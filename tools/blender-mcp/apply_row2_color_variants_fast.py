# FAST version — uses Hue/Sat shader nodes (no pixel loops).
# Run in Blender: Scripting -> Open -> Run Script
# If Blender feels stuck, this finishes in ~1 second.

import bpy

ROW2_COL = "Packtory Characters Row 2"

# Hue values 0..1 for visibly different shirts
HUES = [0.0, 0.08, 0.16, 0.24, 0.33, 0.42, 0.50, 0.58, 0.66, 0.75, 0.83, 0.91, 0.04]


def get_image_node(mat):
    if not mat or not mat.node_tree:
        return None
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE":
            return node
    return None


def get_principled(mat):
    if not mat or not mat.node_tree:
        return None
    for node in mat.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            return node
    return None


def ensure_row2_material(mesh_obj, char_id, part):
    if not mesh_obj.data.materials:
        return None
    src = mesh_obj.data.materials[0]
    name = f"colormap_{char_id}_row2_{part}"
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = src.copy()
        mat.name = name
    mesh_obj.data.materials[0] = mat
    return mat


def add_hue_sat(mat, hue, saturation=1.25, value=1.05):
    nt = mat.node_tree
    if not nt:
        return False
    # Remove old hue node if re-running
    for node in list(nt.nodes):
        if node.name == "Row2HueSat":
            nt.nodes.remove(node)

    principled = get_principled(mat)
    tex = get_image_node(mat)
    if not principled or not tex:
        return False

    hs = nt.nodes.new("ShaderNodeHueSaturation")
    hs.name = "Row2HueSat"
    hs.label = "Row2 Variant"
    hs.location = (tex.location.x + 220, tex.location.y)
    hs.inputs["Hue"].default_value = hue
    hs.inputs["Saturation"].default_value = saturation
    hs.inputs["Value"].default_value = value

    base_in = principled.inputs["Base Color"]
    if base_in.is_linked:
        from_sock = base_in.links[0].from_socket
        nt.links.remove(base_in.links[0])
        nt.links.new(from_sock, hs.inputs["Color"])
    else:
        nt.links.new(tex.outputs["Color"], hs.inputs["Color"])
    nt.links.new(hs.outputs["Color"], base_in)
    return True


def main():
    col = bpy.data.collections.get(ROW2_COL)
    if not col:
        raise RuntimeError("Missing collection: Packtory Characters Row 2")

    arms = sorted(
        [o for o in col.objects if o.type == "ARMATURE"],
        key=lambda o: o.location.x,
    )

    done = []
    for idx, arm in enumerate(arms):
        char_id = arm.name.replace("_row2", "")
        hue = HUES[idx % len(HUES)]
        for child in arm.children:
            if child.type != "MESH" or "body" not in child.name.lower():
                continue  # never tint head — skin/hair live on head-mesh
            mat = ensure_row2_material(child, char_id, "body")
            if not mat:
                continue
            if add_hue_sat(mat, hue, 1.12, 1.0):
                done.append(f"{char_id} body hue={hue:.2f}")

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("Applied %d material variants:" % len(done))
    for line in done:
        print("  ", line)
    print("Done. Save manually: File -> Save (Ctrl+S)")


main()
