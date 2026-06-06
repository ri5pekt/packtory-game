class_name CharacterModelCleanup
extends RefCounted

## Remove Kenney accessory props (hearing aids, canes, etc.) from instantiated characters.
## Only targets nodes that look like aids — never strips core body/head meshes.

const _STRIP_NAME_PARTS: PackedStringArray = [
	"aid",
	"hearing",
	"crutch",
	"cane",
	"glasses",
	"sunglasses",
	"mask",
	"wheelchair",
	"defibrillator",
]


static func strip_accessories(model_root: Node) -> void:
	if model_root == null:
		return
	var to_remove: Array[Node] = []
	_collect_accessories(model_root, to_remove)
	for node in to_remove:
		if is_instance_valid(node):
			node.queue_free()


static func _collect_accessories(node: Node, out: Array[Node]) -> void:
	if _is_accessory_node(node):
		out.append(node)
		return
	for child in node.get_children():
		_collect_accessories(child, out)


static func _is_accessory_node(node: Node) -> bool:
	var label := node.name.to_lower()
	if _name_matches(label):
		return true
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh != null:
			var mesh_path := mesh_inst.mesh.resource_path.to_lower()
			if mesh_path != "" and _name_matches(mesh_path.get_file().get_basename()):
				return true
	return false


static func _name_matches(label: String) -> bool:
	for part in _STRIP_NAME_PARTS:
		if part in label:
			return true
	return false
