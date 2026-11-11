#!/usr/bin/env python3
"""Turn src/*.html into pages/*.html.

A direction page (src/d*.html) picks its icon set with a comment,
<!--icons:rounded-->, and names an icon as [[download]] or, for the filled
cut, [[download*]]. The icons are inlined as SVG.

Any other page can borrow from the direction pages:
  {{styles}}             the screen styles of every direction
  {{phone:d1-shelf:2}}   the second phone of that direction

Every page is written twice: <name>.html with the phones in one row, and
<name>-tall.html with two phones a row, which reads better on a phone.
"""
import glob
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = re.compile(r'<path d="([^"]+)"')
ICON_SET = re.compile(r'<!--icons:(\w+)-->')
ICON = re.compile(r'\[\[([a-z0-9_]+)(\*?)\]\]')
STYLE = re.compile(r'<style>\n(.*?)</style>', re.S)
PAGE_RULE = re.compile(r'^\s*(body|\.bhead)\b')
PHONE = re.compile(r'\{\{phone:([\w-]+):(\w+)\}\}')


def icon(style, name, filled):
    file = os.path.join(HERE, 'icons', style, f"{name}{'_fill' if filled else ''}.svg")
    with open(file) as handle:
        d = PATH.search(handle.read()).group(1)
    return f'<svg class="i" viewBox="0 -960 960 960" aria-hidden="true"><path d="{d}"/></svg>'


def read(path):
    with open(path) as handle:
        return handle.read()


def with_icons(html):
    found = ICON_SET.search(html)
    style = found.group(1) if found else 'rounded'
    return ICON.sub(lambda m: icon(style, m.group(1), bool(m.group(2))), html)


def screen_styles(html):
    """A direction's styles without the rules that dress its own board."""
    lines = STYLE.search(html).group(1).split('\n')
    return '\n'.join(line for line in lines if not PAGE_RULE.match(line))


def phone(name, html, shot):
    found = re.search(rf'<div class="bezel" data-shot="{shot}">.*?(?=\s*<figcaption>)', html, re.S)
    if not found:
        raise KeyError(f'{name} has no phone {shot}')
    return found.group(0).replace(f'data-shot="{shot}"', f'data-shot="{name}"', 1)


def write(name, html):
    for suffix, root in (('', '<html lang="en">'), ('-tall', '<html lang="en" class="tall">')):
        target = os.path.join(HERE, 'pages', f'{name}{suffix}.html')
        with open(target, 'w') as handle:
            handle.write(html.replace('<html lang="en">', root, 1))
        print(os.path.relpath(target, HERE))


def main():
    os.makedirs(os.path.join(HERE, 'pages'), exist_ok=True)
    sources = sorted(glob.glob(os.path.join(HERE, 'src', '*.html')))
    name_of = lambda path: os.path.splitext(os.path.basename(path))[0]

    directions = {name_of(p): with_icons(read(p)) for p in sources if name_of(p).startswith('d')}
    for name, html in directions.items():
        write(name, html)

    styles = '\n'.join(screen_styles(html) for html in directions.values())
    for path in sources:
        if name_of(path) in directions:
            continue
        html = read(path).replace('{{styles}}', styles)
        html = PHONE.sub(lambda m: phone(m.group(1), directions[m.group(1)], m.group(2)), html)
        write(name_of(path), with_icons(html))


if __name__ == '__main__':
    main()
