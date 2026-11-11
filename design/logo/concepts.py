"""The 25 logo concepts for Nazzil, each drawn on a 512 square.

A concept is a function that takes a palette and returns SVG markup. The same
drawing is rendered on ink, on Rose and on paper, and once in a single colour,
which is what an Android themed icon needs.
"""
import math
from dataclasses import dataclass

from lettering import shape

SIZE = 512
MID = SIZE / 2


@dataclass(frozen=True)
class Palette:
    bg: str
    fg: str
    ac: str
    dim: str
    well: str

    @property
    def touch(self):
        """The accent where it lies against the foreground. In one colour it has to step back to stay apart."""
        return self.dim if self.ac == self.fg else self.ac


INK = Palette(bg='#0B0B0C', fg='#F5F3EE', ac='#FF4D8D', dim='#5E5B56', well='#1E1E20')
ROSE = Palette(bg='#FF4D8D', fg='#0B0B0C', ac='#F5F3EE', dim='#B92C63', well='#F03F7F')
PAPER = Palette(bg='#F4F2EE', fg='#111111', ac='#FF4D8D', dim='#B5B0A6', well='#E3DFD6')
MONO = Palette(bg='#202124', fg='#E8EAED', ac='#E8EAED', dim='#7E8084', well='#2C2D31')
SCHEMES = {'ink': INK, 'rose': ROSE, 'paper': PAPER, 'mono': MONO}

# Shapes that run to the edge of the icon are drawn this far past it, so they still
# reach the edge when a launcher shows more of the drawing than the 512 square.
BLEED = 120


def n(v):
    return f'{v:.2f}'.rstrip('0').rstrip('.')


def pts(points):
    return ' '.join(f'{n(x)},{n(y)}' for x, y in points)


def poly(points, fill, extra=''):
    return f'<polygon points="{pts(points)}" fill="{fill}"{extra}/>'


def rect(x, y, w, h, fill, r=0, extra=''):
    corner = f' rx="{n(r)}"' if r else ''
    return f'<rect x="{n(x)}" y="{n(y)}" width="{n(w)}" height="{n(h)}"{corner} fill="{fill}"{extra}/>'


def diamond(cx, cy, r, fill):
    return poly([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill)


def group(inner, dx=0, dy=0):
    return f'<g transform="translate({n(dx)},{n(dy)})">{inner}</g>'


def grown(inner, factor):
    """The drawing made larger or smaller about the middle of the tile."""
    return f'<g transform="translate({n(MID * (1 - factor))},{n(MID * (1 - factor))}) scale({n(factor)})">{inner}</g>'


def letter_n(x0, y0, w, h, stem, diag):
    """A capital N as ten points: two stems and a diagonal `diag` wide, measured along the top."""
    x1, y1 = x0 + w, y0 + h
    k = h * (w - stem - diag) / (w - diag)
    return [
        (x0, y0), (x0 + diag, y0), (x1 - stem, y0 + k), (x1 - stem, y0), (x1, y0),
        (x1, y1), (x1 - diag, y1), (x0 + stem, y1 - k), (x0 + stem, y1), (x0, y1),
    ]


def centred(word, cx, cy, scale=1.0):
    """The transform that puts the middle of a shaped word at (cx, cy)."""
    x0, y0, x1, y1 = word.box
    return f'translate({n(cx - scale * (x0 + x1) / 2)},{n(cy - scale * (y0 + y1) / 2)}) scale({n(scale)})'


def fit(word, width, height):
    """The scale at which a shaped word is as large as fits in `width` by `height`."""
    return min(width / word.width, height / word.height)


def split_dots(word):
    """Path data of the letter bodies, and of their dots and marks, apart.

    A glyph that is a mark on its own (the shadda, or a dot in a typeface that
    keeps its dots apart) goes with the dots. Inside a letter, the body is the
    largest closed shape and every shape that overlaps it, since some typefaces
    build a letter from overlapping pieces. What is left stands clear of the
    body, and that is a dot.
    """
    bodies, dots = [], []
    for glyph in word.glyphs:
        pieces = sorted(glyph['contours'], key=lambda piece: _area(piece['box']), reverse=True)
        if not pieces:
            continue
        if glyph['mark']:
            dots.extend(piece['d'] for piece in pieces)
            continue
        body, rest = [pieces[0]], pieces[1:]
        grew = True
        while grew:
            grew = False
            for piece in list(rest):
                if any(_overlap(piece['box'], part['box']) for part in body):
                    body.append(piece)
                    rest.remove(piece)
                    grew = True
        bodies.extend(piece['d'] for piece in body)
        dots.extend(piece['d'] for piece in rest)
    return ' '.join(bodies), ' '.join(dots)


def _area(box):
    return (box[2] - box[0]) * (box[3] - box[1])


def _overlap(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


# ---------------------------------------------------------------- the letter N

def n_lands(p):
    x0, y0, w, h, stem, diag = 150, 128, 228, 236, 60, 80
    x1, y1 = x0 + w, y0 + h
    k = h * (w - stem - diag) / (w - diag)
    rest = [
        (x0 + stem, y0), (x0 + diag, y0), (x1 - stem, y0 + k), (x1 - stem, y0), (x1, y0),
        (x1, y1), (x1 - diag, y1), (x0 + stem, y1 - k),
    ]
    mid = x0 + stem / 2
    arrow = [
        (x0, y0), (x0 + stem, y0), (x0 + stem, 332), (mid + 74, 332), (mid, 428), (mid - 74, 332), (x0, 332),
    ]
    return grown(group(poly(rest, p.fg) + poly(arrow, p.ac), 14, -22), 1.05)


def n_arriving(p):
    shape_n = pts(letter_n(132, 114, 248, 278, 67, 88))
    line_y, half = 296, 7
    return (
        f'<clipPath id="above"><rect x="0" y="0" width="512" height="{line_y - half}"/></clipPath>'
        f'<clipPath id="below"><rect x="0" y="{line_y + half}" width="512" height="300"/></clipPath>'
        f'<polygon points="{shape_n}" fill="{p.fg}" clip-path="url(#above)"/>'
        f'<polygon points="{shape_n}" fill="{p.dim}" clip-path="url(#below)"/>'
        + rect(96, line_y - half, 320, 2 * half, p.ac)
    )


def n_dot(p):
    return group(poly(letter_n(148, 180, 216, 226, 60, 78), p.fg) + diamond(MID, 112, 44, p.ac), 0, 12)


def n_frame(p):
    x0, y0, side, stem, diag = 111, 111, 290, 75, 96
    x1 = x0 + side
    k = side * (side - stem - diag) / (side - diag)
    # The wedge fills the upper cut of the N and runs a hair under its edges, so no seam shows.
    wedge = [(x0 + diag - 1, y0), (x1 - stem + 1, y0), (x1 - stem + 1, y0 + k + 2)]
    return poly(wedge, p.touch) + poly(letter_n(x0, y0, side, side, stem, diag), p.fg)


def n_letterbox(p):
    top, bottom = 160, 352
    big = pts(letter_n(91, 36, 330, 440, 96, 122))
    wide = SIZE + 2 * BLEED
    return (
        f'<mask id="cut"><rect x="{-BLEED}" y="0" width="{wide}" height="512" fill="#fff"/>'
        f'<polygon points="{big}" fill="#000"/></mask>'
        + rect(-BLEED, top, wide, bottom - top, p.ac, extra=' mask="url(#cut)"')
    )


# ---------------------------------------------------------------- the letter noon

def noon_drop(p):
    cx, cy, radius, stroke, lift = MID, 215, 128, 60, 22
    a = math.radians(lift)
    ex, ey = radius * math.cos(a), radius * math.sin(a)
    bowl = (
        f'<path d="M{n(cx + ex)},{n(cy - ey)} A{radius} {radius} 0 1 1 {n(cx - ex)},{n(cy - ey)}" '
        f'fill="none" stroke="{p.fg}" stroke-width="{stroke}"/>'
    )
    return bowl + diamond(cx, cy - 26, 46, p.ac)


def noon_tray(p):
    left, right, top, bottom, stroke, r = 126, 386, 204, 388, 54, 16
    tray = (
        f'<path d="M{left},{top} H{left + stroke} V{bottom - stroke} H{right - stroke} V{top} H{right} '
        f'V{bottom - r} A{r} {r} 0 0 1 {right - r},{bottom} H{left + r} A{r} {r} 0 0 1 {left},{bottom - r} Z" '
        f'fill="{p.fg}"/>'
    )
    drop = poly([(204, 146), (308, 146), (MID, 236)], p.ac)
    return grown(group(tray + drop, 0, -11), 1.12)


def noon_pen(p):
    word = shape('Amiri-Bold.ttf', 'ن', 100)
    # The dot sits inside the reach of the bowl here, so it is told apart by size, not by standing clear.
    bowl, dot = sorted(word.glyphs[0]['contours'], key=lambda piece: _area(piece['box']), reverse=True)
    return (
        f'<g transform="{centred(word, MID, MID, fit(word, 310, 330))}">'
        f'<path d="{bowl["d"]}" fill="{p.fg}"/><path d="{dot["d"]}" fill="{p.ac}"/></g>'
    )


def n_in_bowl(p):
    cx, cy, outer, inner_r, shift = MID, 236, 150, 112, 34
    # A crescent: the outer circle minus a circle set higher, so the bowl is full at the bottom
    # and thins towards the top, where it is cut flat.
    bowl = (
        f'<mask id="crescent"><rect width="512" height="512" fill="#000"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{outer}" fill="#fff"/>'
        f'<circle cx="{cx}" cy="{cy - shift}" r="{inner_r}" fill="#000"/>'
        f'<rect x="0" y="0" width="512" height="{cy - 64}" fill="#000"/></mask>'
        f'<rect width="512" height="512" fill="{p.fg}" mask="url(#crescent)"/>'
    )
    letter = poly(letter_n(MID - 55, 126, 110, 122, 31, 41), p.ac)
    return group(bowl + letter, 0, -2)


def shadda(p):
    mark = [g for g in shape('Amiri-Bold.ttf', 'نزّل', 100).glyphs if g['mark']][0]
    x0, y0, x1, y1 = mark['box']
    scale = 300 / (x1 - x0)
    return (
        f'<path transform="translate({n(MID - scale * (x0 + x1) / 2)},{n(MID - scale * (y0 + y1) / 2)}) '
        f'scale({n(scale)})" d="{mark["d"]}" fill="{p.ac}"/>'
    )


# ---------------------------------------------------------------- the word

def _word(p, font, variations, width, height, body_fill, dot_fill, more=''):
    """The word نزّل set in `font`, as large as fits in `width` by `height`, with its dots in their own colour."""
    word = shape(font, 'نزّل', 100, variations)
    body, dots = split_dots(word)
    return (
        f'<g transform="{more}{centred(word, MID, MID, fit(word, width, height))}">'
        f'<path d="{body}" fill="{body_fill}"/><path d="{dots}" fill="{dot_fill}"/></g>'
    )


def word_changa(p):
    return _word(p, 'Changa.ttf', {'wght': 800}, 340, 310, p.fg, p.ac)


def word_poster(p):
    return _word(p, 'Lalezar.ttf', None, 350, 300, p.fg, p.fg, more=f'rotate(-7 {MID} {MID}) ')


def word_ruqaa(p):
    return _word(p, 'ArefRuqaa-Bold.ttf', None, 340, 300, p.fg, p.ac)


KUFIC = (
    '..W...R',
    '..W.R..',
    '..W...W',
    '..W.WWW',
    '..W.W..',
    'W.W.W..',
    'WWW....',
)


def word_kufic(p):
    tile, gap = 42, 5
    count = len(KUFIC)
    start = (SIZE - (count * tile + (count - 1) * gap)) / 2
    out = []
    for row, line in enumerate(KUFIC):
        for col, cell in enumerate(line):
            fill = {'W': p.fg, 'R': p.ac, '.': p.well}[cell]
            out.append(rect(start + col * (tile + gap), start + row * (tile + gap), tile, tile, fill))
    return ''.join(out)


def word_latin(p):
    rows = []
    variations = {'wght': 800, 'wdth': 62}
    top = shape('Archivo.ttf', 'NAZ', 100, variations)
    low = shape('Archivo.ttf', 'ZIL', 100, variations)
    scale = 296 / top.width
    cap = top.height * scale
    lead = 26
    y_top = MID - lead / 2 - cap
    for word, y, rose in ((top, y_top, 2), (low, MID + lead / 2, 0)):
        spare = (top.width - word.width) / (len(word.glyphs) - 1)
        for i, glyph in enumerate(word.glyphs):
            dx = MID - scale * top.width / 2 - scale * word.box[0] + scale * spare * i
            dy = y - scale * word.box[1]
            fill = p.ac if i == rose else p.fg
            rows.append(f'<path transform="translate({n(dx)},{n(dy)}) scale({n(scale)})" d="{glyph["d"]}" fill="{fill}"/>')
    return ''.join(rows)


# ---------------------------------------------------------------- the frame

def frame_arriving(p):
    x, y, w, h, line_y = 143, 104, 226, 302, 286
    return (
        rect(x, y, w, line_y - y, p.fg) + rect(x, line_y, w, y + h - line_y, p.dim)
        + rect(x - 34, line_y - 7, w + 68, 14, p.ac)
    )


def frame_arrow(p):
    x0, y0, side, stroke = 116, 142, 280, 20
    x1, y1 = x0 + side, y0 + side
    corner, dash = 62, 52
    lines = []
    for cx, cy, sx, sy in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x1, y1, -1, -1), (x0, y1, 1, -1)):
        lines.append(f'M{cx + sx * corner},{cy} H{cx} V{cy + sy * corner}')
    mid_y = y0 + side / 2
    lines.append(f'M{x0},{mid_y - dash / 2} V{mid_y + dash / 2}')
    lines.append(f'M{x1},{mid_y - dash / 2} V{mid_y + dash / 2}')
    # The top side has no dash in the middle: that is where the arrow comes in.
    lines.append(f'M{MID - dash / 2},{y1} H{MID + dash / 2}')
    frame = (
        f'<path d="{" ".join(lines)}" fill="none" stroke="{p.fg}" stroke-width="{stroke}" '
        f'stroke-linejoin="miter"/>'
    )
    arrow = poly([
        (MID - 24, 70), (MID + 24, 70), (MID + 24, 226), (MID + 76, 226), (MID, 326), (MID - 76, 226), (MID - 24, 226),
    ], p.ac)
    return grown(group(frame + arrow, 0, -5), 0.95)


def frame_pick(p):
    w, h, gap, top, fall = 58, 76, 10, 124, 46
    big_w, big_h = 90, 118
    left = MID - 2.5 * w - 2 * gap
    out = []
    for i in range(5):
        x = left + i * (w + gap)
        if i == 2:
            out.append(
                f'<rect x="{n(x + 4)}" y="{top + 4}" width="{w - 8}" height="{h - 8}" fill="none" '
                f'stroke="{p.dim}" stroke-width="8" stroke-dasharray="13 9.66"/>'
            )
        else:
            out.append(rect(x, top, w, h, p.fg))
    y = top + h + fall
    out.append(rect(MID - big_w / 2, y, big_w, big_h, p.ac,
                    extra=f' transform="rotate(11 {MID} {y + big_h / 2}) translate(10 0)"'))
    return ''.join(out)


def wall_arrow(p):
    w, h, gap = 33, 44, 5
    rows = ('..WWW..', '..WWW..', 'WWWWWWW', '.WWWWW.', '..WWW..', '...R...')
    left = (SIZE - (7 * w + 6 * gap)) / 2
    top = (SIZE - (6 * h + 5 * gap)) / 2
    out = []
    for row, line in enumerate(rows):
        for col, cell in enumerate(line):
            if cell != '.':
                out.append(rect(left + col * (w + gap), top + row * (h + gap), w, h, p.ac if cell == 'R' else p.fg))
    return grown(''.join(out), 1.08)


def strip_arrow(p):
    width, top, neck = 136, 84, 300
    left = MID - width / 2
    out = [rect(left, top, width, neck - top, p.fg)]
    for i in range(4):
        y = top + 20 + i * 50
        out.append(rect(left + 13, y, 20, 26, p.bg, r=4))
        out.append(rect(left + width - 33, y, 20, 26, p.bg, r=4))
    out.append(poly([(MID - 124, neck - 6), (MID + 124, neck - 6), (MID, 428)], p.ac))
    return ''.join(out)


# ---------------------------------------------------------------- cinema and signs

def ticket(p):
    w, h, r, bite, tear = 344, 202, 16, 25, 238
    x0, y0 = MID - w / 2, MID - h / 2
    x1, y1 = x0 + w, y0 + h
    tx = x0 + tear
    body = (
        f'<path d="M{x0 + r},{y0} H{tx - bite} A{bite} {bite} 0 0 0 {tx + bite},{y0} H{x1 - r} '
        f'A{r} {r} 0 0 1 {x1},{y0 + r} V{y1 - r} A{r} {r} 0 0 1 {x1 - r},{y1} H{tx + bite} '
        f'A{bite} {bite} 0 0 0 {tx - bite},{y1} H{x0 + r} A{r} {r} 0 0 1 {x0},{y1 - r} V{y0 + r} '
        f'A{r} {r} 0 0 1 {x0 + r},{y0} Z" fill="{p.ac}"/>'
    )
    tear_line = (
        f'<path d="M{tx},{y0 + bite + 12} V{y1 - bite - 10}" stroke="{p.bg}" stroke-width="7" '
        f'stroke-dasharray="13 11" fill="none"/>'
    )
    letter = poly(letter_n(x0 + 64, y0 + 45, 112, h - 90, 31, 41), p.bg)
    stub = poly([(tx + 30, MID - 21), (tx + 80, MID - 21), (tx + 55, MID + 23)], p.bg)
    return f'<g transform="rotate(-14 {MID} {MID})">{body}{tear_line}{letter}{stub}</g>'


def countdown(p):
    ring, sweep = 160, 112
    a = math.radians(sweep - 90)
    wedge = (
        f'<path d="M{MID},{MID} V{MID - ring} A{ring} {ring} 0 0 1 {n(MID + ring * math.cos(a))},'
        f'{n(MID + ring * math.sin(a))} Z" fill="{p.touch}"/>'
    )
    cross = (
        f'<path d="M{-BLEED},{MID} H{SIZE + BLEED} M{MID},{-BLEED} V{SIZE + BLEED}" '
        f'stroke="{p.dim}" stroke-width="8" fill="none"/>'
    )
    circle = f'<circle cx="{MID}" cy="{MID}" r="{ring}" fill="none" stroke="{p.fg}" stroke-width="14"/>'
    letter = poly(letter_n(MID - 70, MID - 86, 140, 172, 40, 52), p.fg)
    return cross + wedge + circle + letter


def marquee_arrow(p):
    shaft, top, neck, wing, tip = 62, 92, 262, 142, 426
    outline = [
        (MID - shaft, top), (MID + shaft, top), (MID + shaft, neck), (MID + wing, neck),
        (MID, tip), (MID - wing, neck), (MID - shaft, neck),
    ]
    inset = 34
    inner = [
        (MID - shaft + inset, top + inset), (MID + shaft - inset, top + inset),
        (MID + shaft - inset, neck + inset), (MID + wing - inset * 2.3, neck + inset),
        (MID, tip - inset * 1.5), (MID - wing + inset * 2.3, neck + inset), (MID - shaft + inset, neck + inset),
    ]
    bulbs = []
    closed = outline + [outline[0]]
    for (ax, ay), (bx, by) in zip(closed, closed[1:]):
        count = max(1, round(math.hypot(bx - ax, by - ay) / 36))
        for i in range(count):
            bulbs.append((ax + (bx - ax) * i / count, ay + (by - ay) * i / count))
    dots = ''.join(f'<circle cx="{n(x)}" cy="{n(y)}" r="10.5" fill="{p.ac}"/>' for x, y in bulbs)
    return group(poly(inner, p.fg) + dots, 0, -3)


def play_down(p):
    tri = [(150, 136), (362, 136), (MID, 316)]
    triangle = (
        f'<polygon points="{pts(tri)}" fill="{p.ac}" stroke="{p.ac}" stroke-width="36" stroke-linejoin="round"/>'
    )
    return grown(group(triangle + rect(132, 372, 248, 40, p.fg, r=8), 0, -8), 1.06)


def plumb(p):
    return rect(MID - 6, -BLEED, 12, 250 + BLEED, p.fg) + diamond(MID, 322, 74, p.ac)


CONCEPTS = [
    # number, key, name, scheme, the idea in one line, function
    (1, 'n-lands', 'N lands', 'ink', 'The first stroke of the N is the arrow.', n_lands),
    (2, 'n-arriving', 'N arriving', 'ink', "The app's own sign: colour comes down behind a line, grey waits below.", n_arriving),
    (3, 'n-dot', 'N with the dot', 'ink', 'A Latin N wearing the dot of ن. One letter for both languages.', n_dot),
    (4, 'n-frame', 'N in the frame', 'ink', 'A frame with two cuts reads as N, and the upper cut points down.', n_frame),
    (5, 'n-letterbox', 'N, letterboxed', 'ink', 'A wide cinema screen in colour, with the N cut through it.', n_letterbox),
    (6, 'noon-drop', 'Noon drop', 'ink', 'The letter ن, drawn as what it looks like: a dot landing in a bowl.', noon_drop),
    (7, 'noon-tray', 'Noon tray', 'rose', 'ن squared off. It is already a download sign.', noon_tray),
    (8, 'noon-pen', 'Noon, pen-written', 'paper', 'ن as a calligrapher writes it in Naskh, with the dot in colour.', noon_pen),
    (9, 'n-in-bowl', 'N in the bowl', 'ink', 'The dot of ن is the N. Both alphabets in one letter.', n_in_bowl),
    (10, 'shadda', 'Shadda', 'ink', 'The mark that turns نزل (it came down) into نزّل (bring it down).', shadda),
    (11, 'word-changa', 'The word', 'ink', "نزّل in the app's own Arabic type, dots and shadda in colour.", word_changa),
    (12, 'word-poster', 'Poster title', 'rose', 'نزّل in the heavy lettering of old film posters.', word_poster),
    (13, 'word-ruqaa', 'Ruqaa hand', 'paper', 'نزّل in Ruqaa, the everyday handwriting of the region.', word_ruqaa),
    (14, 'word-kufic', 'Kufic wall', 'ink', 'نزل in square Kufic, on the tiles of the library wall. Kufic leaves out the shadda.', word_kufic),
    (15, 'word-latin', 'Title card', 'ink', 'NAZZIL as a film title. The double Z is the shadda, so it gets the colour.', word_latin),
    (16, 'frame-arriving', 'Arriving frame', 'ink', 'One picture, half arrived. The download screen as a sign.', frame_arriving),
    (17, 'frame-arrow', 'Into the frame', 'ink', 'The empty frame of the Home screen, with something coming in.', frame_arrow),
    (18, 'frame-pick', 'One comes down', 'ink', 'A row of frames out there. The one you picked comes down to you, in colour.', frame_pick),
    (19, 'wall-arrow', 'Wall arrow', 'ink', 'The library wall, arranged as an arrow.', wall_arrow),
    (20, 'strip-arrow', 'Film arrow', 'ink', 'A strip of film that ends in a point.', strip_arrow),
    (21, 'ticket', 'Ticket', 'ink', 'A cinema ticket with the N on it.', ticket),
    (22, 'countdown', 'Countdown', 'ink', 'The countdown before a film starts, with N where the number goes.', countdown),
    (23, 'marquee', 'Marquee arrow', 'ink', 'The arrow of light bulbs outside an old cinema.', marquee_arrow),
    (24, 'play-down', 'Play, turned down', 'ink', 'The play button, pointing down and landing. The plainest one.', play_down),
    (25, 'plumb', 'Plumb line', 'ink', 'A straight drop that ends in the dot of ن.', plumb),
]


def svg(function, palette, background=True, pad=0):
    """One concept as a file. `pad` shows that much more around the 512 square, as a round launcher mask does."""
    side = SIZE + 2 * pad
    back = rect(-pad, -pad, side, side, palette.bg) if background else ''
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{-pad} {-pad} {side} {side}" width="{SIZE}" height="{SIZE}">'
        f'{back}{function(palette)}</svg>\n'
    )
