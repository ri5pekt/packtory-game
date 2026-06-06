class_name CharacterVariation
extends RefCounted

## Runtime-only tint/prop overrides for instantiated Kenney characters.
## Duplicates materials per mesh instance — never edits imported GLB resources.

const MINI_CHARACTERS_BASE := (
	"res://blender/assets/kenney_mini-characters/Models/GLB format/"
)
const PROP_GLASSES := MINI_CHARACTERS_BASE + "aid-glasses.glb"
const PROP_SUNGLASSES := MINI_CHARACTERS_BASE + "aid-sunglasses.glb"


static func apply_recipe(model_root: Node3D, recipe: Dictionary) -> Dictionary:
	var result := {
		"ok": false,
		"body_tinted": false,
		"head_tinted": false,
		"prop_attached": false,
		"skip_reason": "",
	}
	if model_root == null:
		result.skip_reason = "Missing model root."
		return result

	var body_tint: Color = recipe.get("body_tint", Color.WHITE)
	var head_tint: Color = recipe.get("head_tint", Color.WHITE)
	result.body_tinted = _tint_meshes_named(model_root, "body", body_tint)
	result.head_tinted = _tint_meshes_named(model_root, "head", head_tint)
	result.ok = result.body_tinted or result.head_tinted

	var prop_path := String(recipe.get("prop", ""))
	if prop_path != "":
		result.prop_attached = _attach_prop(
			model_root,
			prop_path,
			recipe.get("prop_offset", Vector3(0.0, 1.42, 0.02)),
			float(recipe.get("prop_scale", 1.0))
		)

	if not result.ok and result.skip_reason == "":
		result.skip_reason = "No tintable body/head meshes found."
	return result


static func _tint_meshes_named(root: Node, name_part: String, tint: Color) -> bool:
	if tint == Color.WHITE:
		return false
	var applied := false
	for mesh in _find_mesh_instances(root):
		if name_part not in mesh.name.to_lower():
			continue
		if _apply_mesh_tint(mesh, tint):
			applied = true
	return applied


static func _apply_mesh_tint(mesh: MeshInstance3D, tint: Color) -> bool:
	var source := mesh.get_active_material(0)
	if source == null and mesh.mesh and mesh.mesh.get_surface_count() > 0:
		source = mesh.mesh.surface_get_material(0)
	if not source is StandardMaterial3D:
		return false
	var mat := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.albedo_color = tint
	mesh.material_override = mat
	return true


static func _attach_prop(
	model_root: Node3D,
	prop_path: String,
	offset: Vector3,
	scale: float
) -> bool:
	if prop_path.is_empty() or not ResourceLoader.exists(prop_path):
		return false
	var scene: PackedScene = load(prop_path)
	if scene == null:
		return false
	var prop: Node3D = scene.instantiate()
	prop.name = "VariationProp"
	prop.position = offset
	prop.scale = Vector3.ONE * scale
	model_root.add_child(prop)
	return true


static func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, meshes)
	return meshes


static func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, out)
