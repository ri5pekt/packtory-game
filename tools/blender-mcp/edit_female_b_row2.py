# character-female-b (row 2): pink shirt, brown pants, blonde hair, dark blue shoes
# Paste in Blender -> Run Script -> Ctrl+S

import bpy
import colorsys

CHAR_ID = "character-female-b"
ARM_NAME = CHAR_ID + "_row2"

SHIRT_RGB = (0.95, 0.42, 0.62)       # pink
PANTS_RGB = (0.48, 0.30, 0.14)       # brown
SHOES_RGB = (0.10, 0.16, 0.42)       # dark blue
HAIR_RGB = (0.95, 0.82, 0.38)        # blonde
EYE_MOUTH_RGB = (0.07, 0.05, 0.04)   # dark eyes/mouth


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


def ensure_unique_head_material(row2_head, row1_head, char_id):
    mat_name = "colormap_%s_row2_head" % char_id
    img_name = "colormap_%s_row2_head" % char_id

    old_img = bpy.data.images.get(img_name)
    old_mat = bpy.data.materials.get(mat_name)
    if old_img:
        bpy.data.images.remove(old_img)
    if old_mat:
        bpy.data.materials.remove(old_mat)

    src_mat = row1_head.data.materials[0]
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
    row2_head.data.materials[0] = new_mat
    return new_img


def ensure_unique_body_material(row2_body, row1_body, char_id):
    mat_name = "colormap_%s_row2_body" % char_id
    img_name = "colormap_%s_row2_body" % char_id

    existing = bpy.data.materials.get(mat_name)
    if existing and row2_body.data.materials[0] == existing:
        node = get_image_node(existing)
        return node.image if node else None

    old_img = bpy.data.images.get(img_name)
    old_mat = bpy.data.materials.get(mat_name)
    if old_img:
        bpy.data.images.remove(old_img)
    if old_mat:
        bpy.data.materials.remove(old_mat)

    src_mat = row1_body.data.materials[0]
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
    row2_body.data.materials[0] = new_mat
    return new_img


def is_shirt_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # yellow shirt
    return 0.08 <= h <= 0.20 and s > 0.15 and v > 0.35


def is_pants_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # purple pants
    return 0.68 <= h <= 0.88 and s > 0.12 and v > 0.18


def is_shoe_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # dark grey shoes (not white soles)
    return v < 0.38 and s < 0.28 and v > 0.08


def is_eye_mouth_swatch(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return v < 0.16 and s < 0.40


def is_hair_swatch(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # orange / brown hair (female-b)
    return 0.02 <= h <= 0.14 and s > 0.15 and 0.20 <= v < 0.85


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


def main():
    arm = bpy.data.objects.get(ARM_NAME)
    row1 = find_row1_arm(CHAR_ID)
    if not arm or not row1:
        raise RuntimeError("Need %s and row-1 %s" % (ARM_NAME, CHAR_ID))

    head2, body2 = mesh_parts(arm)
    head1, body1 = mesh_parts(row1)
    if not body2 or not body1:
        raise RuntimeError("Missing body mesh")

    report = []

    body_img = ensure_unique_body_material(body2, body1, CHAR_ID)
    if not body_img:
        raise RuntimeError("No body colormap")

    report.append("Shirt -> pink: %d px" % replace_matching(body_img, is_shirt_pixel, SHIRT_RGB))
    report.append("Pants -> brown: %d px" % replace_matching(body_img, is_pants_pixel, PANTS_RGB))
    report.append("Shoes -> dark blue: %d px" % replace_matching(body_img, is_shoe_pixel, SHOES_RGB))

    if head2 and head1:
        head_img = ensure_unique_head_material(head2, head1, CHAR_ID)
        if head_img:
            report.append("Eyes/mouth dark: %d px" % replace_matching(head_img, is_eye_mouth_swatch, EYE_MOUTH_RGB))
            report.append("Hair -> blonde: %d px" % replace_matching(head_img, is_hair_swatch, HAIR_RGB))

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("Updated %s:" % ARM_NAME)
    for line in report:
        print(" ", line)
    print("Save: Ctrl+S")


main()
