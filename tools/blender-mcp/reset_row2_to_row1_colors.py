# Reset row-2 characters to match row-1 colors exactly.
# Copies fresh body colormap + row-1 head material for each character.
# Run in Blender: Scripting -> Open -> Run Script -> Ctrl+S

import bpy

ROW1_COL = "Packtory Characters"
ROW2_COL = "Packtory Characters Row 2"


def get_image_node(mat):
    if not mat or not mat.node_tree:
        return None
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            return node
    return None


def clean_material_nodes(mat):
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
            nt.nodes.remove(node)
    if principled and tex:
        base = principled.inputs["Base Color"]
        if base.is_linked:
            nt.links.remove(base.links[0])
        nt.links.new(tex.outputs["Color"], base)


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
    col = bpy.data.collections.get(ROW1_COL)
    if col:
        for o in col.objects:
            if o.type == "ARMATURE" and o.name == char_id:
                return o
    return None


def reset_body_from_row1(row1_body, row2_body, char_id):
    if not row1_body or not row1_body.data.materials:
        return False
    src_mat = row1_body.data.materials[0]
    src_node = get_image_node(src_mat)
    if not src_node or not src_node.image:
        return False

    img_name = f"colormap_{char_id}_row2_body"
    mat_name = f"colormap_{char_id}_row2_body"

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
    clean_material_nodes(new_mat)
    node = get_image_node(new_mat)
    if node:
        node.image = new_img
    row2_body.data.materials[0] = new_mat
    return True


def main():
    row2_col = bpy.data.collections.get(ROW2_COL)
    if not row2_col:
        raise RuntimeError("Missing: Packtory Characters Row 2")

    arms = sorted(
        [o for o in row2_col.objects if o.type == "ARMATURE"],
        key=lambda o: o.location.x,
    )

    report = []
    for arm in arms:
        char_id = arm.name.replace("_row2", "")
        row1 = find_row1_arm(char_id)
        if not row1:
            report.append(f"SKIP {char_id}: no row-1 match")
            continue

        head1, body1 = mesh_parts(row1)
        head2, body2 = mesh_parts(arm)

        if head2 and head1 and head1.data.materials:
            head2.data.materials[0] = head1.data.materials[0]
            report.append(f"{char_id}: head reset from row-1")

        if body2 and body1:
            if reset_body_from_row1(body1, body2, char_id):
                report.append(f"{char_id}: body colormap copied from row-1")
            else:
                report.append(f"{char_id}: body reset FAILED")
        else:
            report.append(f"{char_id}: missing body mesh")

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()

    print("\n".join(report))
    print("\nRow-2 now matches row-1 colors. Save with Ctrl+S.")
    print("Tell me each character and what to change (e.g. 'female-a row2: green shirt').")


main()
