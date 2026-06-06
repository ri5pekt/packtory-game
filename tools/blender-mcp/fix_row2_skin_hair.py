# Fix row-2: restore normal head/skin/hair, tint OUTFIT on body only.
# Run in Blender: Scripting -> Open -> Run Script -> Save (Ctrl+S)

import bpy

ROW1_COL = "Packtory Characters"
ROW2_COL = "Packtory Characters Row 2"

# Same outfit tints as character_catalog.gd variations (multiply on body only)
BODY_TINTS = [
    (0.50, 0.58, 0.95),  # female-a -> navy-ish
    (0.58, 0.72, 0.38),  # female-b -> olive
    (0.38, 0.82, 0.88),  # female-c -> teal
    (0.78, 0.58, 0.95),  # female-d -> lavender
    (1.05, 0.62, 0.32),  # female-e -> sunrise
    (0.95, 0.48, 0.55),  # female-f -> coral
    (0.42, 0.44, 0.48),  # male-a -> charcoal
    (0.48, 0.88, 0.52),  # male-b -> forest
    (0.62, 0.72, 0.95),  # male-c -> soft blue
    (0.50, 0.58, 0.95),  # male-d -> navy
    (0.55, 0.82, 1.08),  # male-e -> ice
    (0.48, 0.88, 0.52),  # male-f -> green
    (0.95, 0.55, 0.28),  # employee -> copper
]


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


def find_row1_armature(char_id):
    obj = bpy.data.objects.get(char_id)
    if obj and obj.type == "ARMATURE":
        return obj
    col = bpy.data.collections.get(ROW1_COL)
    if col:
        for o in col.objects:
            if o.type == "ARMATURE" and o.name == char_id:
                return o
    return None


def remove_row2_nodes(mat):
    if not mat or not mat.node_tree:
        return
    nt = mat.node_tree
    principled = tex = None
    for node in nt.nodes:
        if node.type == "BSDF_PRINCIPLED":
            principled = node
        if node.type == "TEX_IMAGE":
            tex = node
    for node in list(nt.nodes):
        if node.name in ("Row2HueSat", "Row2BodyTint"):
            # reconnect input if needed
            nt.nodes.remove(node)
    if principled and tex:
        base = principled.inputs["Base Color"]
        if not base.is_linked:
            nt.links.new(tex.outputs["Color"], base)


def ensure_body_material(body_mesh, char_id):
    if not body_mesh.data.materials:
        return None
    src = body_mesh.data.materials[0]
    name = f"colormap_{char_id}_row2_body"
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = src.copy()
        mat.name = name
    remove_row2_nodes(mat)
    body_mesh.data.materials[0] = mat
    return mat


def apply_body_multiply_tint(mat, tint_rgb):
    nt = mat.node_tree
    if not nt:
        return False
    remove_row2_nodes(mat)

    principled = tex = None
    for node in nt.nodes:
        if node.type == "BSDF_PRINCIPLED":
            principled = node
        if node.type == "TEX_IMAGE":
            tex = node
    if not principled or not tex:
        return False

    mix = nt.nodes.new("ShaderNodeMix")
    mix.name = "Row2BodyTint"
    mix.label = "Outfit Tint"
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.clamp_result = True
    mix.location = (tex.location.x + 220, tex.location.y)
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs[6].default_value = (1.0, 1.0, 1.0, 1.0)
    mix.inputs[7].default_value = (tint_rgb[0], tint_rgb[1], tint_rgb[2], 1.0)

    base = principled.inputs["Base Color"]
    if base.is_linked:
        nt.links.remove(base.links[0])
    nt.links.new(tex.outputs["Color"], mix.inputs[6])
    nt.links.new(mix.outputs[2], base)
    return True


def main():
    row2 = bpy.data.collections.get(ROW2_COL)
    if not row2:
        raise RuntimeError("Missing: Packtory Characters Row 2")

    arms = sorted(
        [o for o in row2.objects if o.type == "ARMATURE"],
        key=lambda o: o.location.x,
    )

    report = []
    for idx, arm in enumerate(arms):
        char_id = arm.name.replace("_row2", "")
        row1 = find_row1_armature(char_id)
        head2, body2 = mesh_parts(arm)

        # Restore head: use row-1 head material exactly (skin + hair unchanged)
        if head2 and row1:
            head1, _ = mesh_parts(row1)
            if head1 and head1.data.materials:
                head2.data.materials[0] = head1.data.materials[0]
                report.append(f"{char_id}: head restored from row-1")
        elif head2 and head2.data.materials:
            remove_row2_nodes(head2.data.materials[0])
            report.append(f"{char_id}: head hue removed")

        # Body: outfit tint only
        if body2:
            tint = BODY_TINTS[idx % len(BODY_TINTS)]
            mat = ensure_body_material(body2, char_id)
            if mat and apply_body_multiply_tint(mat, tint):
                report.append(f"{char_id}: body tint {tuple(round(c, 2) for c in tint)}")

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("\n".join(report))
    print("\nDone. Row-2 heads match row-1. Bodies have outfit tint only.")
    print("Save: Ctrl+S")


main()
