#!/usr/bin/env python3
"""Remove solid background from AI-generated UI icons and resize for Godot HUD."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

MAGENTA = (255, 0, 255)
CHROMA_PRESETS = {
    "magenta": MAGENTA,
    "green": None,
    "auto": None,
}


def _sample_background(image: Image.Image, margin: int = 8) -> tuple[int, int, int]:
    w, h = image.size
    samples: list[tuple[int, int, int]] = []
    for x in range(margin):
        for y in range(h):
            samples.append(image.getpixel((x, y))[:3])
            samples.append(image.getpixel((w - 1 - x, y))[:3])
    for y in range(margin):
        for x in range(w):
            samples.append(image.getpixel((x, y))[:3])
            samples.append(image.getpixel((x, h - 1 - y))[:3])
    r = sum(p[0] for p in samples) // len(samples)
    g = sum(p[1] for p in samples) // len(samples)
    b = sum(p[2] for p in samples) // len(samples)
    return r, g, b


def _color_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def _matches_background(
    pixel: tuple[int, int, int],
    bg: tuple[int, int, int],
    tolerance: float,
) -> bool:
    return _color_distance(pixel, bg) <= tolerance


def _background_mask(
    rgb: Image.Image,
    bg: tuple[int, int, int],
    tolerance: float,
) -> list[list[bool]]:
    w, h = rgb.size
    is_bg = [[False] * w for _ in range(h)]
    stack: list[tuple[int, int]] = []

    def try_push(x: int, y: int) -> None:
        if x < 0 or y < 0 or x >= w or y >= h or is_bg[y][x]:
            return
        if not _matches_background(rgb.getpixel((x, y)), bg, tolerance):
            return
        is_bg[y][x] = True
        stack.append((x, y))

    for x in range(w):
        try_push(x, 0)
        try_push(x, h - 1)
    for y in range(h):
        try_push(0, y)
        try_push(w - 1, y)

    while stack:
        x, y = stack.pop()
        try_push(x - 1, y)
        try_push(x + 1, y)
        try_push(x, y - 1)
        try_push(x, y + 1)

    return is_bg


def _is_magenta_family(pixel: tuple[int, int, int]) -> bool:
    r, g, b = pixel
    return r >= 120 and b >= 120 and g <= max(r, b) * 0.55


def _is_magenta_backdrop(pixel: tuple[int, int, int], tolerance: float) -> bool:
    if _is_magenta_family(pixel):
        return True
    if _color_distance(pixel, MAGENTA) <= tolerance:
        return True
    r, g, b = pixel
    # Light lavender/pink rounded “app icon” card the model often adds.
    if r >= 165 and b >= 165 and g >= 115 and (r + b) > g * 1.45:
        return True
    if r >= 210 and b >= 210 and g >= 195:
        return True
    return False


def _is_greenish_backdrop(pixel: tuple[int, int, int], bg: tuple[int, int, int]) -> bool:
    return pixel[1] >= pixel[0] - 20 and pixel[1] >= pixel[2] - 20 and bg[1] >= bg[0]


def remove_background(
    image: Image.Image,
    bg_color: tuple[int, int, int] | None,
    tolerance: float,
    edge_softness: float,
    aggressive: bool,
    use_magenta: bool,
) -> Image.Image:
    rgb = image.convert("RGB")
    bg = MAGENTA if use_magenta else (bg_color or _sample_background(rgb))
    rgba = rgb.convert("RGBA")
    pixels = rgba.load()
    w, h = rgba.size
    soft = max(edge_softness, 1.0)
    bg_mask = _background_mask(rgb, bg, tolerance)
    shadow_tol = tolerance * 1.35 if aggressive else tolerance

    for y in range(h):
        for x in range(w):
            pixel = rgb.getpixel((x, y))
            dist = _color_distance(pixel, bg)
            is_backdrop = bg_mask[y][x]
            if use_magenta:
                if _is_magenta_backdrop(pixel, tolerance):
                    is_backdrop = True
            elif aggressive and not is_backdrop:
                if dist <= shadow_tol and _is_greenish_backdrop(pixel, bg):
                    is_backdrop = True
            if is_backdrop:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            if dist <= tolerance + soft:
                t = (dist - tolerance) / soft
                r, g, b = pixel
                alpha = int(255 * max(0.0, min(1.0, t)))
                pixels[x, y] = (r, g, b, alpha)

    return rgba


def trim_and_resize(image: Image.Image, size: int, padding: int) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        return image
    cropped = image.crop(bbox)
    cw, ch = cropped.size
    side = max(cw, ch) + padding * 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox = (side - cw) // 2
    oy = (side - ch) // 2
    canvas.paste(cropped, (ox, oy), cropped)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def process_icon(
    input_path: Path,
    output_path: Path,
    size: int,
    tolerance: float,
    edge_softness: float,
    padding: int,
    aggressive: bool,
    bg_mode: str,
) -> None:
    image = Image.open(input_path)
    use_magenta = bg_mode == "magenta"
    fixed_bg = MAGENTA if use_magenta else None
    if bg_mode == "auto":
        fixed_bg = None
    cutout = remove_background(
        image, fixed_bg, tolerance, edge_softness, aggressive, use_magenta
    )
    final = trim_and_resize(cutout, size, padding)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    final.save(output_path, format="PNG")
    print(f"Wrote {output_path} ({size}x{size}, RGBA)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Source JPG/PNG from Replicate")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output PNG (default: same name beside input, .png)",
    )
    parser.add_argument("--size", type=int, default=128, help="Output square size")
    parser.add_argument("--tolerance", type=float, default=75.0)
    parser.add_argument("--softness", type=float, default=16.0)
    parser.add_argument("--padding", type=int, default=4)
    parser.add_argument(
        "--bg",
        choices=["auto", "magenta", "green"],
        default="magenta",
        help="Backdrop key colour (magenta recommended for AI icons)",
    )
    parser.add_argument(
        "--no-aggressive",
        action="store_true",
        help="Disable extra shadow/backdrop cleanup",
    )
    args = parser.parse_args()

    if not args.input.is_file():
        print(f"Input not found: {args.input}", file=sys.stderr)
        return 1

    output = args.output or args.input.with_suffix(".png")
    process_icon(
        args.input,
        output,
        args.size,
        args.tolerance,
        args.softness,
        args.padding,
        not args.no_aggressive,
        args.bg,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
