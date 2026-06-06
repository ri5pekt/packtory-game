# Fix character-female-a row2: darker hair, darker eyes/mouth (separate swatches)
# Re-reads head atlas from row-1 first, then splits hair vs face features.
# Body shirt/skin left as-is. Paste in Blender -> Run -> Ctrl+S

import bpy
import colorsys

CHAR_ID = "character-female-a"
ARM_NAME = CHAR_ID + "_row2"

HAIR_RGB = (0.28, 0.16, 0.07)          # darker brown hair
EYE_MOUTH_RGB = (0.07, 0.05, 0.04)     # near-black eyes + mouth line
SKIN_LIGHTEN = 1.18


def is_skin_swatch(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > 0.93 and s < 0.12:
        return False
    return 0.03 <= h <= 0.14 and s < 0.55 and 0.28 <= v <= 0.92


def lighten_skin(img, factor):
    px = list(img.pixels)
    n = 0
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01 or not is_skin_swatch(r, g, b):
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


def reset_head_from_row1(row2_head, row1_head, char_id):
    src_mat = row1_head.data.materials[0]
    src_node = get_image_node(src_mat)
    if not src_node or not src_node.image:
        return None

    mat_name = "colormap_%s_row2_head" % char_id
    img_name = "colormap_%s_row2_head" % char_id
    old_img = bpy.data.images.get(img_name)
    old_mat = bpy.data.materials.get(mat_name)
    if old_img:
        bpy.data.images.remove(old_img)
    if old_mat:
        bpy.data.materials.remove(old_mat)

    new_img = src_node.image.copy()
    new_img.name = img_name
    new_mat = src_mat.copy()
    new_mat.name = mat_name
    node = get_image_node(new_mat)
    if node:
        node.image = new_img
    row2_head.data.materials[0] = new_mat
    return new_img


def is_eye_mouth_swatch(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # pure black / near-black used for eyes + mouth on Kenney heads
    return v < 0.16 and s < 0.40


def is_hair_swatch(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # dark grey hair swatch (NOT the black eye/mouth swatch)
    return 0.16 <= v < 0.42 and s < 0.35


def replace_swatch(img, test_fn, new_rgb):
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

    head2, _ = mesh_parts(arm)
    head1, _ = mesh_parts(row1)
    if not head2 or not head1:
        raise RuntimeError("Missing head mesh")

    head_img = reset_head_from_row1(head2, head1, CHAR_ID)
    if not head_img:
        raise RuntimeError("Could not reset head colormap")

    n_eyes = replace_swatch(head_img, is_eye_mouth_swatch, EYE_MOUTH_RGB)
    n_hair = replace_swatch(head_img, is_hair_swatch, HAIR_RGB)
    n_skin = lighten_skin(head_img, SKIN_LIGHTEN)

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("Head fixed for %s:" % ARM_NAME)
    print("  eye/mouth pixels -> dark:", n_eyes)
    print("  hair pixels -> darker brown:", n_hair)
    print("  skin pixels lightened:", n_skin)
    if n_eyes == 0 and n_hair == 0:
        print("  WARNING: no pixels matched - tell me and we will tune thresholds")
    print("Body unchanged. Save: Ctrl+S")


main()
