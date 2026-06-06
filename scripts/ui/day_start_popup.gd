extends Control

## Welcome popup shown when the warehouse scene loads. Gameplay stays paused until
## the player acknowledges it.

signal acknowledged

const PANEL_BG := Color(0.08, 0.10, 0.14, 0.98)
const ACCENT := Color(0.26, 0.62, 0.92)
const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := Color(0.62, 0.70, 0.80)
const BTN_MIN_HEIGHT := 52.0

var _open := false
var _built := false
var _overlay: ColorRect
var _panel: PanelContainer


func _ready() -> void:
	add_to_group("day_start_popup")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	ensure_built()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_relayout):
		viewport.size_changed.connect(_relayout)
	visible = false


func ensure_built() -> void:
	if _built:
		return
	_built = true
	_build()


func is_open() -> bool:
	return _open


func open(day_number: int = 1) -> void:
	ensure_built()
	_open = true
	visible = true
	_overlay.visible = true
	_panel.visible = true
	_update_copy(day_number)
	_relayout()


func close() -> void:
	ensure_built()
	if not _open:
		return
	_open = false
	visible = false
	_overlay.visible = false
	_panel.visible = false


func notify_world_tap(_screen_position: Vector2) -> bool:
	return _open


func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Welcome to Packtory"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var body := Label.new()
	body.name = "BodyLabel"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", DIM_TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(body)

	var start_btn := Button.new()
	start_btn.name = "StartDayButton"
	start_btn.text = "Start Day"
	start_btn.custom_minimum_size = Vector2(0.0, BTN_MIN_HEIGHT)
	start_btn.pressed.connect(_on_start_day_pressed)
	_style_button(start_btn)
	col.add_child(start_btn)


func _update_copy(day_number: int) -> void:
	var body := _panel.find_child("BodyLabel", true, false) as Label
	if body:
		body.text = (
			"Day %d is ready.\n\nPick up the morning delivery, stock shelves, take orders, "
			+ "and pack shipments. Customers arrive once you begin the day."
		) % day_number


func _on_start_day_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session and session.has_method("acknowledge_day_start"):
		session.acknowledge_day_start()
	close()
	acknowledged.emit()


func _style_button(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.55, 0.34, 0.95)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.64, 0.40, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 17)


func _relayout() -> void:
	if _panel == null or not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(mini(460.0, vp.x - 48.0), 0.0)
	_panel.position = Vector2(
		(vp.x - _panel.size.x) * 0.5,
		(vp.y - _panel.size.y) * 0.42
	)
