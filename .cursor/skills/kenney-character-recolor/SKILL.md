---
name: kenney-character-recolor
description: >-
  Recolor Kenney mini-character row-2 variants in Blender (packtory_characters_lineup.blend)
  by swapping colormap atlas swatches on separate body/head images. Use when changing character
  shirt, pants, shoes, hair, ribbon, or skin in Blender, writing paint_row2 scripts, or fixing
  botched Kenney texture/UV recolors.
---

# Kenney character recolor (Packtory)

## Scene layout

- Blend file: `blender/packtory_characters_lineup.blend`
- Row 1: collection `Packtory Characters` — originals, **never edit**
- Row 2: collection `Packtory Characters Row 2` — color variants
- Armature names: `character-female-a_row2`, `character-female-b_row2`, etc.
- Each armature has two meshes: `head-mesh`, `body-mesh`
- Scripts live in: `tools/blender-mcp/`

## Core rule (what actually works)

Kenney mini-characters use **two colormap images per character**:

| Mesh | Material pattern | What it tints |
|------|------------------|---------------|
| `body-mesh` | `colormap_{id}_row2_body` | shirt, pants/skirt, shoes, hands |
| `head-mesh` | `colormap_{id}_row2_head` | hair, ribbon/headband, face skin, eyes |

**Always:**

1. **Copy fresh** body + head images from row-1 (row-2 gets its own image copies; row-1 stays untouched).
2. **Replace all pixels** in each HSV band on the correct image (`replace_matching`) — Kenney uses multiple swatches per garment.
3. **Exclude skin** from every garment filter (`is_skin` check first).
4. Run in **Object Mode** unless using selection fallback.
5. **Ctrl+S** after run.

**Never:**

- Paint by atlas **texel rows** or use **radius bleed** on texels (Kenney atlases are horizontal bands → stripes on face/hair).
- Change **UV coordinates** or move UV islands.
- Use **Hue/Saturation** shader nodes (`Row2HueSat`) — tints skin/hair wrongly.
- Pick **one swatch via UV sampling** only — misses alternate swatches (half-green shirt bug).
- Run object-mode mesh loops while in **Edit Mode** (`uv_layers.active.data` is empty → crash).
- Apply head filters to body image or vice versa.

## Workflow checklist

```
- [ ] User restored row-2 character OR script copies fresh from row-1
- [ ] Identify target: body-only vs head-only changes
- [ ] Define HSV filters + target RGB per part
- [ ] is_skin excluded from all garment filters
- [ ] Orange/peach garments: require saturation >= 0.28 (skirt/ribbon ≠ skin)
- [ ] Print pixel counts; expect thousands for shirts, not ~0
- [ ] User saves blend
```

## Skin guard (required)

```python
def is_skin(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > 0.93 and s < 0.12:
        return False
    return 0.03 <= h <= 0.14 and s < 0.45 and 0.28 <= v <= 0.92
```

Peach skirt/ribbon sits near skin in hue — use **high saturation** for orange garments:

```python
def is_orange_garment(r, g, b):
    if is_skin(r, g, b):
        return False
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.03 <= h <= 0.12 and s >= 0.28 and v >= 0.50
```

## Copy fresh material (required boilerplate)

```python
def get_tex_node(mat):
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            return node

def copy_fresh_material(src_mesh, dst_mesh, part, char_id):
    mat_name = "colormap_%s_row2_%s" % (char_id, part)
    for block in (bpy.data.images.get(mat_name),):
        if block:
            bpy.data.images.remove(block)
    old_mat = bpy.data.materials.get(mat_name)
    if old_mat:
        bpy.data.materials.remove(old_mat)
    src_node = get_tex_node(src_mesh.data.materials[0])
    new_img = src_node.image.copy()
    new_img.name = mat_name
    new_mat = src_mesh.data.materials[0].copy()
    new_mat.name = mat_name
    get_tex_node(new_mat).image = new_img
    dst_mesh.data.materials[0] = new_mat
    return new_img
```

## Replace all swatches in a band

```python
def replace_matching(img, test_fn, new_rgb):
    px = list(img.pixels)
    n = 0
    nr, ng, nb = new_rgb
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01 or not test_fn(r, g, b):
            continue
        px[i : i + 3] = [nr, ng, nb]
        n += 1
    img.pixels = px
    img.update()
    return n
```

## Body vs head — why ribbon ≠ shirt

Even when ribbon **looks** the same color as shirt/skirt on the model, they are often on **different images**. Example: female-b yellow shirt (body) + yellow headband (head) → pink shirt on body image, pink ribbon on head image independently.

Other character may have orange ribbon (head) + orange skirt (body) — still **two images**, same filter logic, different `replace_matching` calls.

## Proven character recipes

### female-a (`paint_row2_female_a.py`)

**Body:** purple shirt → green (`hue 0.68–0.88`), lighten skin  
**Head:** dark grey hair (`0.16 <= v < 0.42`), dark eyes (`v < 0.16`), lighten skin  

### female-b (`paint_row2_female_b.py`) ✓ verified

**Body:** yellow shirt → pink, purple pants → brown, grey shoes → dark blue  
**Head:** bright yellow headband only → pink (`hue 0.08–0.18`, `s > 0.22`, `v >= 0.68`)  
Do **not** recolor hair unless user asks — bun cores on skin swatch stay tan.

### female-c (`paint_row2_female_c.py`) — needs tuning

**Target:** turquoise shirt + shoes, blue skirt + ribbon  
**Pitfall:** peach skirt/ribbon overlaps skin HSV — must use `is_orange_garment` with `s >= 0.28` and `is_skin` exclusion; shirt filter must exclude skin (`hue 0.50–0.62` only).

## When auto filters fail

1. **Reset:** run `reset_row2_to_row1_colors.py` or reload blend.
2. **Ribbon only:** select ribbon faces in Edit Mode → `paint_selected_ribbon_pink.py` (bmesh, exact texels, no radius).
3. **Debug swatches:** `analyze_body_colormap.py` on selected body-mesh → writes `tools/blender-mcp/debug/colormap_analysis.txt`.

## Creating a new row-2 script

1. Copy `tools/blender-mcp/paint_row2_female_b.py` as template (simplest working case).
2. Set `CHAR_ID`, target RGB values, and HSV test functions per part.
3. Apply body filters to `body_img` only; head filters to `head_img` only.
4. Add `if is_skin(r,g,b): return False` to every garment test.
5. Name file `paint_row2_{char_id_short}.py`.

Full template: [reference.md](reference.md)

## Running in Blender

1. Open `packtory_characters_lineup.blend`
2. **Scripting** workspace → open or paste script → **Run Script**
3. Check console for pixel counts
4. **Ctrl+S**

## Anti-patterns (learned the hard way)

| Mistake | Symptom |
|---------|---------|
| Full-head HSV hair replace | Blonde chin, pink eyes |
| Texel paint with radius ≥ 1 | Horizontal stripes on face/hair |
| Single-swatch UV pick for shirt | Half green / half purple shirt |
| Skirt filter without skin exclusion | Blue/turquoise skin |
| `get_img(mat).image = x` when helper returns Image | `AttributeError: 'Image' has no attribute 'image'` — assign via **tex node**: `get_tex_node(mat).image = new_img` |

## Related game code

Runtime tint (not Blender atlas): `scripts/dev/character_variation.gd` — albedo multiply on body only. Blender scripts are for export/asset lineup workflow.
