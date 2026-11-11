#!/usr/bin/env python3
"""Write the chosen logo to every place the app shows it.

  python3 export.py

The outlines come from the typeface (see chosen.py), so nothing here is drawn
by hand. Run it again after changing the logo, then rebuild the app.

Needs fontTools, uharfbuzz, Pillow and a Chrome for the picture files.
"""
import os
import shutil
import sys
import tempfile

from PIL import Image, ImageDraw

from chosen import FIT, INK, PAPER, ROSE, TILE, Mark, lettering, tile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'remake'))
import shoot  # noqa: E402

FLUTTER = os.path.normpath(os.path.join(HERE, '..', '..', 'flutter'))
ANDROID = os.path.join(FLUTTER, 'android', 'app', 'src', 'main', 'res')
OUT = os.path.join(HERE, 'chosen')


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write(text)
    print(os.path.relpath(path, os.path.join(HERE, '..', '..')))


def dart(mark):
    """The outlines the header of the app paints."""
    write(os.path.join(FLUTTER, 'lib', 'ui', 'widgets', 'logo_outline.g.dart'), f"""\
// Written by design/logo/export.py from the outlines of Aref Ruqaa Bold.
// Change the logo there and run it again; an edit made here is lost.

/// The Nazzil logo, the word نزّل in the Ruqaa hand, as outlines in font units with y down.
abstract final class LogoOutline {{
  /// Where the box of the word starts, and how large it is.
  static const left = {float(mark.left)};
  static const top = {float(mark.top)};
  static const width = {float(mark.width)};
  static const height = {float(mark.height)};

  static const letters = '{mark.letters}';

  /// The dots of ن and ز, and the shadda.
  static const dots = '{mark.dots}';
}}
""")


def android_vector(mark, size, scale, colours):
    """A vector drawable, `size` dp square, with the word centred at `scale` dp per font unit."""
    dx, dy, scale = mark.placed(size / 2, size / 2, scale)
    paths = ''.join(
        f'        <path android:fillColor="{colour}" android:pathData="{data}" />\n'
        for colour, data in zip(colours, (mark.letters, mark.dots))
    )
    return f"""\
<?xml version="1.0" encoding="utf-8"?>
<!-- Written by design/logo/export.py. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{size}dp"
    android:height="{size}dp"
    android:viewportWidth="{size}"
    android:viewportHeight="{size}">
    <group
        android:translateX="{dx:.4f}"
        android:translateY="{dy:.4f}"
        android:scaleX="{scale:.6f}"
        android:scaleY="{scale:.6f}">
{paths}    </group>
</vector>
"""


def android(mark):
    """The adaptive icon: 108 dp, of which a launcher shows the middle 72."""
    scale = mark.scale_into(*FIT) * 72 / TILE
    drawable = os.path.join(ANDROID, 'drawable')
    write(os.path.join(drawable, 'ic_launcher_background.xml'), f"""\
<?xml version="1.0" encoding="utf-8"?>
<!-- Written by design/logo/export.py. -->
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="{PAPER}" />
</shape>
""")
    write(os.path.join(drawable, 'ic_launcher_foreground.xml'), android_vector(mark, 108, scale, (INK, ROSE)))
    # A themed icon is one colour, which the launcher picks.
    write(os.path.join(drawable, 'ic_launcher_monochrome.xml'), android_vector(mark, 108, scale, ('#000000', '#000000')))


def pictures(mark):
    """Every picture file, cut down from one large rendering of each shape."""
    os.makedirs(OUT, exist_ok=True)
    write(os.path.join(OUT, 'nazzil-icon.svg'), tile(mark))
    write(os.path.join(OUT, 'nazzil-lettering.svg'), lettering(mark))
    write(os.path.join(OUT, 'nazzil-lettering-light.svg'), lettering(mark, letters='#F5F3EE'))

    big = 1024
    scratch = tempfile.mkdtemp(prefix='nazzil-logo-')
    try:
        page = os.path.join(scratch, 'shapes.html')
        with open(page, 'w', encoding='utf-8') as handle:
            handle.write(
                '<!doctype html><meta charset="utf-8"><style>*{margin:0}body{width:%dpx}'
                'div{width:%dpx;height:%dpx}svg{display:block}</style>' % (big, big, big)
                + f'<div data-shot="square">{tile(mark, size=big)}</div>'
            )
        profile = tempfile.mkdtemp(prefix='nazzil-shoot-')
        process, port = shoot.start_chrome(profile)
        try:
            tab = shoot.Tab(shoot.page_socket(port))
            tab.call('Page.enable')
            shoot.shoot(tab, page, scratch, 1, True, None)
        finally:
            process.kill()
            process.wait()
            shutil.rmtree(profile, ignore_errors=True)
        square = Image.open(os.path.join(scratch, 'shapes-square.png')).convert('RGB')
    finally:
        shutil.rmtree(scratch, ignore_errors=True)

    def save(image, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        image.save(path, optimize=True)
        print(os.path.relpath(path, os.path.join(HERE, '..', '..')), image.size)

    def sized(side):
        return square.resize((side, side), Image.LANCZOS)

    def rounded(side, radius):
        """The square with its corners cut, for the places that show the file as it is."""
        scale = 4
        mask = Image.new('L', (side * scale, side * scale), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, side * scale - 1, side * scale - 1), radius=radius * side * scale, fill=255,
        )
        image = sized(side).convert('RGBA')
        image.putalpha(mask.resize((side, side), Image.LANCZOS))
        return image

    save(sized(big), os.path.join(OUT, 'nazzil-icon-1024.png'))

    # Android before adaptive icons, and anything that asks for the plain file.
    for folder, side in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        save(rounded(side, 0.225), os.path.join(ANDROID, f'mipmap-{folder}', 'ic_launcher.png'))
        save(rounded(side, 0.5), os.path.join(ANDROID, f'mipmap-{folder}', 'ic_launcher_round.png'))

    # iOS cuts the corners itself and refuses a file with transparency.
    ios = os.path.join(FLUTTER, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    for name in sorted(os.listdir(ios)):
        if name.endswith('.png'):
            side = Image.open(os.path.join(ios, name)).size[0]
            save(sized(side), os.path.join(ios, name))

    # macOS shows the file as it is, so the corners are cut here, with the margin its icons keep.
    mac = os.path.join(FLUTTER, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    for name in sorted(os.listdir(mac)):
        if name.endswith('.png'):
            side = Image.open(os.path.join(mac, name)).size[0]
            inner = round(side * 824 / 1024)
            canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
            canvas.alpha_composite(rounded(inner, 0.225), ((side - inner) // 2, (side - inner) // 2))
            save(canvas, os.path.join(mac, name))

    windows = os.path.join(FLUTTER, 'windows', 'runner', 'resources', 'app_icon.ico')
    rounded(256, 0.225).save(windows, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print(os.path.relpath(windows, os.path.join(HERE, '..', '..')))


def main():
    mark = Mark()
    dart(mark)
    android(mark)
    if '--no-pictures' not in sys.argv:
        pictures(mark)


if __name__ == '__main__':
    main()
