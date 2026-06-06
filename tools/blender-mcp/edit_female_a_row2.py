# character-female-a (row 2): green shirt, lighter skin, brown hair
# Blender: Scripting -> paste -> Run Script -> Ctrl+S

import bpy
import colorsys

CHAR_ID = "character-female-a"
ARM_NAME = CHAR_ID + "_row2"

# Target colors
SHIRT_RGB = (0.35, 0.78, 0.38)       # green
HAIR_RGB = (0.42, 0.28, 0.16)        # brown
SKIN_LIGHTEN = 1.18                  # multiply value on skin pixels


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
    existing = bpy.data.materials.get(mat_name)
    if existing and row2_head.data.materials[0] == existing:
        node = get_image_node(existing)
        return existing, node.image if node else None

    src_mat = row1_head.data.materials[0]
    src_node = get_image_node(src_mat)
    if not src_node or not src_node.image:
        return None, None

    old_img = bpy.data.images.get("colormap_%s_row2_head" % char_id)
    old_mat = bpy.data.materials.get(mat_name)
    if old_img:
        bpy.data.images.remove(old_img)
    if old_mat:
        bpy.data.materials.remove(old_mat)

    new_img = src_node.image.copy()
    new_img.name = "colormap_%s_row2_head" % char_id
    new_mat = src_mat.copy()
    new_mat.name = mat_name
    node = get_image_node(new_mat)
    if node:
        node.image = new_img
    row2_head.data.materials[0] = new_mat
    return new_mat, new_img


def color_dist(r, g, b, tr, tg, tb):
    return abs(r - tr) + abs(g - tg) + abs(b - tb)


def is_shirt_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # lavender / purple shirt (not blue pants)
    return 0.68 <= h <= 0.88 and s > 0.12 and v > 0.22


def is_pants_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.48 <= h <= 0.67 and s > 0.12 and v > 0.18


def is_skin_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > 0.93 and s < 0.12:
        return False
    return 0.03 <= h <= 0.14 and s < 0.55 and 0.28 <= v <= 0.92


def is_hair_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # dark grey / black hair swatch
    return v < 0.38 and s < 0.30


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


def get_body_image(body):
    mat = body.data.materials[0]
    node = get_image_node(mat)
    return node.image if node else None


def main():
    arm = bpy.data.objects.get(ARM_NAME)
    if not arm:
        raise RuntimeError("Missing armature: %s" % ARM_NAME)

    row1 = find_row1_arm(CHAR_ID)
    head2, body2 = mesh_parts(arm)
    if not body2:
        raise RuntimeError("Missing body mesh")

    report = []

    # --- body: green shirt, lighter hands/skin ---
    body_img = get_body_image(body2)
    if not body_img:
        raise RuntimeError("No body colormap on %s" % ARM_NAME)

    n = replace_matching(body_img, is_shirt_pixel, SHIRT_RGB)
    report.append("Shirt pixels painted green: %d" % n)

    n = lighten_skin(body_img, SKIN_LIGHTEN)
    report.append("Body skin pixels lightened: %d" % n)

    # --- head: own copy so row-1 stays unchanged ---
    if head2 and row1:
        head1, _ = mesh_parts(row1)
        if head1:
            _, head_img = ensure_unique_head_material(head2, head1, CHAR_ID)
            if head_img:
                n = replace_matching(head_img, is_hair_pixel, HAIR_RGB)
                report.append("Hair pixels -> brown: %d" % n)
                n = lighten_skin(head_img, SKIN_LIGHTEN)
                report.append("Head skin pixels lightened: %d" % n)

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("Updated %s:" % ARM_NAME)
    for line in report:
        print(" ", line)
    print("Save with Ctrl+S")


main()
