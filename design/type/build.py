"""Make the app's Arabic typeface from Aref Ruqaa, the hand the logo is written in.

English is set in Anthropic Sans, which the owner supplied on 2026-11-11, and one
line of the app can hold both scripts: an Arabic sentence with a size in megabytes,
an English one with an Arabic title. Aref Ruqaa as released cannot stand next to
Anthropic Sans, for three reasons. The copies in `flutter/assets/fonts/` change
those three things and nothing else: no letter, join or space is redrawn. The
released files are in `upstream/`.

1. It carries Latin letters and digits of its own, so a screen would never ask the
   other typeface for them. The copies keep what is Arabic (letters, marks, digits,
   punctuation) and the space. The rest is left out and falls through to
   Anthropic Sans.

2. Its letters are small on their body, so at one text size an Arabic word reads
   smaller than the English word next to it. The copies say the body is 750 units
   and not 1000, which draws every letter a third larger at the same text size.
   One size in the app then suits both scripts.

3. It says its letters reach 1221 units above the line they are written on and 244
   below, so the middle of a line is 488 units up. A screen centres a label in a
   button by those two numbers. The ink of this app's own Arabic strings is centred
   270 to 310 units up (`python3 build.py --measure` prints it), so its words sat
   nearly a fifth of their size too low. The copies say 1005 above and 454 below,
   which keeps the height almost the same and puts the middle 276 units up. That
   is 0.367 of the new body, where Anthropic Sans has its middle, so a line that
   holds both scripts is no taller than a line that holds one.

    python3 build.py            write the app's copies, and check them
    python3 build.py --measure  print where the app's strings sit

The licence allows a changed copy as long as it does not take the reserved name
EURM10, which this one does not. EURM10 is the Latin, and the copies leave it out.
"""
import os
import re
import statistics
import sys

from fontTools import subset
from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
UPSTREAM = os.path.join(HERE, 'upstream')
APP = os.path.join(HERE, '..', '..', 'flutter')
FILES = ('ArefRuqaa-Regular.ttf', 'ArefRuqaa-Bold.ttf')

BODY = 750
ABOVE = 1005
BELOW = 454

# Anthropic Sans: 1985 above and 515 below on a body of 2000.
LATIN_MIDDLE = (1985 - 515) / 2 / 2000

NOTE = (
    'The Arabic of Aref Ruqaa as the Nazzil app sets it: Arabic letters, marks, digits and '
    'punctuation only, drawn a third larger on the body. A changed copy, made by design/type/build.py.'
)

WORDS = ('نزّل', 'التنزيل', 'جارٍ التحويل…', 'الإعدادات', 'صورتان، ثم 11 صورة', 'لا يوجد اتصال بالإنترنت')


def arabic(codepoint):
    return (
        codepoint in (0x20, 0xA0)
        or 0x0600 <= codepoint <= 0x06FF
        or 0x0750 <= codepoint <= 0x077F
        or 0x08A0 <= codepoint <= 0x08FF
        or 0xFB50 <= codepoint <= 0xFDFF
        or 0xFE70 <= codepoint <= 0xFEFC
    )


def build():
    assert abs((ABOVE - BELOW) / 2 / BODY - LATIN_MIDDLE) < 5e-4, 'the two typefaces have one middle'
    for name in FILES:
        source = os.path.join(UPSTREAM, name)
        options = subset.Options()
        options.layout_features = ['*']
        # Only the Arabic rules. The Latin ones would widen a space that follows a Latin letter.
        options.layout_scripts = ['arab']
        options.name_IDs = ['*']
        options.name_languages = ['*']
        options.notdef_outline = True
        font = subset.load_font(source, options)
        kept = sorted(c for c in font.getBestCmap() if arabic(c))
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=kept)
        subsetter.subset(font)

        font['head'].unitsPerEm = BODY
        font['hhea'].ascent, font['hhea'].descent, font['hhea'].lineGap = ABOVE, -BELOW, 0
        os2 = font['OS/2']
        os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = ABOVE, -BELOW, 0
        os2.usWinAscent, os2.usWinDescent = ABOVE, BELOW
        font['name'].setName(NOTE, 10, 3, 1, 0x409)

        target = os.path.join(APP, 'assets', 'fonts', name)
        font.save(target)
        check(source, target, kept)
        print(
            'wrote', os.path.relpath(target, os.path.join(HERE, '..', '..')),
            f'({len(kept)} characters, {os.path.getsize(target) // 1024} KB)',
        )


def shaped(path, text, script=None):
    """What the typeface writes for `text`: each outline, how far it moves on, and where it sits."""
    import uharfbuzz as hb
    from fontTools.pens.recordingPen import DecomposingRecordingPen

    shaper = hb.Font(hb.Face(hb.Blob.from_file_path(path)))
    font = TTFont(path)
    glyphs, order = font.getGlyphSet(), font.getGlyphOrder()
    buffer = hb.Buffer()
    buffer.add_str(text)
    buffer.guess_segment_properties()
    if script:
        buffer.script = script
    hb.shape(shaper, buffer, {})
    written = []
    for info, position in zip(buffer.glyph_infos, buffer.glyph_positions):
        pen = DecomposingRecordingPen(glyphs)
        glyphs[order[info.codepoint]].draw(pen)
        written.append((pen.value, position.x_advance, position.x_offset, position.y_offset))
    return written


def check(source, target, kept):
    """The copy writes Arabic exactly as the release does, and holds nothing that is not Arabic."""
    for word in WORDS:
        text = ''.join(c for c in word if ord(c) in kept)
        assert shaped(source, text) == shaped(target, text), f'{os.path.basename(target)} writes {text} differently'
    space = TTFont(source)['hmtx'][TTFont(source).getBestCmap()[0x20]][0]
    for script in ('Arab', 'Latn'):
        assert [g[1] for g in shaped(target, ' ', script)] == [space], 'one space, whatever stands next to it'
    left = set(TTFont(target).getBestCmap())
    assert left == set(kept) and not any(chr(c).isascii() and chr(c) != ' ' for c in left)


def measure():
    import uharfbuzz as hb

    source = open(os.path.join(APP, 'lib', 'l10n', 'strings.dart'), encoding='utf8').read()
    strings = [s for s in re.findall(r"'((?:[^'\\]|\\.)*)'", source) if '$' not in s and len(s) <= 24]
    texts = [s for s in strings if re.search('[\u0600-\u06FF]', s)]
    for name in FILES:
        path = os.path.join(UPSTREAM, name)
        shaper = hb.Font(hb.Face(hb.Blob.from_file_path(path)))
        font = TTFont(path)
        glyphs, order = font.getGlyphSet(), font.getGlyphOrder()
        middles = []
        for text in texts:
            buffer = hb.Buffer()
            buffer.add_str(text)
            buffer.guess_segment_properties()
            hb.shape(shaper, buffer, {})
            area = moment = 0
            for info, position in zip(buffer.glyph_infos, buffer.glyph_positions):
                pen = BoundsPen(glyphs)
                glyphs[order[info.codepoint]].draw(pen)
                if pen.bounds is None:
                    continue
                x0, y0, x1, y1 = pen.bounds
                size = (x1 - x0) * (y1 - y0)
                area += size
                moment += size * ((y0 + y1) / 2 + position.y_offset)
            if area:
                middles.append(moment / area)
        print(f'{name}: {len(middles)} Arabic strings, ink centred {statistics.mean(middles):.0f} above the line')


if __name__ == '__main__':
    measure() if '--measure' in sys.argv else build()
