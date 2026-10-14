#!/usr/bin/env python3
"""アプリのアイコン(Tools/AppIcon.icns)を生成する。LED が並ぶパネルの図柄で、自作。

使い方: python3 Tools/gen_app_icon.py   (Pillow と macOS の iconutil が必要)
"""
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
RED = (255, 42, 26)
AMBER = (255, 154, 46)
DIM = (74, 28, 30)

# 1 が点灯。上の段はアドレスの下位 8 ビット、下の段はデータの 8 ビットに見立てた並び
ROWS = [
    ("addr", [0, 0, 1, 1, 0, 1, 0, 1], RED),
    ("data", [1, 0, 1, 0, 0, 1, 1, 0], RED),
    ("flag", [0, 1, 0, 0, 1, 0, 0, 1], AMBER),
]


def build_master() -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    margin = 100
    box = (margin, margin, SIZE - margin, SIZE - margin)
    radius = 185

    # 本体: 暗い青の角丸四角に、縦のグラデーション
    body = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    grad = Image.new("RGBA", (SIZE, SIZE))
    gd = ImageDraw.Draw(grad)
    for y in range(SIZE):
        k = y / SIZE
        gd.line([(0, y), (SIZE, y)], fill=(int(30 - 14 * k), int(38 - 18 * k), int(58 - 26 * k), 255))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius, fill=255)
    body.paste(grad, (0, 0), mask)

    # 影
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((box[0], box[1] + 18, box[2], box[3] + 18), radius, fill=(0, 0, 0, 120))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(22)))
    img.alpha_composite(body)

    # 縁の細い明るい線
    ImageDraw.Draw(img).rounded_rectangle(box, radius, outline=(255, 255, 255, 38), width=3)

    # LED の光(下に敷く)とLED 本体
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    leds = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gdraw, ldraw = ImageDraw.Draw(glow), ImageDraw.Draw(leds)
    cols = 8
    left, right = 190, SIZE - 190
    step = (right - left) / (cols - 1)
    rows_y = [345, 512, 679]
    r = 40
    for (name, bits, color), cy in zip(ROWS, rows_y):
        for i, bit in enumerate(bits):
            cx = left + step * i
            if bit:
                gdraw.ellipse((cx - r * 1.9, cy - r * 1.9, cx + r * 1.9, cy + r * 1.9), fill=color + (170,))
                ldraw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color + (255,))
                hi = tuple(min(255, c + 90) for c in color)
                ldraw.ellipse((cx - r * 0.55, cy - r * 0.62, cx + r * 0.15, cy + r * 0.05), fill=hi + (255,))
            else:
                ldraw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=DIM + (255,))
                ldraw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, 22), width=3)
    glow = glow.filter(ImageFilter.GaussianBlur(34))
    clipped = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    clipped.paste(glow, (0, 0), mask)   # 光は本体の外へ出さない
    img.alpha_composite(clipped)
    img.alpha_composite(leds)
    return img


def build_ios_master() -> Image.Image:
    """iOS 用。角丸も影も付けず、全面を塗る(角の丸めは OS が行う)。透明は使わない。"""
    img = Image.new("RGB", (SIZE, SIZE))
    d = ImageDraw.Draw(img)
    for y in range(SIZE):
        k = y / SIZE
        d.line([(0, y), (SIZE, y)], fill=(int(30 - 14 * k), int(38 - 18 * k), int(58 - 26 * k)))
    base = img.convert("RGBA")
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    leds = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gdraw, ldraw = ImageDraw.Draw(glow), ImageDraw.Draw(leds)
    left, right = 150, SIZE - 150
    step = (right - left) / 7
    r = 46
    for (_, bits, color), cy in zip(ROWS, [330, 512, 694]):
        for i, bit in enumerate(bits):
            cx = left + step * i
            if bit:
                gdraw.ellipse((cx - r * 1.9, cy - r * 1.9, cx + r * 1.9, cy + r * 1.9), fill=color + (170,))
                ldraw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color + (255,))
                hi = tuple(min(255, c + 90) for c in color)
                ldraw.ellipse((cx - r * 0.55, cy - r * 0.62, cx + r * 0.15, cy + r * 0.05), fill=hi + (255,))
            else:
                ldraw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=DIM + (255,))
                ldraw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, 22), width=3)
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(34)))
    base.alpha_composite(leds)
    return base.convert("RGB")


def main() -> None:
    out = Path(__file__).resolve().parent / "AppIcon.icns"
    master = build_master()
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for base in (16, 32, 128, 256, 512):
            master.resize((base, base), Image.LANCZOS).save(iconset / f"icon_{base}x{base}.png")
            master.resize((base * 2, base * 2), Image.LANCZOS).save(iconset / f"icon_{base}x{base}@2x.png")
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(out)], check=True)
    print(f"生成: {out}")
    ios = out.parent.parent / "iOS/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    ios.parent.mkdir(parents=True, exist_ok=True)
    build_ios_master().save(ios)
    print(f"生成: {ios}")


if __name__ == "__main__":
    main()
