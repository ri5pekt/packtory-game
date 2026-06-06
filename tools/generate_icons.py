#!/usr/bin/env python3
"""Generate UI icons: Seedream image -> Bria background removal -> HUD PNG."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

from load_env import load_project_env

ROOT = Path(__file__).resolve().parents[1]
load_project_env()
MANIFEST = Path(__file__).with_name("icon_manifest.json")
RAW_DIR = ROOT / "assets" / "ui" / "icons" / "raw"
OUT_DIR = ROOT / "assets" / "ui" / "icons"
GEN_MODEL = "https://api.replicate.com/v1/models/bytedance/seedream-4.5/predictions"
BG_SCRIPT = Path(__file__).with_name("remove_icon_background.py")


def _post_replicate(token: str, prompt: str, size: int) -> str:
    body = {
        "input": {
            "size": "2K",
            "width": size,
            "height": size,
            "prompt": prompt,
            "max_images": 1,
            "image_input": [],
            "aspect_ratio": "1:1",
            "sequential_image_generation": "disabled",
        }
    }
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        GEN_MODEL,
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Prefer": "wait",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        payload = json.load(resp)
    if payload.get("error"):
        raise RuntimeError(payload["error"])
    if payload.get("status") != "succeeded":
        raise RuntimeError(f"Prediction failed: {payload.get('status')}")
    output = payload.get("output") or []
    if not output:
        raise RuntimeError("No output URL in response")
    return str(output[0])


def _download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(url, dest)


def _remove_bg(raw: Path, out: Path, size: int) -> None:
    subprocess.run(
        [
            sys.executable,
            str(BG_SCRIPT),
            str(raw),
            "-o",
            str(out.parent),
            "--size",
            str(size),
        ],
        check=True,
    )


def main() -> int:
    token = os.environ.get("REPLICATE_API_TOKEN", "").strip()
    if not token:
        print("Set REPLICATE_API_TOKEN in .env (see .env.example).", file=sys.stderr)
        return 1

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    suffix = manifest.get("style_suffix", "")
    size = int(manifest.get("size", 1024))
    output_size = int(manifest.get("output_size", 128))
    only: set[str] = set(sys.argv[1:])

    for entry in manifest["icons"]:
        icon_id = entry["id"]
        if only and icon_id not in only:
            continue

        out_png = OUT_DIR / f"{icon_id}.png"
        raw_jpg = RAW_DIR / f"{icon_id}.jpg"

        prompt = f"{entry['prompt']}. {suffix}"
        print(f"Generating {icon_id}…")
        try:
            url = _post_replicate(token, prompt, size)
            _download(url, raw_jpg)
            _remove_bg(raw_jpg, out_png, output_size)
            print(f"  -> {out_png.relative_to(ROOT)}")
        except Exception as exc:  # noqa: BLE001
            print(f"  FAILED {icon_id}: {exc}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
