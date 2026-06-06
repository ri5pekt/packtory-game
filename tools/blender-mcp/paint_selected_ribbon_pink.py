# Paint SELECTED ribbon faces -> pink (Edit Mode only)
# 1) head-mesh selected, Edit Mode, ribbon faces selected
# 2) Run Script -> Ctrl+S

import bpy
import bmesh

RIBBON_RGB = (0.95, 0.42, 0.62)


def get_image_node(mat):
    if not mat or not mat.node_tree:
        return None
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            return node
    return None


obj = bpy.context.active_object
if not obj or obj.type != "MESH":
    raise RuntimeError("Select the head-mesh object")

if bpy.context.mode != "EDIT_MESH":
    raise RuntimeError("Tab into Edit Mode and select ribbon faces, then run")

mesh = obj.data
node = get_image_node(mesh.materials[0]) if mesh.materials else None
if not node or not node.image:
    raise RuntimeError("No colormap image on material")

img = node.image
bm = bmesh.from_edit_mesh(mesh)
uv_layer = bm.loops.layers.uv.active
if not uv_layer:
    raise RuntimeError("No UV layer")

selected = [f for f in bm.faces if f.select]
if not selected:
    raise RuntimeError("Select the ribbon faces first")

w, h = img.size
px = list(img.pixels)
done, n = set(), 0

for face in selected:
    for loop in face.loops:
        uv = loop[uv_layer].uv
        x = min(w - 1, max(0, int(uv.x * w)))
        y = min(h - 1, max(0, int(uv.y * h)))
        if (x, y) in done:
            continue
        i = (y * w + x) * 4
        px[i : i + 3] = list(RIBBON_RGB)
        done.add((x, y))
        n += 1

img.pixels = px
img.update()
bmesh.update_edit_mesh(mesh, loop_triangles=False, destructive=False)

print("Ribbon -> pink: %d texels (%d faces) on %s" % (n, len(selected), img.name))
print("Save: Ctrl+S")
