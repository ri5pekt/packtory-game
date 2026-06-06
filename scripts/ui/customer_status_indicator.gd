class_name CustomerStatusIndicator
extends Node3D

## Small billboard bubble above a customer showing a queue status icon.

const CustomerStatusScript = preload("res://scripts/gameplay/customer_status.gd")

const HEAD_OFFSET_Y := 1.42
const BOB_AMPLITUDE := 0.07
const BOB_SPEED := 2.2
const BUBBLE_VISUAL_SCALE := 1.05

var _bubble: SpeechBubble3D
var _status: int = CustomerStatusScript.Kind.NONE
var _displayed_order: Dictionary = {}
var _bob_time := 0.0


func _ready() -> void:
	position = Vector3(0.0, HEAD_OFFSET_Y, 0.0)
	_ensure_bubble()
	clear()


func set_status(kind: int) -> void:
	_status = kind
	_displayed_order = {}
	_ensure_bubble()
	_bubble.set_visual_scale(BUBBLE_VISUAL_SCALE)
	if not CustomerStatusScript.is_visible(kind):
		_bubble.visible = false
		return
	_bubble.set_content(CustomerStatusScript.icon_for(kind))
	_bubble.visible = true


func set_order_content(order: Dictionary) -> void:
	_status = CustomerStatusScript.Kind.NONE
	_displayed_order = order.duplicate(true)
	_ensure_bubble()
	if _displayed_order.is_empty():
		_bubble.visible = false
		return
	_bubble.set_visual_scale(BUBBLE_VISUAL_SCALE)
	_bubble.set_order_content(_displayed_order)
	_bubble.visible = true


func clear() -> void:
	set_status(CustomerStatusScript.Kind.NONE)


func get_status() -> int:
	return _status


func is_shown() -> bool:
	return _bubble != null and _bubble.visible


func is_showing_order() -> bool:
	return _bubble != null and _bubble.is_showing_order_content()


func get_displayed_order() -> Dictionary:
	return _displayed_order.duplicate(true)


func _process(delta: float) -> void:
	if not is_shown():
		return
	_bob_time += delta
	position.y = HEAD_OFFSET_Y + sin(_bob_time * BOB_SPEED) * BOB_AMPLITUDE


func _ensure_bubble() -> void:
	if _bubble != null:
		return
	_bubble = SpeechBubble3D.new()
	_bubble.name = "StatusBubble"
	_bubble.set_visual_scale(BUBBLE_VISUAL_SCALE)
	add_child(_bubble)
