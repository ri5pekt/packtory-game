# AI image assets (Replicate)

Packtory UI icons live in `assets/ui/icons/` and load through `IconRegistry`.

**For AI agents:** see **[agent-replicate-icon-generation.md](./agent-replicate-icon-generation.md)** — step-by-step handoff with API calls, verification, and troubleshooting.

**Never commit API tokens.** Store yours in project-root `.env` (gitignored; copy from `.env.example`). Icon scripts load it automatically.

---

## The transparency problem (read this first)

| Approach | Works? | Notes |
|----------|--------|-------|
| **Seedream 4.5 + “transparent background” prompt** | No | Outputs **JPEG only** — no alpha channel ([API docs](https://docs.apiyi.com/en/api-capabilities/seedream-image/overview)) |
| **Seedream 5 + `output_format: png`** | Partial | PNG file, but usually **opaque white/gray** — not real alpha |
| **Chroma key (magenta/green) on JPEG** | Poor | JPEG compression + AI floor shadows + rounded “app icon” cards leave **pink/red fringes** |
| **Bria background removal (Replicate)** | **Yes** | Best option for this project — returns true transparent PNG |
| **Local `rembg` (Python)** | Yes | Good offline alternative; needs `pip install rembg[cpu]` |

**Recommended pipeline for Packtory:**

1. **Generate** icon with Seedream 4.5 on a **plain light gray** background  
2. **Remove background** with [`bria/remove-background`](https://replicate.com/bria/remove-background) on Replicate  
3. **Trim + resize** to 128×128 PNG for Godot  

---

## Quick start

```powershell
# One-time: copy .env.example → .env and paste your Replicate token

# Re-process existing raw JPEGs (fast, ~3s/icon):
python tools/remove_icon_background.py

# Generate everything from scratch (~20s/icon):
python tools/generate_icons.py

# One icon only:
python tools/generate_icons.py pickup
```

Manifest of prompts: `tools/icon_manifest.json`

---

## Prompt tips (generation step)

Because background removal is automatic, **do not** prompt for magenta/green chroma keys.

**Do prompt for:**

- Single isolated subject, centered
- Plain solid **light gray** backdrop (`#E8E8E8`)
- **No floor shadow**, no rounded app-icon card frame
- Cozy cartoon warehouse tycoon style, readable at 64px

**Example:**

> Single cartoon closed cardboard box icon, cozy game UI style, centered on plain light gray background, no shadow, no text.

Seedream 4.5 requires **width/height ≥ 1024**.

---

## Background removal (Bria)

```powershell
python tools/remove_icon_background.py assets/ui/icons/raw/pickup.jpg
```

Uses Replicate model `bria/remove-background` (~$0.001/image). Accepts local JPG/PNG via base64 data URI.

Output: `assets/ui/icons/{name}.png` — 128×128 RGBA.

### Alternative: local rembg

If you have rembg working locally:

```bash
pip install rembg[cpu] Pillow
rembg i input.jpg output.png
python tools/process_ui_icon.py output.png -o assets/ui/icons/icon.png --size 128
```

Use `isnet-general-use` model for icons. Enable `alpha_matting=True` for hair/fur (not needed for game icons).

---

## Icon set

| ID | Used for |
|----|----------|
| `go_here` | Walk to tile |
| `take` / `put` | Shelf pick / stock |
| `pickup` | Delivery box |
| `take_order` / `fulfill_order` / `pack_order` | Order flow |
| `waiting` | Customer hourglass bubble while order is in progress |
| `headphones`, `hair_dryer`, `mouse`, `package` | Products |
| `coin` | Money HUD (future) |

---

## Godot import

Icons must import as **lossless** textures with alpha:

- Project → Import → select `assets/ui/icons/*.png`
- Compress Mode: **Lossless** (or VRAM Compressed only if you verify alpha)
- Reimport after regenerating PNGs

In-game: `IconRegistry.get_icon("pickup")` → `Texture2D`

---

## Files

| Path | Purpose |
|------|---------|
| `tools/icon_manifest.json` | Prompts + ids |
| `tools/generate_icons.py` | Full generate + bg removal pipeline |
| `tools/remove_icon_background.py` | Bria bg removal only |
| `tools/process_ui_icon.py` | Legacy chroma-key trim/resize (fallback) |
| `.env` | Local `REPLICATE_API_TOKEN` (gitignored) |
| `.env.example` | Template — safe to commit |
| `assets/ui/icons/raw/` | Source JPEGs from Seedream |
| `assets/ui/icons/*.png` | Final HUD icons |
