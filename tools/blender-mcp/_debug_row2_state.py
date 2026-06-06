import bpy
import colorsys

BLEND = r"C:\Users\denis\Desktop\godot-projects\packtory-game\blender\packtory_characters_lineup.blend"
bpy.ops.wm.open_mainfile(filepath=BLEND)


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


def is_shirt_a(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.68 <= h <= 0.88 and s > 0.12 and v > 0.22


def count_match(img, test_fn):
    n = 0
    px = img.pixels
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01 or not test_fn(r, g, b):
            continue
        n += 1
    return n


row2 = bpy.data.collections.get("Packtory Characters Row 2")
if row2:
    arms = sorted([o for o in row2.objects if o.type == "ARMATURE"], key=lambda o: o.name)
    print("Row2 armatures:", [a.name for a in arms[:3]])

for char_id in ["character-female-a", "character-female-b"]:
    for suffix in ["", "_row2"]:
        arm = bpy.data.objects.get(char_id + suffix)
        if not arm:
            print(char_id + suffix, "MISSING")
            continue
        head, body = mesh_parts(arm)
        for part, mesh in [("body", body), ("head", head)]:
            if not mesh:
                continue
            mat = mesh.data.materials[0] if mesh.data.materials else None
            node = get_image_node(mat)
            img = node.image if node else None
            shirt_px = count_match(img, is_shirt_a) if img else 0
            print(
                "%s %s: mat=%s img=%s users=%s shirt_a_px=%d"
                % (char_id + suffix, part, mat.name if mat else None, img.name if img else None, img.users if img else 0, shirt_px)
            )
