"""One-off script: draws a simple on-brand launcher icon (a t-shirt on the
app's warm terracotta background) and writes it at every mipmap density.
Not part of the app; run manually with `python tool/generate_launcher_icon.py`
whenever the icon needs to change.
"""

from pathlib import Path

from PIL import Image, ImageDraw

BACKGROUND = (138, 90, 52, 255)  # matches ColorScheme.fromSeed primary
SHIRT = (251, 244, 239, 255)  # matches scaffoldBackgroundColor (light)

SHIRT_POINTS = [
    (30, 18),
    (40, 10),
    (50, 18),
    (60, 10),
    (70, 18),
    (92, 30),
    (78, 46),
    (66, 36),
    (66, 92),
    (34, 92),
    (34, 36),
    (22, 46),
    (8, 30),
]

SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

SUPERSAMPLE = 4


def render(size: int) -> Image.Image:
    canvas = size * SUPERSAMPLE
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    corner = int(canvas * 0.22)
    draw.rounded_rectangle([0, 0, canvas - 1, canvas - 1], radius=corner, fill=BACKGROUND)

    margin = canvas * 0.12
    span = canvas - margin * 2
    scaled = [(margin + x / 100 * span, margin + y / 100 * span) for x, y in SHIRT_POINTS]
    draw.polygon(scaled, fill=SHIRT)

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    res_dir = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "res"
    for folder, size in SIZES.items():
        out_path = res_dir / folder / "ic_launcher.png"
        render(size).save(out_path)
        print(f"wrote {out_path} ({size}x{size})")


if __name__ == "__main__":
    main()
