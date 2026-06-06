# Run in Blender: Scripting -> Open -> Run Script
# 1) Gives row-2 its own colormap copies (separate from row-1)
# 2) Paints visible shirt colors on each row-2 character
# 3) Saves the .blend file

import bpy
import colorsys
from collections import Counter

ROW2_COL = "Packtory Characters Row 2"
BLEND_PATH = r"C:\Users\denis\Desktop\godot-projects\packtory-game\blender\packtory_characters_lineup.blend"

SHIRT_COLORS = [
    (0.95, 0.20, 0.25, 1.0),  # red
    (0.98, 0.55, 0.10, 1.0),  # orange
    (0.98, 0.90, 0.15, 1.0),  # yellow
    (0.25, 0.85, 0.35, 1.0),  # green
    (0.20, 0.75, 0.95, 1.0),  # cyan
    (0.30, 0.45, 0.95, 1.0),  # blue
    (0.65, 0.35, 0.95, 1.0),  # purple
    (0.95, 0.35, 0.75, 1.0),  # pink
    (0.55, 0.30, 0.18, 1.0),  # brown
    (0.15, 0.80, 0.70, 1.0),  # teal
    (0.85, 0.85, 0.20, 1.0),  # olive
    (0.80, 0.25, 0.55, 1.0),  # magenta
    (0.40, 0.40, 0.45, 1.0),  # slate
]


def quantize(r, g, b, step=0.06):
    return (
        round(r / step) * step,
        round(g / step) * step,
        round(b / step) * step,
    )


def get_image_from_material(mat):
    if mat is None or not mat.node_tree:
        return None
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            return node
    return None


def ensure_unique_material(mesh_obj, char_id, part):
    if not mesh_obj.data.materials:
        return None, None
    src_mat = mesh_obj.data.materials[0]
    target_mat_name = f"colormap_{char_id}_row2_{part}"
    target_img_name = f"colormap_{char_id}_row2_{part}"

    existing = bpy.data.materials.get(target_mat_name)
    if existing:
        mesh_obj.data.materials[0] = existing
        node = get_image_from_material(existing)
        return existing, node.image if node else None

    new_mat = src_mat.copy()
    new_mat.name = target_mat_name
    node = get_image_from_material(new_mat)
    if node and node.image:
        new_img = node.image.copy()
        new_img.name = target_img_name
        node.image = new_img
    mesh_obj.data.materials[0] = new_mat
    return new_mat, node.image if node else None


def find_main_garment_swatch(img):
    px = img.pixels
    counts = Counter()
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.5:
            continue
        v = max(r, g, b)
        s = v - min(r, g, b)
        if v < 0.10 or v > 0.98:
            continue
        if s < 0.06:
            continue
        counts[quantize(r, g, b)] += 1
    if not counts:
        return None
    return counts.most_common(1)[0][0]


def replace_color(img, src, dst, tolerance=0.18):
    px = list(img.pixels)
    sr, sg, sb = src
    dr, dg, db, da = dst
    changed = 0
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01:
            continue
        if abs(r - sr) + abs(g - sg) + abs(b - sb) <= tolerance:
            px[i : i + 4] = [dr, dg, db, da]
            changed += 1
    img.pixels = px
    img.update()
    return changed


def tint_whole_image(img, hue_delta=0.0, sat_mul=1.0, val_mul=1.0):
    px = list(img.pixels)
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01:
            continue
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if s < 0.02 and v > 0.95:
            continue
        h = (h + hue_delta) % 1.0
        s = min(1.0, max(0.0, s * sat_mul))
        v = min(1.0, max(0.0, v * val_mul))
        nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
        px[i : i + 4] = [nr, ng, nb, a]
    img.pixels = px
    img.update()


def main():
    col = bpy.data.collections.get(ROW2_COL)
    if col is None:
        raise RuntimeError("Missing collection: Packtory Characters Row 2")

    armatures = sorted(
        [o for o in col.objects if o.type == "ARMATURE"],
        key=lambda o: o.location.x,
    )

    report = []
    for idx, arm in enumerate(armatures):
        char_id = arm.name.replace("_row2", "")
        shirt_color = SHIRT_COLORS[idx % len(SHIRT_COLORS)]

        for child in arm.children:
            if child.type != "MESH":
                continue
            part = "body" if "body" in child.name.lower() else "head" if "head" in child.name.lower() else "mesh"
            mat, img = ensure_unique_material(child, char_id, part)
            if img is None:
                continue

            if part == "body":
                swatch = find_main_garment_swatch(img)
                if swatch:
                    n = replace_color(img, swatch, shirt_color)
                    report.append(f"{char_id} body: painted {n} px -> {shirt_color[:3]}")
                else:
                    tint_whole_image(img, hue_delta=0.08 + idx * 0.02, sat_mul=1.15)
                    report.append(f"{char_id} body: full tint fallback")
            else:
                tint_whole_image(img, hue_delta=0.03 + idx * 0.01, sat_mul=1.05)
                report.append(f"{char_id} head: slight tint")

    if bpy.data.filepath:
        bpy.ops.wm.save_mainfile()
        report.append("Saved: " + bpy.data.filepath)
    elif BLEND_PATH:
        bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
        report.append("Saved as: " + BLEND_PATH)

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("\n".join(report))
    print("Done.")


main()
