extends Node

signal pan_drag(delta: Vector2)
signal zoom(factor: float)
signal tap(screen_position: Vector2)
signal reset_view_requested

const DRAG_THRESHOLD_PX := 18.0

var _pointer_down := false
var _dragging := false
var _press_position := Vector2.ZERO
var _active_touch_index := -1
var _touches: Dictionary = {}
var _previous_pinch_distance := 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		reset_view_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMagnifyGesture:
		zoom.emit(event.factor)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom.emit(1.0 + 0.08)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom.emit(1.0 - 0.08)
		return

	if event.pressed:
		_pointer_down = true
		_dragging = false
		_press_position = event.position
	else:
		if _pointer_down and not _dragging:
			tap.emit(event.position)
		_pointer_down = false
		_dragging = false


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _pointer_down:
		return

	if not _dragging and event.position.distance_to(_press_position) >= DRAG_THRESHOLD_PX:
		_dragging = true

	if _dragging:
		pan_drag.emit(event.relative)
		get_viewport().set_input_as_handled()


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_active_touch_index = event.index
			_pointer_down = true
			_dragging = false
			_press_position = event.position
		elif _touches.size() == 2:
			_dragging = true
			_previous_pinch_distance = _get_pinch_distance()
	else:
		_touches.erase(event.index)
		if _touches.is_empty():
			if _pointer_down and not _dragging and _active_touch_index == event.index:
				tap.emit(event.position)
			_pointer_down = false
			_dragging = false
			_active_touch_index = -1
			_previous_pinch_distance = 0.0
		elif _touches.size() == 1:
			var remaining_index: int = _touches.keys()[0]
			_active_touch_index = remaining_index
			_press_position = _touches[remaining_index]
			_dragging = false
			_previous_pinch_distance = 0.0


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position

	if _touches.size() >= 2:
		var distance := _get_pinch_distance()
		if _previous_pinch_distance > 0.0:
			zoom.emit(distance / _previous_pinch_distance)
		_previous_pinch_distance = distance
		get_viewport().set_input_as_handled()
		return

	if event.index != _active_touch_index or not _pointer_down:
		return

	if not _dragging and event.position.distance_to(_press_position) >= DRAG_THRESHOLD_PX:
		_dragging = true

	if _dragging:
		pan_drag.emit(event.relative)
		get_viewport().set_input_as_handled()


func _get_pinch_distance() -> float:
	var keys := _touches.keys()
	if keys.size() < 2:
		return 0.0
	return _touches[keys[0]].distance_to(_touches[keys[1]])
