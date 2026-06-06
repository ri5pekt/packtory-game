# Row 2 — character-female-a ONLY (restored working logic)
# 1) Copy fresh body + head colormap from row-1 (row-1 stays untouched)
# 2) Shirt: replace ALL purple atlas pixels (multiple shirt swatches)
# 3) Head: hair vs eyes use separate HSV bands (fix_female_a_hair_eyes logic)
# Blender: Scripting -> paste -> Run Script -> Ctrl+S

import bpy
import colorsys

CHAR_ID = "character-female-a"
ARM_NAME = CHAR_ID + "_row2"

SHIRT_RGB = (0.35, 0.78, 0.38)
HAIR_RGB = (0.28, 0.16, 0.07)
EYE_MOUTH_RGB = (0.07, 0.05, 0.04)
SKIN_LIGHTEN = 1.18


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
    old_img = bpy.data.images.get(mat_name)
    old_mat = bpy.data.materials.get(mat_name)
    if old_img:
        bpy.data.images.remove(old_img)
    if old_mat:
        bpy.data.materials.remove(old_mat)

    src_mat = src_mesh.data.materials[0]
    src_node = get_image_node(src_mat)
    if not src_node or not src_node.image:
        raise RuntimeError("No colormap on row-1 %s mesh" % part)

    new_img = src_node.image.copy()
    new_img.name = mat_name
    new_mat = src_mat.copy()
    new_mat.name = mat_name
    clean_material_nodes(new_mat)
    node = get_image_node(new_mat)
    if node:
        node.image = new_img
    dst_mesh.data.materials[0] = new_mat
    return new_img


def is_shirt_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # all lavender / purple shirt swatches (blue pants are h ~0.55-0.65)
    return 0.68 <= h <= 0.88 and s > 0.12 and v > 0.22


def is_skin_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > 0.93 and s < 0.12:
        return False
    return 0.03 <= h <= 0.14 and s < 0.55 and 0.28 <= v <= 0.92


def is_eye_mouth_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return v < 0.16 and s < 0.40


def is_hair_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.16 <= v < 0.42 and s < 0.35


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
    px = list(img.pixels)
    n = 0
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01 or not is_skin_pixel(r, g, b):
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


def main():
    arm = bpy.data.objects.get(ARM_NAME)
    row1 = find_row1_arm(CHAR_ID)
    if not arm or not row1:
        raise RuntimeError("Need %s and row-1 %s" % (ARM_NAME, CHAR_ID))

    head2, body2 = mesh_parts(arm)
    head1, body1 = mesh_parts(row1)
    if not head2 or not body2 or not head1 or not body1:
        raise RuntimeError("Missing head/body mesh")

    body_img = copy_fresh_material(body1, body2, "body", CHAR_ID)
    head_img = copy_fresh_material(head1, head2, "head", CHAR_ID)

    report = ["Copied fresh body + head from row-1"]
    report.append("Shirt (all purple swatches) -> green: %d px" % replace_matching(body_img, is_shirt_pixel, SHIRT_RGB))
    report.append("Body skin lightened: %d px" % lighten_skin(body_img, SKIN_LIGHTEN))
    report.append("Eyes/mouth -> dark: %d px" % replace_matching(head_img, is_eye_mouth_pixel, EYE_MOUTH_RGB))
    report.append("Hair -> brown: %d px" % replace_matching(head_img, is_hair_pixel, HAIR_RGB))
    report.append("Head skin lightened: %d px" % lighten_skin(head_img, SKIN_LIGHTEN))

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("=== %s ===" % ARM_NAME)
    for line in report:
        print(" ", line)
    print("\nRow-1 unchanged. Save: Ctrl+S")


main()
