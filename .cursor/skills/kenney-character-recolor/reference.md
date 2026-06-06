# Kenney recolor — script template

Paste into Blender Scripting, adjust `CHAR_ID`, colors, and `is_*` filters.

```python
# paint_row2_TEMPLATE.py — Run in Object Mode -> Ctrl+S
import bpy
import colorsys

CHAR_ID = "character-female-X"  # change me
ARM_NAME = CHAR_ID + "_row2"

# Target RGB (0–1)
SHIRT_RGB = (0.35, 0.78, 0.38)
PANTS_RGB = (0.48, 0.30, 0.14)
SHOES_RGB = (0.10, 0.16, 0.42)
RIBBON_RGB = (0.95, 0.42, 0.62)  # head image only
HAIR_RGB = (0.28, 0.16, 0.07)    # head image only
SKIN_LIGHTEN = 1.18              # optional; 1.0 = skip


def get_tex_node(mat):
    if not mat or not mat.node_tree:
        return None
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            return node
    return None


def mesh_parts(arm):
    head = body = None
    for child in arm.children:
        if child.type != "MESH":
            continue
        n = child.name.lower()
        if "head" in n:
            head = child
        elif "body" in n:
            body = child
    return head, body


def find_row1_arm(char_id):
    obj = bpy.data.objects.get(char_id)
    if obj and obj.type == "ARMATURE":
        return obj
    col = bpy.data.collections.get("Packtory Characters")
    if col:
        for o in col.objects:
            if o.type == "ARMATURE" and o.name == char_id:
                return o
    return None


def copy_fresh_material(src_mesh, dst_mesh, part, char_id):
    mat_name = "colormap_%s_row2_%s" % (char_id, part)
    old_img = bpy.data.images.get(mat_name)
    old_mat = bpy.data.materials.get(mat_name)
    if old_img:
        bpy.data.images.remove(old_img)
    if old_mat:
        bpy.data.materials.remove(old_mat)
    src_node = get_tex_node(src_mesh.data.materials[0])
    if not src_node or not src_node.image:
        raise RuntimeError("No colormap on row-1 %s" % part)
    new_img = src_node.image.copy()
    new_img.name = mat_name
    new_mat = src_mesh.data.materials[0].copy()
    new_mat.name = mat_name
    dst_node = get_tex_node(new_mat)
    dst_node.image = new_img
    dst_mesh.data.materials[0] = new_mat
    return new_img


def is_skin(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > 0.93 and s < 0.12:
        return False
    return 0.03 <= h <= 0.14 and s < 0.45 and 0.28 <= v <= 0.92


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


def lighten_skin(img, factor):
    if factor <= 1.0:
        return 0
    px = list(img.pixels)
    n = 0
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01 or not is_skin(r, g, b):
            continue
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        v = min(1.0, v * factor)
        s = max(0.0, s * 0.92)
        nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
        px[i : i + 3] = [nr, ng, nb]
        n += 1
    img.pixels = px
    img.update()
    return n


# --- Customize filters per character (always exclude is_skin) ---

def is_shirt(r, g, b):
    if is_skin(r, g, b):
        return False
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.68 <= h <= 0.88 and s > 0.12 and v > 0.22  # example: purple shirt


def is_pants(r, g, b):
    if is_skin(r, g, b):
        return False
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.48 <= h <= 0.67 and s > 0.12 and v > 0.18  # example: blue pants


def is_shoe(r, g, b):
    if is_skin(r, g, b):
        return False
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return v < 0.38 and s < 0.28 and v > 0.08


def is_ribbon(r, g, b):
    if is_skin(r, g, b):
        return False
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.08 <= h <= 0.18 and s > 0.22 and v >= 0.68  # example: yellow headband


def is_hair(r, g, b):
    if is_skin(r, g, b):
        return False
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.16 <= v < 0.42 and s < 0.35


def is_eye(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return v < 0.16 and s < 0.40


# --- Main ---

arm = bpy.data.objects.get(ARM_NAME)
row1 = find_row1_arm(CHAR_ID)
if not arm or not row1:
    raise RuntimeError("Need %s and row-1 %s" % (ARM_NAME, CHAR_ID))

head2, body2 = mesh_parts(arm)
head1, body1 = mesh_parts(row1)
body_img = copy_fresh_material(body1, body2, "body", CHAR_ID)
head_img = copy_fresh_material(head1, head2, "head", CHAR_ID)

print("=== %s ===" % ARM_NAME)
print("Shirt:", replace_matching(body_img, is_shirt, SHIRT_RGB))
print("Pants:", replace_matching(body_img, is_pants, PANTS_RGB))
print("Shoes:", replace_matching(body_img, is_shoe, SHOES_RGB))
print("Ribbon:", replace_matching(head_img, is_ribbon, RIBBON_RGB))
print("Hair:", replace_matching(head_img, is_hair, HAIR_RGB))
print("Eyes:", replace_matching(head_img, is_eye, (0.07, 0.05, 0.04)))
print("Body skin:", lighten_skin(body_img, SKIN_LIGHTEN))
print("Head skin:", lighten_skin(head_img, SKIN_LIGHTEN))
print("Save: Ctrl+S")
```

## HSV cheat sheet (typical Kenney swatches)

| Part | Hue | Sat | Val | Notes |
|------|-----|-----|-----|-------|
| Skin | 0.03–0.14 | < 0.45 | 0.28–0.92 | Exclude from garments |
| Yellow shirt/band | 0.08–0.20 | > 0.15 | > 0.35 | Head band: often v ≥ 0.68 |
| Purple pants/skirt | 0.68–0.88 | > 0.12 | > 0.18 | |
| Light blue shirt | 0.50–0.62 | > 0.18 | > 0.40 | |
| Orange skirt/ribbon | 0.03–0.12 | **≥ 0.28** | ≥ 0.50 | Not skin |
| Dark shoes | any | < 0.28 | 0.08–0.38 | |
| Tan shoes | 0.05–0.14 | < 0.22 | 0.55–0.88 | Not skin, not orange garment |
| Dark hair | any | < 0.35 | 0.16–0.42 | |
| Eyes/mouth | any | < 0.40 | < 0.16 | |

## Existing scripts

| File | Status |
|------|--------|
| `paint_row2_female_a.py` | Working |
| `paint_row2_female_b.py` | Working |
| `paint_row2_female_c.py` | Needs HSV tuning |
| `paint_selected_ribbon_pink.py` | Edit Mode fallback |
| `reset_row2_to_row1_colors.py` | Reset all row-2 |
