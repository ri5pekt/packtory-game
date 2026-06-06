extends Control

## Celebrates level gains — queues multiple level-ups when XP jumps several tiers at once.

signal dismissed

const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")

const PANEL_BG := Color(0.08, 0.10, 0.14, 0.98)
const ACCENT := GameUIThemeScript.ACCENT
const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := Color(0.62, 0.70, 0.80)
const BTN_MIN_HEIGHT := 52.0
const SHOW_SEC := 1.35

var _built := false
var _open := false
var _queue: Array[int] = []
var _showing := false
var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _panel_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
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


func enqueue_levels(from_level: int, to_level: int, _count: int) -> void:
	for level in range(from_level + 1, to_level + 1):
		if _should_show_generic_level_up(level):
			_queue.append(level)
	_try_show_next()


func _should_show_generic_level_up(level: int) -> bool:
	var unlocks := get_node_or_null("/root/UnlockManager")
	if unlocks and unlocks.has_method("has_generic_level_up"):
		return unlocks.has_generic_level_up(level)
	return true


func get_pending_count() -> int:
	return _queue.size()


func is_showing() -> bool:
	return _showing


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
	_panel.pivot_offset = Vector2.ZERO
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
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	_title_label = Label.new()
	_title_label.text = "Level Up!"
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", TEXT_COLOR)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", DIM_TEXT)
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_body_label)

	var ok_btn := Button.new()
	ok_btn.text = "Continue"
	ok_btn.custom_minimum_size = Vector2(0.0, BTN_MIN_HEIGHT)
	ok_btn.pressed.connect(_on_continue_pressed)
	_style_button(ok_btn)
	col.add_child(ok_btn)


func _try_show_next() -> void:
	if _showing or _queue.is_empty():
		return
	_showing = true
	_open = true
	visible = true
	_overlay.visible = true
	_panel.visible = true
	var level: int = _queue.pop_front()
	_body_label.text = "You reached Level %d!" % level
	_relayout()
	_play_open_animation()
	get_tree().create_timer(SHOW_SEC).timeout.connect(_on_auto_continue, CONNECT_ONE_SHOT)


func _play_open_animation() -> void:
	if _panel_tween:
		_panel_tween.kill()
	_panel.scale = Vector2(0.82, 0.82)
	_panel.modulate = Color(1, 1, 1, 0.0)
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(_panel, "scale", Vector2.ONE, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(_panel, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_continue_pressed() -> void:
	_close_current()


func _on_auto_continue() -> void:
	if _showing:
		_close_current()


func _close_current() -> void:
	if not _showing:
		return
	_showing = false
	_open = false
	visible = false
	_overlay.visible = false
	_panel.visible = false
	dismissed.emit()
	_try_show_next()


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
	_panel.custom_minimum_size = Vector2(mini(420.0, vp.x - 48.0), 0.0)
	_panel.position = Vector2(
		(vp.x - _panel.size.x) * 0.5,
		(vp.y - _panel.size.y) * 0.38
	)
	_panel.pivot_offset = _panel.size * 0.5
