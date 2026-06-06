# Row-2 variants: copy fresh colormap from row-1, recolor GARMENT pixels only.
# Fast (tiny atlas). Head uses row-1 material unchanged.
#
# Step 1 (optional test): run analyze_body_colormap.py first
# Step 2: run this script, then Ctrl+S

import bpy
import colorsys
from collections import Counter

ROW1_COL = "Packtory Characters"
ROW2_COL = "Packtory Characters Row 2"

# Per-character garment hue shift (subtle, distinct outfits)
GARMENT_HUE_SHIFTS = [
    0.00, 0.06, 0.12, 0.18, 0.24, 0.30, 0.36, 0.42, 0.48, 0.54, 0.60, 0.66, 0.08,
]


def quantize(r, g, b, step=0.04):
    return (
        round(r / step) * step,
        round(g / step) * step,
        round(b / step) * step,
    )


def classify_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > 0.92 and s < 0.12:
        return "neutral"
    if v < 0.12:
        return "neutral"
    if 0.03 <= h <= 0.14 and s < 0.55 and 0.30 <= v <= 0.92:
        return "skin"
    if s < 0.10 and v < 0.85:
        return "neutral"
    return "garment"


def get_image_node(mat):
    if not mat or not mat.node_tree:
        return None
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            return node
    return None


def clean_material_nodes(mat):
    if not mat or not mat.node_tree:
        return
    nt = mat.node_tree
    principled = tex = None
    for node in nt.nodes:
        if node.type == "BSDF_PRINCIPLED":
            principled = node
        if node.type == "TEX_IMAGE":
            tex = node
    for node in list(nt.nodes):
        if node.name in ("Row2HueSat", "Row2BodyTint"):
            nt.nodes.remove(node)
    if principled and tex:
        base = principled.inputs["Base Color"]
        if base.is_linked:
            nt.links.remove(base.links[0])
        nt.links.new(tex.outputs["Color"], base)


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
    col = bpy.data.collections.get(ROW1_COL)
    if col:
        for o in col.objects:
            if o.type == "ARMATURE" and o.name == char_id:
                return o
    return None


def copy_row1_body_setup(row1_body, row2_body, char_id):
    if not row1_body or not row1_body.data.materials:
        return None, None
    src_mat = row1_body.data.materials[0]
    src_node = get_image_node(src_mat)
    if not src_node or not src_node.image:
        return None, None

    img_name = f"colormap_{char_id}_row2_body"
    mat_name = f"colormap_{char_id}_row2_body"

    # Remove old datablocks so we start fresh from row-1
    old_mat = bpy.data.materials.get(mat_name)
    old_img = bpy.data.images.get(img_name)
    if old_img:
        bpy.data.images.remove(old_img)
    if old_mat:
        bpy.data.materials.remove(old_mat)

    new_img = src_node.image.copy()
    new_img.name = img_name
    new_mat = src_mat.copy()
    new_mat.name = mat_name
    clean_material_nodes(new_mat)
    new_node = get_image_node(new_mat)
    if new_node:
        new_node.image = new_img
    row2_body.data.materials[0] = new_mat
    return new_mat, new_img


def recolor_garment_pixels(img, hue_delta, sat_mul=1.08):
    px = list(img.pixels)
    changed = 0
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01:
            continue
        if classify_pixel(r, g, b) != "garment":
            continue
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        h = (h + hue_delta) % 1.0
        s = min(1.0, max(0.0, s * sat_mul))
        nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
        px[i : i + 4] = [nr, ng, nb, a]
        changed += 1
    img.pixels = px
    img.update()
    return changed


def main():
    row2_col = bpy.data.collections.get(ROW2_COL)
    if not row2_col:
        raise RuntimeError("Missing: Packtory Characters Row 2")

    arms = sorted(
        [o for o in row2_col.objects if o.type == "ARMATURE"],
        key=lambda o: o.location.x,
    )

    report = []
    for idx, arm in enumerate(arms):
        char_id = arm.name.replace("_row2", "")
        row1 = find_row1_arm(char_id)
        if not row1:
            report.append(f"SKIP {char_id}: no row-1 match")
            continue

        head1, body1 = mesh_parts(row1)
        head2, body2 = mesh_parts(arm)

        # Head: exact row-1 material (skin + hair untouched)
        if head2 and head1 and head1.data.materials:
            head2.data.materials[0] = head1.data.materials[0]
            report.append(f"{char_id}: head <- row-1 material")

        if not body2 or not body1:
            report.append(f"SKIP {char_id}: missing body mesh")
            continue

        mat, img = copy_row1_body_setup(body1, body2, char_id)
        if not img:
            report.append(f"SKIP {char_id}: no body image")
            continue

        hue = GARMENT_HUE_SHIFTS[idx % len(GARMENT_HUE_SHIFTS)]
        n = recolor_garment_pixels(img, hue)
        report.append(f"{char_id}: copied atlas, shifted {n} garment pixels hue={hue:.2f}")

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("\n".join(report))
    print("\nDone. Garment pixels only (shirt/pants/shoes). Skin/neutral unchanged.")
    print("Save: Ctrl+S")


main()
