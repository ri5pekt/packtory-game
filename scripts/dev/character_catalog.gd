class_name CharacterCatalog
extends RefCounted

## Kenney character GLBs used for gameplay and the developer showcase.

const MINI_CHARACTERS_BASE := (
	"res://blender/assets/kenney_mini-characters/Models/GLB format/"
)
const MINI_MARKET_BASE := (
	"res://blender/assets/kenney_mini-market/Models/GLB format/"
)

## Default manager / player Kenney model — reserved for workers, not NPC traffic.
const DEFAULT_PLAYER_MODEL := "character-male-d.glb"

const PLAYABLE_MODELS: PackedStringArray = [
	"character-female-a.glb",
	"character-female-b.glb",
	"character-female-c.glb",
	"character-female-d.glb",
	"character-female-e.glb",
	"character-female-f.glb",
	"character-male-a.glb",
	"character-male-b.glb",
	"character-male-c.glb",
	"character-male-d.glb",
	"character-male-e.glb",
	"character-male-f.glb",
]


static func all_showcase_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for file_name in PLAYABLE_MODELS:
		entries.append(_entry(file_name, MINI_CHARACTERS_BASE, "mini-characters"))
	entries.append(_entry("character-employee.glb", MINI_MARKET_BASE, "mini-market"))
	return entries


static func model_path(file_name: String) -> String:
	if file_name == "character-employee.glb":
		return MINI_MARKET_BASE + file_name
	return MINI_CHARACTERS_BASE + file_name


static func is_player_model(file_name: String) -> bool:
	return file_name.get_file() == DEFAULT_PLAYER_MODEL


static func npc_character_models(extra_reserved: PackedStringArray = PackedStringArray()) -> Array[String]:
	var reserved := {DEFAULT_PLAYER_MODEL: true}
	for file_name in extra_reserved:
		var base_name := file_name.get_file()
		if base_name != "":
			reserved[base_name] = true
	var models: Array[String] = []
	for file_name in PLAYABLE_MODELS:
		if not reserved.has(file_name):
			models.append(file_name)
	return models


static func reserved_worker_model_files(tree: SceneTree) -> PackedStringArray:
	var files := PackedStringArray([DEFAULT_PLAYER_MODEL])
	for node in tree.get_nodes_in_group("workers"):
		if node.has_method("get_model_file"):
			var file_name := String(node.call("get_model_file"))
			if file_name != "" and not files.has(file_name):
				files.append(file_name)
	return files


static func pick_random_npc_model(
	rng: RandomNumberGenerator = null,
	tree: SceneTree = null
) -> String:
	var reserved := PackedStringArray([DEFAULT_PLAYER_MODEL])
	if tree != null:
		reserved = reserved_worker_model_files(tree)
	var models := npc_character_models(reserved)
	if models.is_empty():
		push_warning("CharacterCatalog: no NPC models left after exclusions")
		return "character-male-a.glb"
	var idx: int
	if rng != null:
		idx = rng.randi_range(0, models.size() - 1)
	else:
		idx = randi_range(0, models.size() - 1)
	return models[idx]


static func display_name(file_name: String) -> String:
	return file_name.get_basename()


static func all_variation_entries() -> Array[Dictionary]:
	return [
		_variation(
			"var-navy-blonde-male-d",
			"character-male-d.glb",
			"Navy + Blonde",
			Color(0.50, 0.58, 0.95),
			Color(1.12, 1.05, 0.68)
		),
		_variation(
			"var-forest-male-b",
			"character-male-b.glb",
			"Forest Green",
			Color(0.48, 0.88, 0.52),
			Color(0.92, 0.78, 0.62)
		),
		_variation(
			"var-burgundy-female-a",
			"character-female-a.glb",
			"Burgundy",
			Color(0.92, 0.42, 0.48),
			Color(0.55, 0.36, 0.30)
		),
		_variation(
			"var-teal-auburn-female-c",
			"character-female-c.glb",
			"Teal + Auburn",
			Color(0.38, 0.82, 0.88),
			Color(1.05, 0.62, 0.38)
		),
		_variation(
			"var-charcoal-red-male-a",
			"character-male-a.glb",
			"Charcoal + Ginger",
			Color(0.42, 0.44, 0.48),
			Color(1.15, 0.72, 0.38)
		),
		_variation(
			"var-sunrise-female-e",
			"character-female-e.glb",
			"Sunrise Orange",
			Color(1.05, 0.62, 0.32),
			Color(0.95, 0.55, 0.72)
		),
		_variation(
			"var-lavender-female-d",
			"character-female-d.glb",
			"Lavender",
			Color(0.78, 0.58, 0.95),
			Color(0.35, 0.28, 0.38)
		),
		_variation(
			"var-employee-copper",
			"character-employee.glb",
			"Copper Uniform",
			Color(0.95, 0.55, 0.28),
			Color(0.62, 0.40, 0.28),
			MINI_MARKET_BASE
		),
		_variation_prop(
			"var-glasses-male-c",
			"character-male-c.glb",
			"Glasses Accent",
			Color(0.62, 0.72, 0.95),
			Color(0.88, 0.82, 0.72),
			MINI_CHARACTERS_BASE + "aid-glasses.glb"
		),
		_variation_prop(
			"var-shades-female-f",
			"character-female-f.glb",
			"Sunglasses Accent",
			Color(0.95, 0.48, 0.55),
			Color(0.28, 0.22, 0.20),
			MINI_CHARACTERS_BASE + "aid-sunglasses.glb"
		),
		_variation(
			"var-ice-male-e",
			"character-male-e.glb",
			"Ice Blue",
			Color(0.55, 0.82, 1.08),
			Color(0.82, 0.88, 0.95)
		),
		_variation(
			"var-olive-female-b",
			"character-female-b.glb",
			"Olive + Chestnut",
			Color(0.58, 0.72, 0.38),
			Color(0.72, 0.48, 0.30)
		),
	]


static func _entry(file_name: String, base: String, kit: String) -> Dictionary:
	return {
		"id": display_name(file_name),
		"file": file_name,
		"path": base + file_name,
		"kit": kit,
	}


static func _variation(
	id: String,
	base_file: String,
	short_label: String,
	body_tint: Color,
	head_tint: Color,
	base: String = MINI_CHARACTERS_BASE
) -> Dictionary:
	return {
		"id": id,
		"base_file": base_file,
		"base_id": display_name(base_file),
		"path": base + base_file,
		"label": short_label,
		"body_tint": body_tint,
		"head_tint": head_tint,
		"prop": "",
	}


static func _variation_prop(
	id: String,
	base_file: String,
	short_label: String,
	body_tint: Color,
	head_tint: Color,
	prop_path: String
) -> Dictionary:
	var entry := _variation(id, base_file, short_label, body_tint, head_tint)
	entry["prop"] = prop_path
	return entry
