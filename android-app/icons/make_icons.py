from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = Path(__file__).resolve().parent
SIZE = 1024
PINK = (255, 77, 141)
DEEP = (194, 24, 91)
DARK = (20, 12, 18)
WHITE = (255, 255, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, start=PINK, end=DEEP):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = lerp(start, end, t)
    return img


def squircle_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def circle_mask(size):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    return mask


def apply_mask(rgb, mask):
    out = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
    out.paste(rgb.convert("RGBA"), mask=mask)
    return out


def font(size):
    for path in (
        r"C:\Windows\Fonts\ariblk.ttf",
        r"C:\Windows\Fonts\arialbd.ttf",
        r"C:\Windows\Fonts\seguisb.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def draw_n(img, color, size, y_shift=0):
    draw = ImageDraw.Draw(img)
    f = font(int(size * 0.62))
    text = "N"
    box = draw.textbbox((0, 0), text, font=f)
    w, h = box[2] - box[0], box[3] - box[1]
    x = (size - w) / 2 - box[0]
    y = (size - h) / 2 - box[1] + y_shift
    draw.text((x, y), text, font=f, fill=color)


def draw_n_drop(img, color, size):
    draw_n(img, color, size, y_shift=-int(size * 0.04))
    draw = ImageDraw.Draw(img)
    cx = size / 2
    top = size * 0.72
    tip = size * 0.86
    half = size * 0.075
    draw.polygon(
        [(cx - half, top), (cx + half, top), (cx, tip)],
        fill=color,
    )


def save(name, rgb, mask):
    path = OUT / name
    apply_mask(rgb, mask).save(path, "PNG")
    print(path)


def main():
    g = gradient(SIZE)
    dark = Image.new("RGB", (SIZE, SIZE), DARK)
    sq = squircle_mask(SIZE, int(SIZE * 0.22))
    circ = circle_mask(SIZE)

    heavy = g.copy()
    draw_n(heavy, WHITE, SIZE)
    save("nazzil-1-heavy.png", heavy, sq)

    drop = g.copy()
    draw_n_drop(drop, WHITE, SIZE)
    save("nazzil-2-drop.png", drop, sq)

    dark_n = dark.copy()
    draw_n(dark_n, PINK, SIZE)
    save("nazzil-3-dark.png", dark_n, sq)

    circle = g.copy()
    draw_n(circle, WHITE, SIZE)
    save("nazzil-4-circle.png", circle, circ)


if __name__ == "__main__":
    main()
