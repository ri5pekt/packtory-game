# Agent instructions — generate Packtory UI icons via Replicate

Handoff doc for an AI coding agent working in this repo. Follow these steps
exactly when asked to create or regenerate HUD icons.

---

## Goal

Produce **128×128 transparent PNG** icons in:

```
assets/ui/icons/{id}.png
```

Icons are loaded at runtime by `scripts/ui/icon_registry.gd` (`IconRegistry.get_icon(id)`).

---

## Prerequisites

1. **Replicate account** + API token from  
   https://replicate.com/account/api-tokens  
2. **Python 3** with **Pillow**: `pip install Pillow`  
3. Token in environment (**never commit the token**):

```powershell
# PowerShell (Windows)
$env:REPLICATE_API_TOKEN = "r8_…"
```

```bash
# bash
export REPLICATE_API_TOKEN="r8_…"
```

4. Network access to `api.replicate.com` and `replicate.delivery`.

---

## Critical rules (read before generating)

| Rule | Why |
|------|-----|
| **Do NOT prompt for “transparent background” on Seedream 4.5** | Model outputs **JPEG only** — no alpha channel |
| **Do NOT rely on chroma key (magenta/green)** | JPEG + AI shadows leave pink/red fringes in Godot |
| **Always run background removal after generation** | Use `bria/remove-background` on Replicate |
| **Use plain light gray backdrop in prompts** | `#E8E8E8` — easy for Bria to remove |
| **width/height must be ≥ 1024** for Seedream 4.5 | API returns 422 otherwise |
| **Never store API tokens in repo files** | Use env var only |

---

## Recommended pipeline (use project scripts)

### A. Generate one or all icons (full pipeline)

1. Edit or add an entry in `tools/icon_manifest.json`:

```json
{
  "id": "my_icon",
  "prompt": "Short description of the subject only"
}
```

The `style_suffix` in the manifest is appended automatically — do not repeat it in `prompt`.

2. Run:

```powershell
cd c:\Users\denis_particleformen\Desktop\godot-projects\packtory
python tools/generate_icons.py my_icon
```

Or all icons:

```powershell
python tools/generate_icons.py
```

**What the script does:**

1. POST → `bytedance/seedream-4.5` (image generation)  
2. Saves raw JPEG → `assets/ui/icons/raw/{id}.jpg`  
3. Calls `tools/remove_icon_background.py` → Bria bg removal  
4. Writes final PNG → `assets/ui/icons/{id}.png` (128×128, trimmed, RGBA)

**Expected runtime:** ~20–30 s per icon (generation + bg removal).

### B. Re-run background removal only (cheaper, ~3 s/icon)

If raw JPEGs already exist and only transparency is wrong:

```powershell
python tools/remove_icon_background.py
```

Or one file:

```powershell
python tools/remove_icon_background.py assets/ui/icons/raw/pickup.jpg
```

---

## Manual API calls (if scripts fail)

### Step 1 — Generate image (Seedream 4.5)

Save request body to a JSON file (PowerShell mangles inline JSON):

`tools/_request_gen.json`:

```json
{
  "input": {
    "size": "2K",
    "width": 1024,
    "height": 1024,
    "prompt": "YOUR SUBJECT PROMPT. Single isolated game UI icon for a cozy cartoon warehouse tycoon mobile game. Low-poly friendly, warm saturated colors, soft rounded 3D shapes, subtle shading. Centered subject on a plain solid light gray background (#E8E8E8). No text, no watermark, no rounded app-icon card frame, no floor shadow.",
    "max_images": 1,
    "image_input": [],
    "aspect_ratio": "1:1",
    "sequential_image_generation": "disabled"
  }
}
```

```powershell
curl -s -X POST `
  -H "Authorization: Bearer $env:REPLICATE_API_TOKEN" `
  -H "Content-Type: application/json" `
  -H "Prefer: wait" `
  -d "@tools/_request_gen.json" `
  "https://api.replicate.com/v1/models/bytedance/seedream-4.5/predictions" `
  -o tools/_response_gen.json
```

Read `output[0]` URL from the response JSON. Download:

```powershell
curl -s -L "<output_url>" -o assets/ui/icons/raw/my_icon.jpg
```

### Step 2 — Remove background (Bria)

Use the Python script (handles base64 upload):

```powershell
python tools/remove_icon_background.py assets/ui/icons/raw/my_icon.jpg
```

**API endpoint used internally:**

```
POST https://api.replicate.com/v1/models/bria/remove-background/predictions
Body: { "input": { "image": "<data-uri or url>" } }
```

---

## Prompt template for new icons

**Subject line** (unique per icon, in manifest `prompt` field):

```
A [subject], product/action inventory icon, simple and readable at small size
```

**Style suffix** (already in manifest — do not duplicate):

```
Single isolated game UI icon for a cozy cartoon warehouse tycoon mobile game.
Low-poly friendly, warm saturated colors, soft rounded 3D shapes, subtle shading.
Centered subject on a plain solid light gray background (#E8E8E8).
No text, no watermark, no rounded app-icon card frame, no floor shadow.
Background will be removed automatically — keep the subject cleanly separated from the backdrop.
```

---

## Verify output before finishing

Run this check (agent should execute and confirm):

```powershell
python -c "
from PIL import Image
from pathlib import Path
p = Path('assets/ui/icons/my_icon.png')
img = Image.open(p).convert('RGBA')
w, h = img.size
trans = sum(1 for y in range(h) for x in range(w) if img.getpixel((x,y))[3] == 0)
corner = img.getpixel((0, 0))
print(f'{p.name}: {w}x{h}, transparent={trans}/{w*h}, corner={corner}')
assert trans > 2000, 'Too little transparency — bg removal failed'
assert corner[3] == 0, 'Corner not transparent — red/magenta fringe likely'
print('OK')
"
```

**Pass criteria:**

- Size is **128×128**
- Corner alpha is **0** (fully transparent)
- At least **~2000+** transparent pixels (subject is centered, rest is clear)

---

## Wire icon into the game (after PNG exists)

1. **Context menu action** — id must match action id in `gameplay_input.gd`  
   (e.g. `go_here`, `take`, `put`). Icons load automatically via `IconRegistry.action_icon(id)`.

2. **Product icon** — id must match `ProductCatalog.PRODUCTS` key  
   (e.g. `book`, `mouse`). Used by inventory UI and shelf labels.

3. **No code change needed** if `{id}.png` exists and id matches.

4. Ask user to **reimport** in Godot: select `assets/ui/icons/`, Reimport.  
   Compress mode: **Lossless** (preserves alpha).

---

## Current icon ids (manifest)

| id | Purpose |
|----|---------|
| `go_here` | Walk to tile |
| `take` | Take from shelf |
| `put` | Stock shelf |
| `pickup` | Pick up delivery box |
| `take_order` | Take customer order |
| `fulfill_order` | Deliver package |
| `pack_order` | Pack at table |
| `coin` | Money HUD |
| `headphones`, `hair_dryer`, `mouse`, `package` | Product types |

To add a product icon: add product to `ProductCatalog`, add manifest entry, run `generate_icons.py {id}`.

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `422 width/height Must be >= 1024` | Set `"width": 1024, "height": 1024` in request |
| `Set REPLICATE_API_TOKEN first` | Export token in shell before running scripts |
| Red/pink background in Godot | Re-run `python tools/remove_icon_background.py` |
| `404` on background model | Use exact path `bria/remove-background` (not `851-labs/...`) |
| PowerShell JSON parse error | Always use `-d "@file.json"`, never inline JSON |
| Icon not showing in game | Check filename `{id}.png` matches action/product id; reimport in Godot |

---

## Files reference

| Path | Role |
|------|------|
| `tools/icon_manifest.json` | Prompts + ids |
| `tools/generate_icons.py` | Full generate + bg removal |
| `tools/remove_icon_background.py` | Bria bg removal only |
| `tools/process_ui_icon.py` | Legacy chroma-key (avoid for new icons) |
| `assets/ui/icons/raw/*.jpg` | Seedream output (intermediate) |
| `assets/ui/icons/*.png` | Final HUD assets |
| `scripts/ui/icon_registry.gd` | Runtime loader |
| `docs/ai-asset-generation.md` | Human-readable overview |

---

## Example agent task checklist

When user says “generate icon for X”:

- [ ] Add `{ "id": "x", "prompt": "..." }` to `tools/icon_manifest.json`
- [ ] Confirm `REPLICATE_API_TOKEN` is set
- [ ] Run `python tools/generate_icons.py x`
- [ ] Verify PNG transparency (Python check above)
- [ ] Confirm id matches game code (action or product id)
- [ ] Tell user to reimport `assets/ui/icons/` in Godot if editor is open
