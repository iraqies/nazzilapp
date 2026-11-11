"""The logo the owner chose on 2026-11-11: concept 13, the word نزّل in the Ruqaa hand.

The letters are ink, and the two dots and the shadda take the colour. On the
launcher icon the ground is paper and the colour is Rose. In the app the mark
stands on the page, and its dots take the colour the user picked.
"""
import math

from concepts import split_dots
from lettering import shape

FONT = 'ArefRuqaa-Bold.ttf'
WORD = 'نزّل'

PAPER = '#F4F2EE'
INK = '#111111'
ROSE = '#FF4D8D'


class Mark:
    """The outlines in font units, y down. `left` and `top` are where the word's box starts."""

    def __init__(self):
        word = shape(FONT, WORD, 1000)
        self.letters, self.dots = split_dots(word)
        x0, y0, x1, y1 = word.box
        self.left, self.top = math.floor(x0), math.floor(y0)
        self.width, self.height = math.ceil(x1) - self.left, math.ceil(y1) - self.top

    def scale_into(self, width, height):
        """The scale at which the word is as large as fits in `width` by `height`."""
        return min(width / self.width, height / self.height)

    def placed(self, cx, cy, scale):
        """Where the outlines' origin lands, and the scale, for the word centred on cx, cy."""
        return (
            cx - scale * (self.left + self.width / 2),
            cy - scale * (self.top + self.height / 2),
            scale,
        )

    def svg(self, cx, cy, scale, letters, dots):
        """The word centred on cx, cy, as SVG."""
        dx, dy, scale = self.placed(cx, cy, scale)
        return (
            f'<g transform="translate({dx:.3f},{dy:.3f}) scale({scale:.5f})">'
            f'<path d="{self.letters}" fill="{letters}"/><path d="{self.dots}" fill="{dots}"/></g>'
        )


# On a square of 512, the word takes the same room as on the sheet the owner picked from.
TILE = 512
FIT = (340, 300)


def tile(mark, ground=PAPER, letters=INK, dots=ROSE, size=TILE, bleed=0):
    """The launcher icon as a square SVG. `bleed` shows that much more of the ground on every side."""
    scale = mark.scale_into(*FIT)
    view = f'{-bleed} {-bleed} {TILE + 2 * bleed} {TILE + 2 * bleed}'
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" width="{size}" height="{size}">'
        f'<rect x="{-bleed}" y="{-bleed}" width="{TILE + 2 * bleed}" height="{TILE + 2 * bleed}" fill="{ground}"/>'
        f'{mark.svg(TILE / 2, TILE / 2, scale, letters, dots)}</svg>'
    )


def lettering(mark, letters=INK, dots=ROSE, pad=0):
    """The word alone, with no ground, as an SVG as large as the word plus `pad` font units around it."""
    width, height = mark.width + 2 * pad, mark.height + 2 * pad
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">'
        f'{mark.svg(width / 2, height / 2, 1, letters, dots)}</svg>'
    )
