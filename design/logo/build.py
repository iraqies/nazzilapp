#!/usr/bin/env python3
"""Write the concept drawings as SVG and the pages that show them.

svg/<scheme>/<nn>-<key>.svg   every concept on ink, on Rose, on paper and in one colour
pages/overview.html           all 25 on one sheet
pages/board-<n>.html          five concepts a sheet, each with its reason, colours and small sizes
pages/phone-<theme>.html      all 25 at the size of a home screen icon

Then: python3 ../remake/shoot.py --scale 3 --out boards pages/*.html

Needs fontTools and uharfbuzz (pip install fonttools uharfbuzz).
"""
import html
import os

import concepts

HERE = os.path.dirname(os.path.abspath(__file__))

GROUPS = [
    ('The letter N', 'The first letter of the name in Latin, as a sign.'),
    ('The letter ن', 'The first letter of the name in Arabic. Its shape is a dot above a bowl.'),
    ('The word', 'The whole name as the logo, in five kinds of lettering.'),
    ('The frame', 'The app is built on frames: the empty one on Home, the wall of them in the library.'),
    ('Cinema and signs', 'From the direction you picked, and from the buttons of a player.'),
]
ROUND_PAD = 36
TODAY = '../../../flutter/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'
SCHEME_NAMES = {'ink': 'on black', 'rose': 'on Rose', 'paper': 'on paper', 'mono': 'one colour'}

HEAD = '''<!doctype html>
<html lang="en">
<meta charset="utf-8">
<title>{title}</title>
<link rel="stylesheet" href="../../remake/src/fonts.css">
<link rel="stylesheet" href="../board.css">
<body class="{body}">
'''


def file_name(number, key):
    return f'{number:02d}-{key}.svg'


def write_svgs():
    for scheme, palette in concepts.SCHEMES.items():
        folder = os.path.join(HERE, 'svg', scheme)
        os.makedirs(folder, exist_ok=True)
        for number, key, _name, _scheme, _idea, function in concepts.CONCEPTS:
            with open(os.path.join(folder, file_name(number, key)), 'w') as handle:
                handle.write(concepts.svg(function, palette))
    # A round launcher mask shows the drawing smaller, so that nothing is cut off.
    folder = os.path.join(HERE, 'svg', 'round')
    os.makedirs(folder, exist_ok=True)
    for number, key, _name, scheme, _idea, function in concepts.CONCEPTS:
        with open(os.path.join(folder, file_name(number, key)), 'w') as handle:
            handle.write(concepts.svg(function, concepts.SCHEMES[scheme], pad=ROUND_PAD))


def tile(number, key, scheme, extra=''):
    return f'<img class="tile {scheme}{extra}" src="../svg/{scheme}/{file_name(number, key)}" alt="">'


def write(name, body_class, title, body):
    with open(os.path.join(HERE, 'pages', f'{name}.html'), 'w') as handle:
        handle.write(HEAD.format(title=html.escape(title), body=body_class) + body + '\n')
    print(f'pages/{name}.html')


def overview():
    rows = []
    for index, (title, _line) in enumerate(GROUPS):
        cells = ''.join(
            f'<figure>{tile(number, key, scheme)}<figcaption><b>{number}</b>{html.escape(name)}</figcaption></figure>'
            for number, key, name, scheme, _idea, _fn in concepts.CONCEPTS[index * 5:index * 5 + 5]
        )
        rows.append(f'<section><h2>{html.escape(title)}</h2><div class="cells">{cells}</div></section>')
    write('overview', 'overview', 'Nazzil logo: 25 concepts', (
        '<header><div><h1>Nazzil logo: 25 concepts</h1>'
        '<p>Each one is drawn as an app icon, in black, white and Rose. '
        'Five sheets follow with the reason behind each. Pick by number.</p></div>'
        f'<figure class="today"><img src="{TODAY}" alt=""><figcaption>The icon today</figcaption></figure></header>'
        + ''.join(rows)
    ))


def boards():
    for index, (title, line) in enumerate(GROUPS):
        rows = []
        for number, key, name, scheme, idea, _fn in concepts.CONCEPTS[index * 5:index * 5 + 5]:
            others = [s for s in ('ink', 'rose', 'paper', 'mono') if s != scheme]
            alts = ''.join(
                f'<figure>{tile(number, key, other)}<figcaption>{SCHEME_NAMES[other]}</figcaption></figure>'
                for other in others
            )
            small = ''.join(tile(number, key, scheme, f' s{size}') for size in (44, 30, 20))
            rows.append(
                f'<article>{tile(number, key, scheme, " big")}<div class="about">'
                f'<h3><b>{number}</b>{html.escape(name)}</h3><p>{html.escape(idea)}</p>'
                f'<div class="alts">{alts}<figure class="small"><div>{small}</div>'
                f'<figcaption>small</figcaption></figure></div></div></article>'
            )
        first = index * 5 + 1
        write(f'board-{index + 1}', 'board', f'Nazzil logo: {title}', (
            f'<header><div class="range">{first} to {first + 4}</div><h1>{html.escape(title)}</h1>'
            f'<p>{html.escape(line)}</p></header>' + ''.join(rows)
        ))


def phones():
    for theme, mask in (('dark', 'square'), ('light', 'round')):
        cells = ''.join(
            f'<figure>{tile(number, key, "round" if mask == "round" else scheme)}'
            f'<figcaption>{number}</figcaption></figure>'
            for number, key, _name, scheme, _idea, _fn in concepts.CONCEPTS
        )
        dock = '<i></i>' * 4
        write(f'phone-{theme}', f'phone {theme} {mask}', f'Nazzil logo: on a {theme} home screen', (
            '<div class="status"><span>9:41</span><span class="bars"><i></i><i></i><i></i></span></div>'
            f'<div class="grid">{cells}</div>'
            '<p class="note">Open this picture full screen. The icons are then the size they have on a phone.</p>'
            f'<div class="dock">{dock}</div>'
        ))


def main():
    os.makedirs(os.path.join(HERE, 'pages'), exist_ok=True)
    write_svgs()
    overview()
    boards()
    phones()


if __name__ == '__main__':
    main()
