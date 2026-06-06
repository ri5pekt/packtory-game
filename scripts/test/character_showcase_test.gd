extends SceneTree

## Run with: godot --headless --path . --script res://scripts/test/character_showcase_test.gd

const CharacterCatalogScript = preload("res://scripts/dev/character_catalog.gd")
const CharacterVariationScript = preload("res://scripts/dev/character_variation.gd")
const SHOWCASE_SCENE := "res://scenes/dev/character_showcase.tscn"
const SAMPLE_GLB := (
	"res://blender/assets/kenney_mini-characters/Models/GLB format/character-male-d.glb"
)


func _init() -> void:
	var failed := 0
	failed += _assert("catalog lists 13 characters", _test_catalog_count())
	failed += _assert("catalog lists 12 variations", _test_variation_count())
	failed += _assert("all catalog model files exist", _test_model_paths())
	failed += _assert("npc pool excludes player model", _test_npc_pool_excludes_player())
	failed += _assert("variation tints do not share overrides", _test_variation_isolation())
	failed += _assert("showcase scene loads", _test_scene_loads())

	if failed == 0:
		print("character_showcase_test: ALL PASSED")
		quit(0)
	else:
		push_error("character_showcase_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _test_catalog_count() -> bool:
	return CharacterCatalogScript.all_showcase_entries().size() == 13


func _test_variation_count() -> bool:
	return CharacterCatalogScript.all_variation_entries().size() == 12


func _test_model_paths() -> bool:
	for entry in CharacterCatalogScript.all_showcase_entries():
		if not _path_exists(entry):
			return false
	for entry in CharacterCatalogScript.all_variation_entries():
		if not _path_exists(entry):
			return false
		var prop := String(entry.get("prop", ""))
		if prop != "" and not ResourceLoader.exists(prop):
			push_error("Missing prop: %s" % prop)
			return false
	return true


func _test_npc_pool_excludes_player() -> bool:
	var models := CharacterCatalogScript.npc_character_models()
	if models.has(CharacterCatalogScript.DEFAULT_PLAYER_MODEL):
		return false
	return models.size() == CharacterCatalogScript.PLAYABLE_MODELS.size() - 1


func _path_exists(entry: Dictionary) -> bool:
	var path := String(entry.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Missing model: %s" % path)
		return false
	return true


func _test_variation_isolation() -> bool:
	var scene_a: PackedScene = load(SAMPLE_GLB)
	var scene_b: PackedScene = load(SAMPLE_GLB)
	var model_a: Node3D = scene_a.instantiate()
	var model_b: Node3D = scene_b.instantiate()
	root.add_child(model_a)
	root.add_child(model_b)
	var recipe := CharacterCatalogScript.all_variation_entries()[0]
	CharacterVariationScript.apply_recipe(model_a, recipe)
	var mesh_a := _first_body_mesh(model_a)
	var mesh_b := _first_body_mesh(model_b)
	if mesh_a == null or mesh_b == null:
		return false
	return mesh_a.material_override != null and mesh_b.material_override == null


func _first_body_mesh(root: Node) -> MeshInstance3D:
	return _find_body_mesh(root)


func _find_body_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and "body" in node.name.to_lower():
		return node
	for child in node.get_children():
		var found := _find_body_mesh(child)
		if found:
			return found
	return null


func _test_scene_loads() -> bool:
	var packed: PackedScene = load(SHOWCASE_SCENE)
	if packed == null:
		return false
	var scene: Node = packed.instantiate()
	if scene == null:
		return false
	return (
		scene.get_script() != null
		and scene.get_node_or_null("Originals") != null
		and scene.get_node_or_null("Variations") != null
	)
