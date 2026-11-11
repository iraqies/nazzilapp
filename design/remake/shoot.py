#!/usr/bin/env python3
"""Render the mock boards with headless Chrome over the DevTools protocol.

Usage: shoot.py [--scale 2] [--jpeg 90] [--parts] [--out DIR] page.html [more.html ...]
Each page is written to boards/<name>.png (or .jpg), as wide as its <body>.
With --parts, every element that carries a data-shot attribute is also written
to boards/<name>-<data-shot>.png.
"""
import argparse
import base64
import json
import os
import shutil
import subprocess
import tempfile
import time
import urllib.request

import websocket

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = shutil.which('google-chrome') or shutil.which('chromium') or 'google-chrome'


class Tab:
    def __init__(self, ws_url):
        self.ws = websocket.create_connection(ws_url, timeout=60, suppress_origin=True)
        self.next_id = 0

    def call(self, method, **params):
        self.next_id += 1
        wanted = self.next_id
        self.ws.send(json.dumps({'id': wanted, 'method': method, 'params': params}))
        while True:
            message = json.loads(self.ws.recv())
            if message.get('id') == wanted:
                if 'error' in message:
                    raise RuntimeError(f"{method}: {message['error']}")
                return message.get('result', {})

    def wait_event(self, name):
        while True:
            message = json.loads(self.ws.recv())
            if message.get('method') == name:
                return message.get('params', {})

    def evaluate(self, expression):
        result = self.call('Runtime.evaluate', expression=expression, awaitPromise=True, returnByValue=True)
        if 'exceptionDetails' in result:
            raise RuntimeError(json.dumps(result['exceptionDetails'])[:600])
        return result['result'].get('value')


def start_chrome(profile):
    process = subprocess.Popen(
        [
            CHROME, '--headless=new', '--no-sandbox', '--disable-gpu', '--hide-scrollbars',
            '--no-first-run', '--disable-extensions', '--disable-background-networking',
            '--disable-component-update', '--disable-sync', '--disable-dev-shm-usage',
            '--allow-file-access-from-files', '--remote-allow-origins=*',
            '--remote-debugging-port=0', f'--user-data-dir={profile}', 'about:blank',
        ],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    port_file = os.path.join(profile, 'DevToolsActivePort')
    deadline = time.time() + 40
    while not os.path.exists(port_file):
        if time.time() > deadline:
            process.kill()
            raise RuntimeError('Chrome did not open its DevTools port')
        time.sleep(0.1)
    with open(port_file) as handle:
        port = int(handle.readline().strip())
    return process, port


def page_socket(port):
    deadline = time.time() + 20
    while True:
        try:
            with urllib.request.urlopen(f'http://127.0.0.1:{port}/json/list', timeout=5) as response:
                for target in json.load(response):
                    if target.get('type') == 'page':
                        return target['webSocketDebuggerUrl']
        except OSError:
            pass
        if time.time() > deadline:
            raise RuntimeError('No page target')
        time.sleep(0.1)


SIZE_JS = """
document.fonts.ready.then(() => new Promise(done => requestAnimationFrame(() => requestAnimationFrame(() => {
  const root = document.documentElement;
  const parts = [...document.querySelectorAll('[data-shot]')].map(el => {
    const r = el.getBoundingClientRect();
    return {name: el.dataset.shot, x: r.left + scrollX, y: r.top + scrollY, w: r.width, h: r.height};
  });
  const missing = [...document.fonts].filter(f => f.status === 'error').map(f => f.family);
  done(JSON.stringify({w: document.body.offsetWidth, h: root.scrollHeight, parts, missing}));
}))))
"""


def shoot(tab, page, out_dir, scale, parts, jpeg):
    name = os.path.splitext(os.path.basename(page))[0]
    tab.call('Emulation.setDeviceMetricsOverride', width=1840, height=900, deviceScaleFactor=scale, mobile=False)
    tab.call('Page.navigate', url='file://' + os.path.abspath(page))
    tab.wait_event('Page.loadEventFired')
    info = json.loads(tab.evaluate(SIZE_JS))
    if info['missing']:
        print(f'  fonts failed to load: {sorted(set(info["missing"]))}')

    kind = {'format': 'jpeg', 'quality': jpeg} if jpeg else {'format': 'png'}
    ext = 'jpg' if jpeg else 'png'

    def capture(path, x, y, w, h):
        shot = tab.call(
            'Page.captureScreenshot', captureBeyondViewport=True,
            clip={'x': x, 'y': y, 'width': w, 'height': h, 'scale': 1}, **kind,
        )
        with open(path, 'wb') as handle:
            handle.write(base64.b64decode(shot['data']))
        print(f'  {os.path.relpath(path, HERE)}  {round(w * scale)}x{round(h * scale)}')

    capture(os.path.join(out_dir, f'{name}.{ext}'), 0, 0, info['w'], info['h'])
    if parts:
        for part in info['parts']:
            capture(os.path.join(out_dir, f"{name}-{part['name']}.{ext}"), part['x'], part['y'], part['w'], part['h'])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('pages', nargs='+')
    parser.add_argument('--scale', type=float, default=2)
    parser.add_argument('--jpeg', type=int, metavar='QUALITY', help='write JPEG at this quality instead of PNG')
    parser.add_argument('--parts', action='store_true')
    parser.add_argument('--out', default=os.path.join(HERE, 'boards'))
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)

    profile = tempfile.mkdtemp(prefix='nazzil-shoot-')
    process, port = start_chrome(profile)
    try:
        tab = Tab(page_socket(port))
        tab.call('Page.enable')
        for page in args.pages:
            print(page)
            shoot(tab, page, args.out, args.scale, args.parts, args.jpeg)
    finally:
        process.kill()
        process.wait()
        shutil.rmtree(profile, ignore_errors=True)


if __name__ == '__main__':
    main()
