extends Control

## Mobile-friendly warehouse layout editor controls.

const WarehouseEditModeScript = preload("res://scripts/warehouse/warehouse_edit_mode.gd")

const BAR_HEIGHT := 72.0
const BTN_MIN_HEIGHT := 52.0
const BTN_GAP := 10.0
const PAD := 12.0
const HINT_HEIGHT := 28.0

const BTN_BG := Color(0.14, 0.17, 0.24, 0.94)
const BTN_BORDER := Color(0.38, 0.44, 0.54, 0.9)
const ACCENT := Color(0.26, 0.62, 0.92)
const APPLY_BG := Color(0.18, 0.55, 0.34, 0.95)
const CANCEL_BG := Color(0.55, 0.22, 0.20, 0.95)
const TEXT_COLOR := Color(1.0, 1.0, 1.0)
const DIM_TEXT := Color(0.78, 0.83, 0.90)

var _edit_mode: Node
var _bar: PanelContainer
var _hint: Label
var _rotate_btn: Button
var _cancel_btn: Button
var _apply_btn: Button
var _done_btn: Button
var _action_row: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_relayout()
	get_viewport().size_changed.connect(_relayout)


func bind_edit_mode(edit_mode: Node) -> void:
	_edit_mode = edit_mode
	if not _edit_mode.mode_changed.is_connected(_on_mode_changed):
		_edit_mode.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(_edit_mode.is_active())


func consumes_tap(screen_position: Vector2) -> bool:
	if not _bar or not _bar.visible:
		return false
	return _bar.get_global_rect().has_point(screen_position)


func on_mode_entered() -> void:
	_set_hud_enter_visible(false)
	_bar.visible = true
	_update_action_buttons()


func on_mode_exited() -> void:
	_set_hud_enter_visible(true)
	_bar.visible = false
	_hint.text = "Tap the layout icon to move shelves and tables."


func on_selection_changed(placeable: Node) -> void:
	if placeable == null:
		_hint.text = "Tap a shelf, table, or reception desk to select it."
	else:
		var label := "object"
		if placeable.has_method("get_placeable_label"):
			label = placeable.get_placeable_label()
		_hint.text = "Selected: %s — tap floor tiles to move." % label
	_update_action_buttons()


func _build() -> void:
	_bar = PanelContainer.new()
	_bar.name = "EditBar"
	_bar.visible = false
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.08, 0.10, 0.14, 0.92)
	bar_style.set_corner_radius_all(14)
	bar_style.content_margin_left = PAD
	bar_style.content_margin_right = PAD
	bar_style.content_margin_top = PAD
	bar_style.content_margin_bottom = PAD
	_bar.add_theme_stylebox_override("panel", bar_style)
	add_child(_bar)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_bar.add_child(column)

	_hint = Label.new()
	_hint.text = "Tap the layout icon to move shelves and tables."
	_hint.add_theme_color_override("font_color", DIM_TEXT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)

	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", BTN_GAP)
	_action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_action_row)

	_rotate_btn = _make_button("Rotate", BTN_BG)
	_rotate_btn.pressed.connect(_on_rotate_pressed)
	_action_row.add_child(_rotate_btn)

	_cancel_btn = _make_button("Cancel", CANCEL_BG)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_action_row.add_child(_cancel_btn)

	_apply_btn = _make_button("Apply", APPLY_BG)
	_apply_btn.pressed.connect(_on_apply_pressed)
	_action_row.add_child(_apply_btn)

	_done_btn = _make_button("Done", ACCENT)
	_done_btn.pressed.connect(_on_done_pressed)
	_action_row.add_child(_done_btn)


func _make_button(text: String, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, BTN_MIN_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	normal.border_width_bottom = 2
	normal.border_color = BTN_BORDER
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.08)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn


func _relayout() -> void:
	var vp := get_viewport_rect().size
	var bar_width := minf(vp.x - PAD * 2.0, 720.0)
	_bar.custom_minimum_size = Vector2(bar_width, BAR_HEIGHT + HINT_HEIGHT)
	var bar_height := _bar.custom_minimum_size.y
	_bar.position = Vector2((vp.x - bar_width) * 0.5, vp.y - bar_height - PAD)
	_bar.size = Vector2(bar_width, bar_height)

func _update_action_buttons() -> void:
	var has_selection := _edit_mode != null and _edit_mode.get_selected() != null
	_rotate_btn.disabled = not has_selection
	_cancel_btn.disabled = not has_selection
	_apply_btn.disabled = not has_selection


func _on_rotate_pressed() -> void:
	if _edit_mode:
		_edit_mode.rotate_selected()


func _on_cancel_pressed() -> void:
	if _edit_mode:
		_edit_mode.cancel_selected()


func _on_apply_pressed() -> void:
	if _edit_mode:
		_edit_mode.apply_selected()


func _on_done_pressed() -> void:
	if _edit_mode:
		_edit_mode.exit_mode()


func _on_mode_changed(active: bool) -> void:
	if active:
		on_mode_entered()
	else:
		on_mode_exited()


func _set_hud_enter_visible(visible: bool) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_edit_layout_visible"):
		hud.set_edit_layout_visible(visible)
