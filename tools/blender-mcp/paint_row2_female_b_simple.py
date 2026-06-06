# female-b row2 — fixed copy_mat bug. Object Mode -> Run -> Ctrl+S

import bpy
import colorsys

CHAR_ID = "character-female-b"
ARM_NAME = CHAR_ID + "_row2"

SHIRT_RGB = (0.95, 0.42, 0.62)
PANTS_RGB = (0.48, 0.30, 0.14)
SHOES_RGB = (0.10, 0.16, 0.42)
RIBBON_RGB = (0.95, 0.42, 0.62)


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


def copy_fresh(src_mesh, dst_mesh, part):
    mat_name = "colormap_%s_row2_%s" % (CHAR_ID, part)
    old_img = bpy.data.images.get(mat_name)
    old_mat = bpy.data.materials.get(mat_name)
    if old_img:
        bpy.data.images.remove(old_img)
    if old_mat:
        bpy.data.materials.remove(old_mat)

    src_node = get_tex_node(src_mesh.data.materials[0])
    if not src_node:
        raise RuntimeError("No colormap on row-1 %s" % part)

    new_img = src_node.image.copy()
    new_img.name = mat_name
    new_mat = src_mesh.data.materials[0].copy()
    new_mat.name = mat_name
    dst_node = get_tex_node(new_mat)
    if not dst_node:
        raise RuntimeError("Copied material has no image node")
    dst_node.image = new_img
    dst_mesh.data.materials[0] = new_mat
    return new_img


def replace_matching(img, test_fn, rgb):
    px = list(img.pixels)
    n = 0
    nr, ng, nb = rgb
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01 or not test_fn(r, g, b):
            continue
        px[i : i + 3] = [nr, ng, nb]
        n += 1
    img.pixels = px
    img.update()
    return n


arm = bpy.data.objects.get(ARM_NAME)
row1 = bpy.data.objects.get(CHAR_ID)
if not arm or not row1:
    raise RuntimeError("Need %s and %s" % (ARM_NAME, CHAR_ID))

head2, body2 = mesh_parts(arm)
head1, body1 = mesh_parts(row1)

body_img = copy_fresh(body1, body2, "body")
head_img = copy_fresh(head1, head2, "head")

print("=== %s ===" % ARM_NAME)
print("Shirt -> pink:", replace_matching(body_img, lambda r, g, b: 0.08 <= colorsys.rgb_to_hsv(r, g, b)[0] <= 0.20 and colorsys.rgb_to_hsv(r, g, b)[1] > 0.15 and colorsys.rgb_to_hsv(r, g, b)[2] > 0.35, SHIRT_RGB))
print("Pants -> brown:", replace_matching(body_img, lambda r, g, b: 0.68 <= colorsys.rgb_to_hsv(r, g, b)[0] <= 0.88 and colorsys.rgb_to_hsv(r, g, b)[1] > 0.12 and colorsys.rgb_to_hsv(r, g, b)[2] > 0.18, PANTS_RGB))
print("Shoes -> blue:", replace_matching(body_img, lambda r, g, b: (lambda h, s, v: v < 0.38 and s < 0.28 and v > 0.08)(*colorsys.rgb_to_hsv(r, g, b)), SHOES_RGB))
print("Ribbon -> pink:", replace_matching(head_img, lambda r, g, b: (lambda h, s, v: 0.08 <= h <= 0.18 and s > 0.22 and v >= 0.68)(*colorsys.rgb_to_hsv(r, g, b)), RIBBON_RGB))
print("Save: Ctrl+S")
