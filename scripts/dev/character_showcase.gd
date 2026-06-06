extends Node3D

## Developer scene: original Kenney presets + generated tint/prop variations.

const CharacterCatalogScript = preload("res://scripts/dev/character_catalog.gd")
const CharacterModelCleanupScript = preload("res://scripts/character_model_cleanup.gd")
const CharacterVariationScript = preload("res://scripts/dev/character_variation.gd")
const CharacterAnimationUtilsScript = preload(
	"res://scripts/shared/character_animation_utils.gd"
)

const COLS := 4
const SPACING := 2.35
const MODEL_SCALE := 1.0
const LABEL_Y := 1.62
const FLOOR_PAD := 2.4
const FLOOR_THICKNESS := 0.14
const ZONE_GAP := 4.5
const SECTION_LABEL_Y := 2.35

@onready var _originals_root: Node3D = $Originals
@onready var _variations_root: Node3D = $Variations
@onready var _camera_rig: Node3D = $ShowcaseCamera
@onready var _touch_input: Node = $TouchInput


func _ready() -> void:
	var originals := CharacterCatalogScript.all_showcase_entries()
	var variations := CharacterCatalogScript.all_variation_entries()
	_build_floor(originals.size(), variations.size())
	_add_section_title(
		_originals_root,
		"ORIGINAL PRESETS",
		Vector3(0.0, SECTION_LABEL_Y, -1.6),
		Color(0.78, 0.86, 0.98)
	)
	_populate_zone(_originals_root, originals, Vector3.ZERO, false)
	var variations_offset_z := _zone_depth(originals.size()) + ZONE_GAP
	_add_section_title(
		_variations_root,
		"GENERATED VARIATIONS",
		Vector3(0.0, SECTION_LABEL_Y, variations_offset_z - 1.6),
		Color(0.98, 0.84, 0.58)
	)
	_variations_root.position = Vector3.ZERO
	_populate_zone(_variations_root, variations, Vector3(0.0, 0.0, variations_offset_z), true)
	_frame_camera(originals.size(), variations.size(), variations_offset_z)
	if _touch_input:
		_touch_input.pan_drag.connect(_camera_rig.pan_screen_delta)
		_touch_input.zoom.connect(_camera_rig.zoom_by)
		_touch_input.reset_view_requested.connect(_camera_rig.reset_view)


func _build_floor(original_count: int, variation_count: int) -> void:
	var originals_depth := _zone_depth(original_count)
	var variations_depth := _zone_depth(variation_count)
	var total_depth := originals_depth + ZONE_GAP + variations_depth
	var width := float(COLS) * SPACING + FLOOR_PAD
	var origin := Vector3(-((float(COLS) - 1.0) * SPACING) * 0.5, 0.0, -1.2)

	_add_floor_panel(
		"OriginalsFloor",
		Vector3(width, FLOOR_THICKNESS, originals_depth + FLOOR_PAD),
		origin + Vector3(0.0, -FLOOR_THICKNESS * 0.5, originals_depth * 0.5),
		Color(0.22, 0.25, 0.30)
	)
	_add_floor_panel(
		"VariationsFloor",
		Vector3(width, FLOOR_THICKNESS, variations_depth + FLOOR_PAD),
		origin + Vector3(0.0, -FLOOR_THICKNESS * 0.5, originals_depth + ZONE_GAP + variations_depth * 0.5),
		Color(0.20, 0.23, 0.28)
	)
	_add_floor_panel(
		"GapStrip",
		Vector3(width * 0.85, 0.03, ZONE_GAP - 0.4),
		origin + Vector3(0.0, 0.005, originals_depth + ZONE_GAP * 0.5),
		Color(0.14, 0.16, 0.20)
	)


func _add_floor_panel(panel_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = panel_name
	var box := BoxMesh.new()
	box.size = size
	floor_mesh.mesh = box
	floor_mesh.position = position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	floor_mesh.material_override = mat
	add_child(floor_mesh)


func _populate_zone(
	parent: Node3D,
	entries: Array,
	zone_offset: Vector3,
	is_variation: bool
) -> void:
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var slot := Node3D.new()
		slot.name = String(entry.get("id", "Entry_%d" % i))
		slot.position = zone_offset + _slot_position(i, entries.size())
		parent.add_child(slot)

		var path := String(entry.get("path", ""))
		var model := _instantiate_character(path)
		if model == null:
			_add_slot_label(slot, "%s\n(missing)" % entry.get("id", "?"), Color(0.95, 0.45, 0.4))
			continue

		model.name = "Model"
		model.scale = Vector3.ONE * MODEL_SCALE
		slot.add_child(model)
		CharacterModelCleanupScript.strip_accessories(model)

		var label_text := String(entry.get("id", ""))
		var label_color := Color(0.92, 0.95, 1.0)
		if is_variation:
			var apply_result: Dictionary = CharacterVariationScript.apply_recipe(model, entry)
			label_text = _variation_label(entry, apply_result)
			label_color = Color(0.98, 0.88, 0.62) if apply_result.get("ok", false) else Color(0.95, 0.5, 0.45)
		_play_idle(model)
		_add_slot_label(slot, label_text, label_color)


func _variation_label(entry: Dictionary, apply_result: Dictionary) -> String:
	var short := String(entry.get("label", entry.get("id", "Variation")))
	var base := String(entry.get("base_id", ""))
	if not apply_result.get("ok", false):
		return "%s\n%s\n(skip)" % [short, base]
	var bits: PackedStringArray = []
	if apply_result.get("body_tinted", false):
		bits.append("outfit")
	if apply_result.get("head_tinted", false):
		bits.append("hair")
	if apply_result.get("prop_attached", false):
		bits.append("prop")
	return "%s\n%s\n(%s)" % [short, base, ", ".join(bits)]


func _instantiate_character(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("CharacterShowcase: missing model %s" % path)
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	return scene.instantiate()


func _play_idle(model_root: Node) -> void:
	var anim := CharacterAnimationUtilsScript.find_animation_player(model_root)
	if anim == null:
		return
	var idle_name := CharacterAnimationUtilsScript.resolve_anim_name(
		anim, ["idle", "Idle", "static"]
	)
	if idle_name.is_empty():
		return
	var animation: Animation = anim.get_animation(idle_name)
	if animation:
		animation.loop_mode = Animation.LOOP_LINEAR
	anim.play(idle_name)


func _add_slot_label(parent: Node3D, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = text
	label.font_size = 32
	label.modulate = color
	label.position = Vector3(0.0, LABEL_Y, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0, 0.75)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _add_section_title(parent: Node3D, text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = "SectionTitle"
	label.text = text
	label.font_size = 52
	label.modulate = color
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _zone_depth(entry_count: int) -> float:
	var rows := ceili(float(entry_count) / float(COLS))
	return maxf(0.0, (float(rows) - 1.0) * SPACING)


func _slot_position(index: int, entry_count: int) -> Vector3:
	var col := index % COLS
	var row := index / COLS
	var width := (float(COLS) - 1.0) * SPACING
	return Vector3(float(col) * SPACING - width * 0.5, 0.0, float(row) * SPACING)


func _frame_camera(original_count: int, variation_count: int, variations_offset_z: float) -> void:
	if _camera_rig == null or not _camera_rig.has_method("set_focus"):
		return
	var originals_depth := _zone_depth(original_count)
	var variations_depth := _zone_depth(variation_count)
	var center_z := (originals_depth + variations_offset_z + variations_depth) * 0.5
	_camera_rig.set_focus(Vector3(0.0, 0.0, center_z))
