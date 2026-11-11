"""Make the app's two typefaces: Aref Ruqaa for Arabic, Fraunces for English.

Arabic is set in Aref Ruqaa, the hand the logo is written in. English is set in
Fraunces, which was picked to go with it when the owner asked for a match
(2026-11-11). Nineteen typefaces were set next to the Arabic at the app's sizes,
seven of them in the app's own screens, and Fraunces came closest in the three
ways that can be seen:

- Its strokes are the same kind. Both swell and thin the way a broad pen does, and
  both end soft and round. Fraunces can be drawn with sharp or soft ends, and the
  app uses the softest.
- It is as dark on the page. A line of its Regular carries about nine tenths of
  the ink a line of Ruqaa Regular does, and its SemiBold the same share of Ruqaa
  Bold, so neither script looks faint next to the other. Most of the others were
  lighter, some by a third or more. `python3 build.py --measure` prints it.
- It has a cut for reading sizes and a cut for headings, so small text stays
  sturdy and large text stays fine.

Neither release can go into the app as it is, because one line of the app can hold
both scripts: an Arabic sentence with a size in megabytes, an English one with an
Arabic title. The copies in `flutter/assets/fonts/` change what is listed here and
nothing else. No letter, join or space is redrawn. The releases are in `upstream/`.

Fraunces

1. The release is one file that can be drawn at any weight, size and softness. The
   app sets three fixed cuts of it, so the copies are those three: reading sizes in
   Regular and SemiBold, headings in SemiBold. All three have the soft ends, and
   none has the leaning letters the release offers.

2. Its small letters stand 0.47 of the text size tall, and the sizes of the app
   were chosen for small letters a little over half the text size, as a phone's
   own typeface has them. The copies say the body is 1800 units and not 2000,
   which draws every letter a ninth larger at the same text size.

3. Its figures have different widths, so a number that counts up would shake. The
   copies carry a second set, the same ten figures each centred on the width of
   the widest, which a screen gets by asking for figures of one width (`tnum`).

Aref Ruqaa

1. It carries Latin letters and digits of its own, so a screen would never ask the
   other typeface for them. The copies keep what is Arabic (letters, marks, digits,
   punctuation) and the space. The rest is left out and falls through to Fraunces.

2. Its letters are small on their body, so at one text size an Arabic word reads
   smaller than the English word next to it. The copies say the body is 750 units
   and not 1000, which draws every letter a third larger at the same text size.
   One size in the app then suits both scripts.

3. It says its letters reach 1221 units above the line they are written on and 244
   below, so the middle of a line is 488 units up. A screen centres a label in a
   button by those two numbers. The ink of this app's own Arabic strings is centred
   270 to 310 units up, so its words sat nearly a fifth of their size too low. The
   copies say 1005 above and 454 below, which keeps the height almost the same and
   puts the middle 276 units up.

Both copies have the middle of their line in one place, 0.367 of the text size
above the line the letters are written on, so a line that holds both scripts is no
taller than a line that holds one.

    python3 build.py            write the app's copies, and check them
    python3 build.py --measure  print how dark the lines are, and where the Arabic sits

Both licences (the SIL Open Font License) allow a changed copy as long as it does
not take a reserved name. Fraunces reserves none. Aref Ruqaa reserves EURM10, which
is its Latin, and the copies leave that out.
"""
import os
import re
import statistics
import sys

from fontTools import subset
from fontTools.otlLib.builder import buildLookup, buildSingleSubstSubtable
from fontTools.pens.areaPen import AreaPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables import otTables
from fontTools.ttLib.tables._g_l_y_f import ARGS_ARE_XY_VALUES, ROUND_XY_TO_GRID, Glyph, GlyphComponent
from fontTools.varLib import instancer

HERE = os.path.dirname(os.path.abspath(__file__))
UPSTREAM = os.path.join(HERE, 'upstream')
APP = os.path.join(HERE, '..', '..', 'flutter')
FONTS = os.path.join(APP, 'assets', 'fonts')

# The middle of a line of either script, in text sizes above the line the letters are written on.
MIDDLE = 0.3673

FRAUNCES = 'Fraunces[SOFT,WONK,opsz,wght].ttf'
# The cut, the name it is filed under, and where on the release's four scales it is taken.
CUTS = (
    ('Fraunces-Text-Regular.ttf', 'Fraunces Text', 'Regular', {'opsz': 14, 'wght': 400, 'SOFT': 100, 'WONK': 0}),
    ('Fraunces-Text-SemiBold.ttf', 'Fraunces Text', 'SemiBold', {'opsz': 14, 'wght': 600, 'SOFT': 100, 'WONK': 0}),
    ('Fraunces-Display-SemiBold.ttf', 'Fraunces Display', 'SemiBold', {'opsz': 72, 'wght': 600, 'SOFT': 100, 'WONK': 0}),
)
LATIN_BODY = 1800
LATIN_ABOVE = 1786
LATIN_BELOW = 464
# How tall the small letters of the reading cut stand, in text sizes.
SMALL = 0.52
FIGURES = ('zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine')
LATIN_NOTE = (
    'Fraunces as the Nazzil app sets it: one fixed cut with soft ends, drawn a ninth larger on the body, '
    'with a set of figures of one width. A changed copy, made by design/type/build.py.'
)

RUQAA = ('ArefRuqaa-Regular.ttf', 'ArefRuqaa-Bold.ttf')
BODY = 750
ABOVE = 1005
BELOW = 454
NOTE = (
    'The Arabic of Aref Ruqaa as the Nazzil app sets it: Arabic letters, marks, digits and '
    'punctuation only, drawn a third larger on the body. A changed copy, made by design/type/build.py.'
)

WORDS = ('نزّل', 'التنزيل', 'جارٍ التحويل…', 'الإعدادات', 'صورتان، ثم 11 صورة', 'لا يوجد اتصال بالإنترنت')
ENGLISH = ('Paste a link', 'Best WALL-E cosplay ever', '24.6 MB of 108.3 MB, 0:43 left', 'Saved to Downloads/Nazzil')


def lines(font, above, below):
    font['hhea'].ascent, font['hhea'].descent, font['hhea'].lineGap = above, -below, 0
    os2 = font['OS/2']
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = above, -below, 0
    os2.usWinAscent, os2.usWinDescent = above, below


def wrote(target, what):
    print('wrote', os.path.relpath(target, os.path.join(HERE, '..', '..')), f'({what}, {os.path.getsize(target) // 1024} KB)')


def one_width(font):
    """Add the ten figures again, each centred on the width of the widest, for `tnum`."""
    widths, outlines = font['hmtx'], font['glyf']
    width = max(widths[name][0] for name in FIGURES)
    for name in FIGURES:
        advance, side = widths[name]
        shift = (width - advance) // 2
        placed = GlyphComponent()
        placed.glyphName, placed.x, placed.y = name, shift, 0
        placed.flags = ARGS_ARE_XY_VALUES | ROUND_XY_TO_GRID
        figure = Glyph()
        figure.numberOfContours = -1
        figure.components = [placed]
        outlines[name + '.tf'] = figure
        widths[name + '.tf'] = (width, side + shift)
    order = list(dict.fromkeys(outlines.glyphOrder))
    font.setGlyphOrder(order)
    outlines.setGlyphOrder(order)

    rules = font['GSUB'].table
    rules.LookupList.Lookup.append(buildLookup([buildSingleSubstSubtable({name: name + '.tf' for name in FIGURES})]))
    rules.LookupList.LookupCount = len(rules.LookupList.Lookup)
    record = otTables.FeatureRecord()
    record.FeatureTag = 'tnum'
    record.Feature = otTables.Feature()
    record.Feature.FeatureParams = None
    record.Feature.LookupListIndex = [rules.LookupList.LookupCount - 1]
    record.Feature.LookupCount = 1
    tags = [existing.FeatureTag for existing in rules.FeatureList.FeatureRecord]
    assert 'tnum' not in tags and all(tag < 'tnum' for tag in tags), 'the new rule goes last, where the order keeps it'
    rules.FeatureList.FeatureRecord.append(record)
    rules.FeatureList.FeatureCount = len(rules.FeatureList.FeatureRecord)
    for script in rules.ScriptList.ScriptRecord:
        for system in [script.Script.DefaultLangSys, *(entry.LangSys for entry in script.Script.LangSysRecord)]:
            if system is not None:
                system.FeatureIndex.append(rules.FeatureList.FeatureCount - 1)
                system.FeatureCount = len(system.FeatureIndex)
    return width


def top(font, letter):
    glyphs = font.getGlyphSet()
    pen = BoundsPen(glyphs)
    glyphs[font.getBestCmap()[ord(letter)]].draw(pen)
    return pen.bounds[3]


def fraunces():
    assert abs((LATIN_ABOVE - LATIN_BELOW) / 2 / LATIN_BODY - MIDDLE) < 5e-4, 'the two typefaces have one middle'
    source = os.path.join(UPSTREAM, FRAUNCES)
    for file, family, style, place in CUTS:
        font = instancer.instantiateVariableFont(TTFont(source), place)
        # The same release gives the same file, whenever it is built.
        font.recalcTimestamp = False
        released = {text: [g[:2] for g in shaped_font(font, text)] for text in ENGLISH}
        width = one_width(font)
        font['head'].unitsPerEm = LATIN_BODY
        lines(font, LATIN_ABOVE, LATIN_BELOW)
        font['OS/2'].usWeightClass = place['wght']
        names = font['name']
        regular = style == 'Regular'
        for number, text in (
            (1, family if regular else f'{family} {style}'),
            (2, 'Regular'),
            (3, f'Nazzil;{file[:-4]}'),
            (4, f'{family} {style}'),
            (6, file[:-4]),
            (10, LATIN_NOTE),
            (16, family),
            (17, style),
        ):
            names.setName(text, number, 3, 1, 0x409)
        # A name that only a file with scales has a use for.
        names.removeNames(nameID=25)

        target = os.path.join(FONTS, file)
        font.save(target)
        check_latin(target, released, width, place['wght'])
        wrote(target, f'{len(font.getBestCmap())} characters')


def check_latin(target, released, width, weight):
    """The copy writes English exactly as the release does, larger, and has figures of one width."""
    font = TTFont(target)
    for text, written in released.items():
        assert [g[:2] for g in shaped(target, text)] == written, f'{os.path.basename(target)} writes {text} differently'
    assert {g[1] for g in shaped(target, '0123456789', features={'tnum': True})} == {width}, 'figures of one width'
    assert len({g[1] for g in shaped(target, '0123456789')}) > 1, 'and the figures as drawn, when not asked'
    assert font['OS/2'].usWeightClass == weight and font['head'].unitsPerEm == LATIN_BODY
    if 'Text-Regular' in target:
        assert abs(top(font, 'x') / LATIN_BODY - SMALL) < 0.005, 'the small letters stand as tall as the sizes expect'


def arabic(codepoint):
    return (
        codepoint in (0x20, 0xA0)
        or 0x0600 <= codepoint <= 0x06FF
        or 0x0750 <= codepoint <= 0x077F
        or 0x08A0 <= codepoint <= 0x08FF
        or 0xFB50 <= codepoint <= 0xFDFF
        or 0xFE70 <= codepoint <= 0xFEFC
    )


def ruqaa():
    assert abs((ABOVE - BELOW) / 2 / BODY - MIDDLE) < 5e-4, 'the two typefaces have one middle'
    for name in RUQAA:
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
        lines(font, ABOVE, BELOW)
        font['name'].setName(NOTE, 10, 3, 1, 0x409)

        target = os.path.join(FONTS, name)
        font.save(target)
        check_arabic(source, target, kept)
        wrote(target, f'{len(kept)} characters')


def shaped_font(font, text, script=None, features=None, blob=None):
    """What a typeface writes for `text`: each outline, how far it moves on, and where it sits."""
    import io

    import uharfbuzz as hb
    from fontTools.pens.recordingPen import DecomposingRecordingPen

    if blob is None:
        data = io.BytesIO()
        font.save(data)
        blob = hb.Blob(data.getvalue())
        font = TTFont(io.BytesIO(data.getvalue()))
    shaper = hb.Font(hb.Face(blob))
    glyphs, order = font.getGlyphSet(), font.getGlyphOrder()
    buffer = hb.Buffer()
    buffer.add_str(text)
    buffer.guess_segment_properties()
    if script:
        buffer.script = script
    hb.shape(shaper, buffer, features or {})
    written = []
    for info, position in zip(buffer.glyph_infos, buffer.glyph_positions):
        pen = DecomposingRecordingPen(glyphs)
        glyphs[order[info.codepoint]].draw(pen)
        written.append((pen.value, position.x_advance, position.x_offset, position.y_offset))
    return written


def shaped(path, text, script=None, features=None):
    import uharfbuzz as hb

    return shaped_font(TTFont(path), text, script, features, blob=hb.Blob.from_file_path(path))


def check_arabic(source, target, kept):
    """The copy writes Arabic exactly as the release does, and holds nothing that is not Arabic."""
    for word in WORDS:
        text = ''.join(c for c in word if ord(c) in kept)
        assert shaped(source, text) == shaped(target, text), f'{os.path.basename(target)} writes {text} differently'
    space = TTFont(source)['hmtx'][TTFont(source).getBestCmap()[0x20]][0]
    for script in ('Arab', 'Latn'):
        assert [g[1] for g in shaped(target, ' ', script)] == [space], 'one space, whatever stands next to it'
    left = set(TTFont(target).getBestCmap())
    assert left == set(kept) and not any(chr(c).isascii() and chr(c) != ' ' for c in left)


def strings(wanted):
    source = open(os.path.join(APP, 'lib', 'l10n', 'strings.dart'), encoding='utf8').read()
    quoted = re.findall(r"'((?:[^'\\]|\\.)*)'" + '|' + r'"((?:[^"\\]|\\.)*)"', source)
    return [s for s in (one or two for one, two in quoted) if '$' not in s and '\\' not in s and wanted(s)]


def ink(path, texts):
    """The share of a line that is ink: what the letters cover, of the room the line is given."""
    import uharfbuzz as hb

    shaper = hb.Font(hb.Face(hb.Blob.from_file_path(path)))
    font = TTFont(path)
    glyphs, order = font.getGlyphSet(), font.getGlyphOrder()
    covered = room = 0
    for text in texts:
        buffer = hb.Buffer()
        buffer.add_str(text)
        buffer.guess_segment_properties()
        hb.shape(shaper, buffer, {})
        for info, position in zip(buffer.glyph_infos, buffer.glyph_positions):
            pen = AreaPen(glyphs)
            glyphs[order[info.codepoint]].draw(pen)
            covered += abs(pen.value)
            room += position.x_advance * font['head'].unitsPerEm
    return covered / room


def measure():
    import uharfbuzz as hb

    english = strings(lambda s: len(s) >= 12 and not re.search('[\u0600-\u06FF]', s) and re.search('[a-z] [a-z]', s))
    arabic_strings = strings(lambda s: len(s) >= 12 and re.search('[\u0600-\u06FF] [\u0600-\u06FF]', s))
    print(f'{len(english)} English and {len(arabic_strings)} Arabic strings of the app, as the app sets them:')
    for file, texts in (
        ('Fraunces-Text-Regular.ttf', english),
        ('ArefRuqaa-Regular.ttf', arabic_strings),
        ('Fraunces-Text-SemiBold.ttf', english),
        ('ArefRuqaa-Bold.ttf', arabic_strings),
    ):
        print(f'  {file}: {ink(os.path.join(FONTS, file), texts):.3f} of a line is ink')

    short = strings(lambda s: len(s) <= 24 and re.search('[\u0600-\u06FF]', s))
    for name in RUQAA:
        path = os.path.join(UPSTREAM, name)
        shaper = hb.Font(hb.Face(hb.Blob.from_file_path(path)))
        font = TTFont(path)
        glyphs, order = font.getGlyphSet(), font.getGlyphOrder()
        middles = []
        for text in short:
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
        print(f'{name} as released: {len(middles)} Arabic strings, ink centred {statistics.mean(middles):.0f} above the line')


if __name__ == '__main__':
    if '--measure' in sys.argv:
        measure()
    else:
        fraunces()
        ruqaa()
