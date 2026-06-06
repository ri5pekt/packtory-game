# Row 2 — character-female-c (fixed — skin protected)
# Shirt + shoes -> turquoise | Skirt + ribbon -> blue
# Blender: Scripting -> paste -> Run Script -> Ctrl+S
# Reload blend first if skin was already tinted wrong.

import bpy
import colorsys

CHAR_ID = "character-female-c"
ARM_NAME = CHAR_ID + "_row2"

TURQUOISE_RGB = (0.20, 0.78, 0.72)
BLUE_RGB = (0.40, 0.58, 0.85)


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
        raise RuntimeError("Missing row-1 colormap on %s" % part)
    new_img = src_node.image.copy()
    new_img.name = mat_name
    new_mat = src_mat.copy()
    new_mat.name = mat_name
    get_image_node(new_mat).image = new_img
    dst_mesh.data.materials[0] = new_mat
    return new_img


def is_skin(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > 0.93 and s < 0.12:
        return False
    return 0.03 <= h <= 0.14 and s < 0.45 and 0.28 <= v <= 0.92


def is_shirt_blue(r, g, b):
    if is_skin(r, g, b):
        return False
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.50 <= h <= 0.62 and s > 0.18 and v > 0.40


def is_orange_garment(r, g, b):
    """Skirt + ribbon — saturated peach/orange, not skin."""
    if is_skin(r, g, b):
        return False
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.03 <= h <= 0.12 and s >= 0.28 and v >= 0.50


def is_shoe_tan(r, g, b):
    if is_skin(r, g, b):
        return False
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if is_orange_garment(r, g, b):
        return False
    return 0.05 <= h <= 0.14 and s < 0.22 and 0.55 <= v <= 0.88


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
    if not head2 or not body2 or not head1 or not body1:
        raise RuntimeError("Missing head/body mesh")

    body_img = copy_fresh_material(body1, body2, "body", CHAR_ID)
    head_img = copy_fresh_material(head1, head2, "head", CHAR_ID)

    print("=== %s (skin safe) ===" % ARM_NAME)
    print("  Shirt -> turquoise:", replace_matching(body_img, is_shirt_blue, TURQUOISE_RGB), "px")
    print("  Skirt -> blue:", replace_matching(body_img, is_orange_garment, BLUE_RGB), "px")
    print("  Shoes -> turquoise:", replace_matching(body_img, is_shoe_tan, TURQUOISE_RGB), "px")
    print("  Ribbon -> blue:", replace_matching(head_img, is_orange_garment, BLUE_RGB), "px")
    print("Skin/hair/eyes unchanged. Save: Ctrl+S")

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()


main()
