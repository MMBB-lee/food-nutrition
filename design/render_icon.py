"""Render the Food Nuri icon's fixed geometry into HarmonyOS PNG assets."""

from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
MEDIA_DIRS = [
    ROOT / "AppScope/resources/base/media",
    ROOT / "entry/src/main/resources/base/media",
]
SCALE = 4
SIZE = 1024
INK = (17, 17, 17, 255)
GRAY = (236, 237, 235, 255)


def point(x, y):
    return round(x * SCALE), round(y * SCALE)


def bezier(p0, p1, p2, p3, steps=60):
    result = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        result.append(point(
            u**3 * p0[0] + 3 * u*u*t * p1[0] + 3 * u*t*t * p2[0] + t**3 * p3[0],
            u**3 * p0[1] + 3 * u*u*t * p1[1] + 3 * u*t*t * p2[1] + t**3 * p3[1],
        ))
    return result


def render_foreground():
    canvas = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    width = 34 * SCALE

    draw.ellipse((*point(210, 265), *point(750, 805)), outline=INK, width=width)

    leaf = (
        bezier((660, 323), (630, 238), (682, 178), (820, 165))
        + bezier((820, 165), (835, 293), (769, 345), (660, 323))[1:]
    )
    draw.line(leaf + [leaf[0]], fill=INK, width=width, joint="curve")

    hands = [point(480, 405), point(480, 535), point(605, 615)]
    draw.line(hands, fill=INK, width=width, joint="curve")
    for x, y in (hands[0], hands[-1]):
        radius = width // 2
        draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=INK)
    cx, cy = point(480, 535)
    radius = 23 * SCALE
    draw.ellipse((cx-radius, cy-radius, cx+radius, cy+radius), fill=INK)
    return canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def main():
    foreground = render_foreground()
    background = Image.new("RGBA", (SIZE, SIZE), GRAY)
    combined = Image.alpha_composite(background, foreground).convert("RGB")
    for media_dir in MEDIA_DIRS:
        media_dir.mkdir(parents=True, exist_ok=True)
        foreground.save(media_dir / "nutrition_icon_foreground.png")
        background.save(media_dir / "nutrition_icon_background.png")
    entry_media = MEDIA_DIRS[1]
    combined.save(entry_media / "nutrition_icon.png")
    combined.resize((144, 144), Image.Resampling.LANCZOS).save(
        entry_media / "nutrition_start_icon.png"
    )


if __name__ == "__main__":
    main()
