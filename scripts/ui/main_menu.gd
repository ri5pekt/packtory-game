extends Control

## Main menu — Start Game begins a fresh run; Continue loads the latest save.

const GAMEPLAY_SCENE := "res://scenes/main/main.tscn"

const BG_COLOR := Color(0.08, 0.11, 0.16, 1.0)
const ACCENT := Color(0.26, 0.62, 0.92)
const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := Color(0.62, 0.70, 0.80)
const BTN_MIN_HEIGHT := 52.0

var _built := false
var _continue_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	ensure_built()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_relayout):
		viewport.size_changed.connect(_relayout)
	_relayout()
	_refresh_continue_button()


func ensure_built() -> void:
	if _built:
		return
	_built = true
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var title := Label.new()
	title.text = "Packtory"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Warehouse fulfillment simulator"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", DIM_TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(subtitle)

	col.add_child(_spacer(12))

	_continue_btn = Button.new()
	_continue_btn.name = "ContinueGameButton"
	_continue_btn.text = "Continue Game"
	_continue_btn.custom_minimum_size = Vector2(220.0, BTN_MIN_HEIGHT)
	_continue_btn.pressed.connect(_on_continue_pressed)
	_style_primary_button(_continue_btn)
	col.add_child(_continue_btn)

	var start_btn := Button.new()
	start_btn.name = "StartGameButton"
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size = Vector2(220.0, BTN_MIN_HEIGHT)
	start_btn.pressed.connect(_on_start_pressed)
	_style_primary_button(start_btn)
	col.add_child(start_btn)


func _on_start_pressed() -> void:
	var save := get_node_or_null("/root/SaveManager")
	if save and save.has_method("prepare_new_game"):
		save.prepare_new_game()
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _on_continue_pressed() -> void:
	var save := get_node_or_null("/root/SaveManager")
	if save == null or not save.has_method("prepare_continue_game"):
		return
	if not save.prepare_continue_game():
		return
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func _refresh_continue_button() -> void:
	if _continue_btn == null:
		return
	var save := get_node_or_null("/root/SaveManager")
	var has_save: bool = save != null and save.has_method("has_save") and save.has_save()
	_continue_btn.visible = has_save
	_continue_btn.disabled = not has_save


func _style_primary_button(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT.darkened(0.12)
	normal.border_color = ACCENT.lightened(0.1)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACCENT
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 18)


func _spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0.0, height)
	return s


func _relayout() -> void:
	pass
