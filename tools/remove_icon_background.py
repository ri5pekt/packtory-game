#!/usr/bin/env python3
"""Remove backgrounds from icon JPEGs using Replicate bria/remove-background."""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import urllib.request
from pathlib import Path

from PIL import Image

from load_env import load_project_env

ROOT = Path(__file__).resolve().parents[1]
load_project_env()
BG_MODEL = "https://api.replicate.com/v1/models/bria/remove-background/predictions"


def _data_uri(path: Path) -> str:
    mime = "image/jpeg" if path.suffix.lower() in {".jpg", ".jpeg"} else "image/png"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def remove_background_api(image_path: Path, token: str) -> Image.Image:
    body = json.dumps({"input": {"image": _data_uri(image_path)}}).encode("utf-8")
    req = urllib.request.Request(
        BG_MODEL,
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Prefer": "wait",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        payload = json.load(resp)
    if payload.get("status") != "succeeded":
        raise RuntimeError(payload.get("error") or payload.get("status"))
    url = payload.get("output")
    if not url:
        raise RuntimeError("No output URL from background remover")
    with urllib.request.urlopen(str(url), timeout=120) as img_resp:
        return Image.open(img_resp).convert("RGBA")


def trim_and_resize(image: Image.Image, size: int, padding: int) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        return image
    cropped = image.crop(bbox)
    side = max(cropped.size) + padding * 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox = (side - cropped.size[0]) // 2
    oy = (side - cropped.size[1]) // 2
    canvas.paste(cropped, (ox, oy), cropped)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def process_file(
    input_path: Path,
    output_path: Path,
    token: str,
    size: int,
    padding: int,
) -> None:
    cutout = remove_background_api(input_path, token)
    final = trim_and_resize(cutout, size, padding)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    final.save(output_path, format="PNG")
    transparent = sum(
        1
        for y in range(final.size[1])
        for x in range(final.size[0])
        if final.getpixel((x, y))[3] == 0
    )
    print(
        f"Wrote {output_path.relative_to(ROOT)} "
        f"({size}x{size}, {transparent}/{size * size} transparent px)"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "inputs",
        nargs="*",
        type=Path,
        help="JPEG/PNG files (default: all assets/ui/icons/raw/*)",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        default=ROOT / "assets" / "ui" / "icons",
        help="Directory for output PNGs",
    )
    parser.add_argument("--size", type=int, default=128)
    parser.add_argument("--padding", type=int, default=4)
    args = parser.parse_args()

    token = os.environ.get("REPLICATE_API_TOKEN", "").strip()
    if not token:
        print("Set REPLICATE_API_TOKEN in .env (see .env.example).", file=sys.stderr)
        return 1

    inputs = args.inputs
    if not inputs:
        raw_dir = ROOT / "assets" / "ui" / "icons" / "raw"
        inputs = sorted(raw_dir.glob("*.jpg")) + sorted(raw_dir.glob("*.jpeg"))

    if not inputs:
        print("No input images found.", file=sys.stderr)
        return 1

    for input_path in inputs:
        if not input_path.is_file():
            print(f"Skip missing {input_path}", file=sys.stderr)
            continue
        output_path = args.output_dir / f"{input_path.stem}.png"
        try:
            process_file(input_path, output_path, token, args.size, args.padding)
        except Exception as exc:  # noqa: BLE001
            print(f"FAILED {input_path.name}: {exc}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
