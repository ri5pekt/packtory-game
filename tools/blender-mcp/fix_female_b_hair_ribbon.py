# Fix character-female-b row2 hair: full blonde + pink ribbon (matches shirt)
# Uses mesh normals/UV per loop (not just atlas swatches).
# Paste in Blender -> Run Script -> Ctrl+S

import bpy
import colorsys

CHAR_ID = "character-female-b"
ARM_NAME = CHAR_ID + "_row2"

BLONDE = (0.95, 0.82, 0.38)
RIBBON_PINK = (0.95, 0.42, 0.62)  # same as shirt
EYE_MOUTH = (0.07, 0.05, 0.04)


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


def get_head_image(head):
    if not head.data.materials:
        return None
    node = get_image_node(head.data.materials[0])
    return node.image if node else None


def is_eye_mouth_color(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return v < 0.16 and s < 0.40


def paint_texel(px, w, h, x, y, color, radius=1):
    n = 0
    nr, ng, nb = color
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            tx = (x + dx) % w
            ty = (y + dy) % h
            i = (ty * w + tx) * 4
            r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
            if a < 0.01 or is_eye_mouth_color(r, g, b):
                continue
            px[i : i + 3] = [nr, ng, nb]
            n += 1
    return n


def is_hair_loop(normal):
    nx, ny, nz = normal.x, normal.y, normal.z
    if nz < 0.20:
        return False
    # top of head + bun sides; exclude front face skin
    if nz > 0.45:
        return True
    if abs(nx) > 0.55 and nz > 0.15:
        return True
    return False


def is_ribbon_loop(normal):
    nx, ny, nz = normal.x, normal.y, normal.z
    # front headband / ribbon around upper head
    return ny < -0.45 and 0.15 < nz < 0.72 and abs(nx) < 0.85


def is_face_loop(normal):
    nx, ny, nz = normal.x, normal.y, normal.z
    return ny < -0.35 and nz < 0.45


def paint_head_by_geometry(head, img):
    mesh = head.data
    mesh.calc_normals_split()
    uv_layer = mesh.uv_layers.active.data
    w, h = img.size
    px = list(img.pixels)

    hair_n = ribbon_n = eye_n = 0
    done = set()

    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            n = mesh.loops[loop_idx].normal
            uv = uv_layer[loop_idx].uv
            x = int(uv.x * w) % w
            y = int(uv.y * h) % h
            key = (x, y)

            i = (y * w + x) * 4
            r, g, b = px[i], px[i + 1], px[i + 2]

            if is_eye_mouth_color(r, g, b):
                if key not in done:
                    hair_n += paint_texel(px, w, h, x, y, EYE_MOUTH, 0)
                    done.add(key)
                    eye_n += 1
                continue

            if is_ribbon_loop(n):
                if key not in done:
                    ribbon_n += paint_texel(px, w, h, x, y, RIBBON_PINK, 1)
                    done.add(key)
                continue

            if is_hair_loop(n) and not is_face_loop(n):
                if key not in done:
                    hair_n += paint_texel(px, w, h, x, y, BLONDE, 1)
                    done.add(key)

    img.pixels = px
    img.update()
    return hair_n, ribbon_n, eye_n


def main():
    arm = bpy.data.objects.get(ARM_NAME)
    if not arm:
        raise RuntimeError("Missing %s" % ARM_NAME)

    head, _ = mesh_parts(arm)
    if not head:
        raise RuntimeError("Missing head mesh")

    img = get_head_image(head)
    if not img:
        raise RuntimeError("No head colormap")

    h, r, e = paint_head_by_geometry(head, img)

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("Fixed hair for %s:" % ARM_NAME)
    print("  hair texels -> blonde:", h)
    print("  ribbon texels -> pink:", r)
    print("  eye/mouth texels:", e)
    print("Save: Ctrl+S")


main()
