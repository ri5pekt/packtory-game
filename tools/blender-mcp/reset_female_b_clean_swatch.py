# RESET + recolor character-female-b row2 — SWATCH ONLY (never touch UV/texel mapping)
# Fixes stripe corruption. Paste in Blender -> Run -> Ctrl+S

import bpy
import colorsys

CHAR_ID = "character-female-b"
ARM_NAME = CHAR_ID + "_row2"

SHIRT_RGB = (0.95, 0.42, 0.62)
PANTS_RGB = (0.48, 0.30, 0.14)
SHOES_RGB = (0.10, 0.16, 0.42)
HAIR_RGB = (0.95, 0.82, 0.38)
RIBBON_RGB = (0.95, 0.42, 0.62)
EYE_MOUTH_RGB = (0.07, 0.05, 0.04)
TOL = 0.14


def get_image_node(mat):
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


def copy_fresh_material(src_mesh, dst_mesh, mat_name, img_name):
    old_img = bpy.data.images.get(img_name)
    old_mat = bpy.data.materials.get(mat_name)
    if old_img:
        bpy.data.images.remove(old_img)
    if old_mat:
        bpy.data.materials.remove(old_mat)

    src_mat = src_mesh.data.materials[0]
    src_node = get_image_node(src_mat)
    if not src_node or not src_node.image:
        return None

    new_img = src_node.image.copy()
    new_img.name = img_name
    new_mat = src_mat.copy()
    new_mat.name = mat_name
    node = get_image_node(new_mat)
    if node:
        node.image = new_img
    dst_mesh.data.materials[0] = new_mat
    return new_img


def dist(r, g, b, tr, tg, tb):
    return abs(r - tr) + abs(g - tg) + abs(b - tb)


def replace_near(img, src_rgb, dst_rgb):
    sr, sg, sb = src_rgb
    dr, dg, db = dst_rgb
    px = list(img.pixels)
    n = 0
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01:
            continue
        if dist(r, g, b, sr, sg, sb) <= TOL:
            px[i : i + 3] = [dr, dg, db]
            n += 1
    img.pixels = px
    img.update()
    return n


def collect_swatch(img, test_fn):
    counts = {}
    px = img.pixels
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01 or not test_fn(r, g, b):
            continue
        key = (round(r, 3), round(g, 3), round(b, 3))
        counts[key] = counts.get(key, 0) + 1
    return sorted(counts.items(), key=lambda x: -x[1])


def is_skin(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > 0.93 and s < 0.12:
        return False
    return 0.03 <= h <= 0.14 and s < 0.55 and 0.28 <= v <= 0.92


def is_eye(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return v < 0.16 and s < 0.40


def is_hair(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # orange / brown / yellow hair tones on Kenney heads
    return 0.02 <= h <= 0.18 and s > 0.12 and 0.18 <= v < 0.92 and not is_skin(r, g, b)


def is_ribbon(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # accent band — often blue/purple/red on mini characters; not hair orange, not skin
    if is_skin(r, g, b) or is_eye(r, g, b) or is_hair(r, g, b):
        return False
    return s > 0.15 and 0.20 <= v <= 0.95


def is_shirt(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.08 <= h <= 0.20 and s > 0.15 and v > 0.35


def is_pants(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.68 <= h <= 0.88 and s > 0.12 and v > 0.18


def is_shoe(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return v < 0.38 and s < 0.28 and v > 0.08


def replace_all_swatches(img, test_fn, dst_rgb):
    total = 0
    for (r, g, b), _count in collect_swatch(img, test_fn):
        total += replace_near(img, (r, g, b), dst_rgb)
    return total


def main():
    arm = bpy.data.objects.get(ARM_NAME)
    row1 = find_row1_arm(CHAR_ID)
    if not arm or not row1:
        raise RuntimeError("Need %s and row-1 %s" % (ARM_NAME, CHAR_ID))

    head2, body2 = mesh_parts(arm)
    head1, body1 = mesh_parts(row1)
    if not head2 or not body2 or not head1 or not body1:
        raise RuntimeError("Missing head/body meshes")

    report = []

    # Fresh copies from row-1 (fixes corrupted atlas)
    body_img = copy_fresh_material(
        body1, body2,
        "colormap_%s_row2_body" % CHAR_ID,
        "colormap_%s_row2_body" % CHAR_ID,
    )
    head_img = copy_fresh_material(
        head1, head2,
        "colormap_%s_row2_head" % CHAR_ID,
        "colormap_%s_row2_head" % CHAR_ID,
    )
    report.append("Reset body + head colormaps from row-1")

    report.append("Shirt -> pink: %d px" % replace_all_swatches(body_img, is_shirt, SHIRT_RGB))
    report.append("Pants -> brown: %d px" % replace_all_swatches(body_img, is_pants, PANTS_RGB))
    report.append("Shoes -> dark blue: %d px" % replace_all_swatches(body_img, is_shoe, SHOES_RGB))

    report.append("Eyes/mouth: %d px" % replace_all_swatches(head_img, is_eye, EYE_MOUTH_RGB))

    hair_swatches = collect_swatch(head_img, is_hair)
    hair_px = 0
    for swatch, _ in hair_swatches:
        hair_px += replace_near(head_img, swatch, HAIR_RGB)
    report.append("Hair swatches %d -> blonde: %d px" % (len(hair_swatches), hair_px))

    ribbon_swatches = collect_swatch(head_img, is_ribbon)
    ribbon_px = 0
    for swatch, _ in ribbon_swatches:
        ribbon_px += replace_near(head_img, swatch, RIBBON_RGB)
    report.append("Ribbon/accent swatches %d -> pink: %d px" % (len(ribbon_swatches), ribbon_px))

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("Clean swatch recolor for %s:" % ARM_NAME)
    for line in report:
        print(" ", line)
    print("\nNote: bun parts mapped to SKIN swatch in the model cannot turn blonde")
    print("without also changing face skin — that is a model/UV limit.")
    print("Save: Ctrl+S")


main()
