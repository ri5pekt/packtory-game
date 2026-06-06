extends Control

## Compact reputation meter for the top HUD row.

const ReputationConfigScript = preload("res://scripts/gameplay/reputation_config.gd")

const TRACK_COLOR := Color(0.12, 0.14, 0.18, 0.95)
const FILL_COLOR := Color(0.38, 0.68, 0.52, 1.0)
const BORDER_COLOR := Color(0.22, 0.25, 0.30, 1.0)
const DEBUG_TICK_COLOR := Color(0.95, 0.88, 0.35, 0.85)

var _value := ReputationConfigScript.STARTING_REPUTATION
var _ratio := 1.0
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


func set_reputation(value: int, max_value: int = -1) -> void:
	_ensure_built()
	var max_rep := max_value if max_value > 0 else ReputationConfigScript.MAX_REPUTATION
	_value = clampi(value, ReputationConfigScript.MIN_REPUTATION, max_rep)
	_ratio = ReputationConfigScript.ratio_for_value(_value)
	_apply_fill()
	queue_redraw()


func set_ratio(ratio: float, value: int = -1) -> void:
	_ensure_built()
	_ratio = clampf(ratio, 0.0, 1.0)
	if value >= 0:
		_value = ReputationConfigScript.clamp_reputation(value)
	_apply_fill()
	queue_redraw()


func get_ratio() -> float:
	return _ratio


func get_reputation() -> int:
	return _value


func _apply_fill() -> void:
	if _fill == null or _track == null:
		return
	var width := maxf(0.0, _track.size.x * _ratio)
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
