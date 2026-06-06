# Row 2 — character-female-b — SIMPLE (why it works)
# Body colormap and head colormap are SEPARATE images.
# Yellow shirt lives on body. Yellow ribbon lives on head.
# -> replace yellow on body = pink shirt, replace bright yellow on head = pink ribbon
#    hair (orange) and face (skin) on head are different swatches — left alone.
# Blender: Scripting -> paste -> Run Script -> Ctrl+S

import bpy
import colorsys

CHAR_ID = "character-female-b"
ARM_NAME = CHAR_ID + "_row2"

SHIRT_RGB = (0.95, 0.42, 0.62)
PANTS_RGB = (0.48, 0.30, 0.14)
SHOES_RGB = (0.10, 0.16, 0.42)
RIBBON_RGB = (0.95, 0.42, 0.62)


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


def is_shirt_yellow(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.08 <= h <= 0.20 and s > 0.15 and v > 0.35


def is_pants_purple(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.68 <= h <= 0.88 and s > 0.12 and v > 0.18


def is_shoe_grey(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return v < 0.38 and s < 0.28 and v > 0.08


def is_headband_yellow(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # bright yellow headband on HEAD atlas only (hair is orange, lower v)
    return 0.08 <= h <= 0.18 and s > 0.22 and v >= 0.68


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

    print("=== %s ===" % ARM_NAME)
    print("  Body image:", body_img.name)
    print("  Head image:", head_img.name)
    print("  Shirt (body yellow) -> pink:", replace_matching(body_img, is_shirt_yellow, SHIRT_RGB), "px")
    print("  Pants -> brown:", replace_matching(body_img, is_pants_purple, PANTS_RGB), "px")
    print("  Shoes -> blue:", replace_matching(body_img, is_shoe_grey, SHOES_RGB), "px")
    print("  Ribbon (head yellow) -> pink:", replace_matching(head_img, is_headband_yellow, RIBBON_RGB), "px")
    print("Hair/skin/eyes unchanged. Save: Ctrl+S")

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()


main()
