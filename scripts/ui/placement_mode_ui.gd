extends Control

## Controls for placing boxed warehouse equipment from inventory.

const BAR_HEIGHT := 72.0
const BTN_MIN_HEIGHT := 52.0
const BTN_GAP := 10.0
const PAD := 12.0
const HINT_HEIGHT := 28.0

const BTN_BG := Color(0.14, 0.17, 0.24, 0.94)
const ACCENT := Color(0.26, 0.62, 0.92)
const APPLY_BG := Color(0.18, 0.55, 0.34, 0.95)
const CANCEL_BG := Color(0.55, 0.22, 0.20, 0.95)
const TEXT_COLOR := Color(1.0, 1.0, 1.0)
const DIM_TEXT := Color(0.78, 0.83, 0.90)

var _placement_mode: Node
var _bar: PanelContainer
var _hint: Label
var _rotate_btn: Button
var _cancel_btn: Button
var _apply_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_relayout()
	get_viewport().size_changed.connect(_relayout)
	visible = false


func bind_placement_mode(placement_mode: Node) -> void:
	_placement_mode = placement_mode
	if not _placement_mode.mode_changed.is_connected(_on_mode_changed):
		_placement_mode.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(_placement_mode.is_active())


func consumes_tap(screen_position: Vector2) -> bool:
	if not visible or _bar == null:
		return false
	return _bar.get_global_rect().has_point(screen_position)


func on_mode_entered(box_data: Dictionary) -> void:
	var label := String(box_data.get("label", "Equipment"))
	_hint.text = "Placing %s — tap floor tiles, then Apply." % label
	visible = true


func on_mode_exited() -> void:
	_hint.text = ""
	visible = false


func _build() -> void:
	_bar = PanelContainer.new()
	_bar.name = "PlacementBar"
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
	_hint.add_theme_color_override("font_color", DIM_TEXT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", BTN_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	_rotate_btn = _make_button("Rotate", BTN_BG)
	_rotate_btn.pressed.connect(_on_rotate_pressed)
	row.add_child(_rotate_btn)

	_cancel_btn = _make_button("Cancel", CANCEL_BG)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	row.add_child(_cancel_btn)

	_apply_btn = _make_button("Place", APPLY_BG)
	_apply_btn.pressed.connect(_on_apply_pressed)
	row.add_child(_apply_btn)


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
	btn.add_theme_stylebox_override("normal", normal)
	return btn


func _relayout() -> void:
	var vp := get_viewport_rect().size
	var bar_width := minf(vp.x - PAD * 2.0, 720.0)
	_bar.custom_minimum_size = Vector2(bar_width, BAR_HEIGHT + HINT_HEIGHT)
	var bar_height := _bar.custom_minimum_size.y
	_bar.position = Vector2((vp.x - bar_width) * 0.5, vp.y - bar_height - PAD)
	_bar.size = Vector2(bar_width, bar_height)


func _on_rotate_pressed() -> void:
	if _placement_mode:
		_placement_mode.rotate_preview()


func _on_cancel_pressed() -> void:
	if _placement_mode:
		_placement_mode.cancel_placement()


func _on_apply_pressed() -> void:
	if _placement_mode:
		_placement_mode.apply_placement()


func _on_mode_changed(active: bool) -> void:
	visible = active
	if not active:
		on_mode_exited()
