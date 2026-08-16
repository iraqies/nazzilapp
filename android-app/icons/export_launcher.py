from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "app" / "src" / "main" / "res"
SRC = Path(__file__).resolve().parent / "nazzil-3-dark.png"
PINK = (255, 77, 141, 255)
SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def font(size):
    return ImageFont.truetype(r"C:\Windows\Fonts\ariblk.ttf", size)


def draw_n(img, color, size):
    draw = ImageDraw.Draw(img)
    f = font(int(size * 0.42))
    box = draw.textbbox((0, 0), "N", font=f)
    w, h = box[2] - box[0], box[3] - box[1]
    x = (size - w) / 2 - box[0]
    y = (size - h) / 2 - box[1]
    draw.text((x, y), "N", font=f, fill=color)


def main():
    source = Image.open(SRC).convert("RGBA")
    for folder, size in SIZES.items():
        dest = RES / folder
        dest.mkdir(parents=True, exist_ok=True)
        icon = source.resize((size, size), Image.Resampling.LANCZOS)
        icon.save(dest / "ic_launcher.png")
        icon.save(dest / "ic_launcher_round.png")

    fg_size = 432
    fg = Image.new("RGBA", (fg_size, fg_size), (0, 0, 0, 0))
    draw_n(fg, PINK, fg_size)
    drawable = RES / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    fg.save(drawable / "ic_launcher_foreground.png")

    mono = Image.new("RGBA", (fg_size, fg_size), (0, 0, 0, 0))
    draw_n(mono, (0, 0, 0, 255), fg_size)
    mono.save(drawable / "ic_launcher_monochrome.png")
    print("exported launcher assets")


if __name__ == "__main__":
    main()
