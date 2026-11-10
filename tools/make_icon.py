"""Generate Android launcher icons (rounded gradient square + 知)."""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = r"D:\work\zhixingligongflash\app\android\app\src\main\res"
SIZE = 1024

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\msyhbd.ttc",
    r"C:\Windows\Fonts\msyh.ttc",
    r"C:\Windows\Fonts\simhei.ttf",
    r"C:\Windows\Fonts\simsun.ttc",
]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def make_master():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    top = (47, 91, 255)
    bottom = (110, 139, 255)

    # vertical gradient
    grad = Image.new("RGBA", (SIZE, SIZE))
    gd = ImageDraw.Draw(grad)
    for y in range(SIZE):
        gd.line([(0, y), (SIZE, y)], fill=lerp(top, bottom, y / SIZE) + (255,))

    # rounded mask
    mask = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=int(SIZE * 0.23), fill=255)
    img.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(img)
    font = None
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            font = ImageFont.truetype(path, int(SIZE * 0.54))
            break
    if font is None:
        font = ImageFont.load_default()

    text = "知"
    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (SIZE - tw) / 2 - bbox[0]
    y = (SIZE - th) / 2 - bbox[1] - SIZE * 0.02
    # soft shadow
    d.text((x + 6, y + 10), text, font=font, fill=(20, 40, 120, 70))
    d.text((x, y), text, font=font, fill=(255, 255, 255, 255))
    return img


def main():
    master = make_master()
    targets = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in targets.items():
        out_dir = os.path.join(ROOT, folder)
        os.makedirs(out_dir, exist_ok=True)
        out = os.path.join(out_dir, "ic_launcher.png")
        master.resize((size, size), Image.LANCZOS).save(out)
        print("wrote", out, size)


if __name__ == "__main__":
    main()
