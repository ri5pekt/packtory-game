extends Control

## Circular XP readout — level number centered, progress ring fills around it.

const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")

const RING_WIDTH := 4.0
const ANIM_SEC := 0.28
const LEVEL_UP_ANIM_SEC := 0.42

const TRACK_COLOR := Color(0.10, 0.12, 0.16, 0.9)
const FILL_COLOR := GameUIThemeScript.ACCENT
const LEVEL_TEXT_COLOR := Color(1.0, 1.0, 1.0)
const DEBUG_TICK_COLOR := Color(0.95, 0.88, 0.35, 0.9)

var _level := 0
var _progress := 0.0
var _target_progress := 0.0
var _progress_tween: Tween
var _pulse_tween: Tween
var _level_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(40.0, 40.0)
	_ensure_label()
	queue_redraw()


func _ensure_label() -> void:
	if _level_label:
		return
	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_label.add_theme_font_size_override("font_size", 13)
	_level_label.add_theme_color_override("font_color", LEVEL_TEXT_COLOR)
	_level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_level_label.add_theme_constant_override("shadow_offset_x", 1)
	_level_label.add_theme_constant_override("shadow_offset_y", 1)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level_label)


func set_state(level: int, progress: float, animate: bool = true) -> void:
	_ensure_label()
	var level_changed := level != _level
	_level = maxi(0, level)
	_target_progress = clampf(progress, 0.0, 1.0)
	if _level_label:
		_level_label.text = str(_level)
	if not animate:
		_progress = _target_progress
		queue_redraw()
		return
	if _progress_tween:
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_method(_set_progress_value, _progress, _target_progress, ANIM_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if level_changed:
		play_level_up_pulse()


func play_level_up_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2(1.18, 1.18), LEVEL_UP_ANIM_SEC * 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, LEVEL_UP_ANIM_SEC * 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func get_level() -> int:
	return _level


func get_progress() -> float:
	return _progress


func get_target_progress() -> float:
	return _target_progress


func _set_progress_value(value: float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - RING_WIDTH * 0.5
	if radius <= 1.0:
		return
	draw_arc(center, radius, 0.0, TAU, 48, TRACK_COLOR, RING_WIDTH, true)
	if OS.is_debug_build():
		_draw_debug_ticks(center, radius)
	var start := -PI * 0.5
	if _progress > 0.0:
		var end := start + TAU * _progress
		draw_arc(center, radius, start, end, maxi(12, int(48.0 * _progress)), FILL_COLOR, RING_WIDTH, true)
	if OS.is_debug_build() and _progress > 0.0:
		var tip_angle := start + TAU * _progress
		var tip := center + Vector2(cos(tip_angle), sin(tip_angle)) * radius
		draw_circle(tip, 2.5, FILL_COLOR)


func _draw_debug_ticks(center: Vector2, radius: float) -> void:
	for frac: float in [0.25, 0.5, 0.75, 1.0]:
		var angle: float = -PI * 0.5 + TAU * frac
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius - RING_WIDTH)
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + RING_WIDTH * 0.5)
		draw_line(inner, outer, DEBUG_TICK_COLOR, 1.5, true)
