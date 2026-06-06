# Row 2 — characters 1 & 2 (female-a, female-b)
# Fresh copy from row-1, then SWATCH-ONLY recolor (never UV / texel rows).
# Blender: Scripting -> paste -> Run Script -> Ctrl+S

import bpy
import colorsys

TOL = 0.14
SKIN_LIGHTEN = 1.18

# --- character-female-a ---
FEMALE_A = {
    "char_id": "character-female-a",
    "shirt": (0.35, 0.78, 0.38),
    "hair": (0.28, 0.16, 0.07),
    "eye_mouth": (0.07, 0.05, 0.04),
    "lighten_skin": True,
}

# --- character-female-b ---
FEMALE_B = {
    "char_id": "character-female-b",
    "shirt": (0.95, 0.42, 0.62),
    "pants": (0.48, 0.30, 0.14),
    "shoes": (0.10, 0.16, 0.42),
    "hair": (0.95, 0.82, 0.38),
    "ribbon": (0.95, 0.42, 0.62),
    "eye_mouth": (0.07, 0.05, 0.04),
    "lighten_skin": False,
}


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
    col = bpy.data.collections.get("Packtory Characters")
    if col:
        for o in col.objects:
            if o.type == "ARMATURE" and o.name == char_id:
                return o
    return None


def copy_fresh_material(src_mesh, dst_mesh, part, char_id):
    mat_name = "colormap_%s_row2_%s" % (char_id, part)
    img_name = mat_name
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
    clean_material_nodes(new_mat)
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


def replace_all_swatches(img, test_fn, dst_rgb):
    total = 0
    for (r, g, b), _count in collect_swatch(img, test_fn):
        total += replace_near(img, (r, g, b), dst_rgb)
    return total


def is_skin(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > 0.93 and s < 0.12:
        return False
    return 0.03 <= h <= 0.14 and s < 0.55 and 0.28 <= v <= 0.92


def is_eye(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return v < 0.16 and s < 0.40


def is_hair_a(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.16 <= v < 0.42 and s < 0.35


def is_hair_b(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.02 <= h <= 0.18 and s > 0.12 and 0.18 <= v < 0.92 and not is_skin(r, g, b)


def is_ribbon(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if is_skin(r, g, b) or is_eye(r, g, b) or is_hair_b(r, g, b):
        return False
    return s > 0.15 and 0.20 <= v <= 0.95


def is_shirt_a(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.68 <= h <= 0.88 and s > 0.12 and v > 0.22


def is_shirt_b(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.08 <= h <= 0.20 and s > 0.15 and v > 0.35


def is_pants(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.68 <= h <= 0.88 and s > 0.12 and v > 0.18


def is_shoe(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return v < 0.38 and s < 0.28 and v > 0.08


def lighten_skin(img, factor):
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


def paint_female_a(cfg):
    char_id = cfg["char_id"]
    arm = bpy.data.objects.get(char_id + "_row2")
    row1 = find_row1_arm(char_id)
    if not arm or not row1:
        raise RuntimeError("Need %s_row2 and row-1 %s" % (char_id, char_id))

    head2, body2 = mesh_parts(arm)
    head1, body1 = mesh_parts(row1)
    if not head2 or not body2 or not head1 or not body1:
        raise RuntimeError("%s: missing head/body meshes" % char_id)

    report = ["Reset body + head from row-1"]
    body_img = copy_fresh_material(body1, body2, "body", char_id)
    head_img = copy_fresh_material(head1, head2, "head", char_id)

    report.append("Shirt -> green: %d px" % replace_all_swatches(body_img, is_shirt_a, cfg["shirt"]))
    report.append("Body skin lightened: %d px" % lighten_skin(body_img, SKIN_LIGHTEN))
    report.append("Eyes/mouth: %d px" % replace_all_swatches(head_img, is_eye, cfg["eye_mouth"]))
    report.append("Hair -> brown: %d px" % replace_all_swatches(head_img, is_hair_a, cfg["hair"]))
    report.append("Head skin lightened: %d px" % lighten_skin(head_img, SKIN_LIGHTEN))
    return report


def paint_female_b(cfg):
    char_id = cfg["char_id"]
    arm = bpy.data.objects.get(char_id + "_row2")
    row1 = find_row1_arm(char_id)
    if not arm or not row1:
        raise RuntimeError("Need %s_row2 and row-1 %s" % (char_id, char_id))

    head2, body2 = mesh_parts(arm)
    head1, body1 = mesh_parts(row1)
    if not head2 or not body2 or not head1 or not body1:
        raise RuntimeError("%s: missing head/body meshes" % char_id)

    report = ["Reset body + head from row-1"]
    body_img = copy_fresh_material(body1, body2, "body", char_id)
    head_img = copy_fresh_material(head1, head2, "head", char_id)

    report.append("Shirt -> pink: %d px" % replace_all_swatches(body_img, is_shirt_b, cfg["shirt"]))
    report.append("Pants -> brown: %d px" % replace_all_swatches(body_img, is_pants, cfg["pants"]))
    report.append("Shoes -> dark blue: %d px" % replace_all_swatches(body_img, is_shoe, cfg["shoes"]))
    report.append("Eyes/mouth: %d px" % replace_all_swatches(head_img, is_eye, cfg["eye_mouth"]))

    hair_swatches = collect_swatch(head_img, is_hair_b)
    hair_px = 0
    for swatch, _ in hair_swatches:
        hair_px += replace_near(head_img, swatch, cfg["hair"])
    report.append("Hair swatches %d -> blonde: %d px" % (len(hair_swatches), hair_px))

    ribbon_swatches = collect_swatch(head_img, is_ribbon)
    ribbon_px = 0
    for swatch, _ in ribbon_swatches:
        ribbon_px += replace_near(head_img, swatch, cfg["ribbon"])
    report.append("Ribbon swatches %d -> pink: %d px" % (len(ribbon_swatches), ribbon_px))
    return report


def main():
    results = []

    print("=== 1/2 character-female-a ===")
    for line in paint_female_a(FEMALE_A):
        print(" ", line)
        results.append(("female-a", line))

    print("\n=== 2/2 character-female-b ===")
    for line in paint_female_b(FEMALE_B):
        print(" ", line)
        results.append(("female-b", line))

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("\nDone. Row-1 unchanged. Save: Ctrl+S")
    print("Note: female-b bun parts on skin swatch stay tan (model limit).")


main()
