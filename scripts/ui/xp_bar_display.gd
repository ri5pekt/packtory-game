extends Control

## Compact XP progress meter for the top HUD row.

const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")

const ANIM_SEC := 0.28
const LEVEL_UP_ANIM_SEC := 0.42
const TRACK_COLOR := Color(0.12, 0.14, 0.18, 0.95)
const FILL_COLOR := GameUIThemeScript.ACCENT
const BORDER_COLOR := Color(0.22, 0.25, 0.30, 1.0)
const DEBUG_TICK_COLOR := Color(0.95, 0.88, 0.35, 0.85)

var _progress := 0.0
var _target_progress := 0.0
var _progress_tween: Tween
var _pulse_tween: Tween
var _track: Panel
var _fill: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_built()
	_apply_fill()


func _ensure_built() -> void:
	if _track:
		return
	_track = Panel.new()
	_track.name = "Track"
	_track.set_anchors_preset(Control.PRESET_FULL_RECT)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = TRACK_COLOR
	track_style.border_color = BORDER_COLOR
	track_style.set_border_width_all(1)
	track_style.set_corner_radius_all(3)
	_track.add_theme_stylebox_override("panel", track_style)
	add_child(_track)

	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.color = FILL_COLOR
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_fill)


func set_state(_level: int, progress: float, animate: bool = true) -> void:
	_ensure_built()
	_target_progress = clampf(progress, 0.0, 1.0)
	if not animate:
		_progress = _target_progress
		_apply_fill()
		queue_redraw()
		return
	if _progress_tween:
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_method(_set_progress_value, _progress, _target_progress, ANIM_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func play_level_up_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2(1.08, 1.22), LEVEL_UP_ANIM_SEC * 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, LEVEL_UP_ANIM_SEC * 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func get_progress() -> float:
	return _progress


func get_target_progress() -> float:
	return _target_progress


func _set_progress_value(value: float) -> void:
	_progress = value
	_apply_fill()
	queue_redraw()


func _apply_fill() -> void:
	if _fill == null or _track == null:
		return
	var width := maxf(0.0, _track.size.x * _progress)
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(width, _track.size.y)


func _draw() -> void:
	if not OS.is_debug_build():
		return
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	for frac: float in [0.25, 0.5, 0.75]:
		var x: float = w * frac
		draw_line(Vector2(x, 0.0), Vector2(x, h), DEBUG_TICK_COLOR, 1.0, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_fill()
		queue_redraw()
