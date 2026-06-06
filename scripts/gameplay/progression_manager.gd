extends Node

## Reusable XP/level progression — grants on fulfillment and persistence hooks for SaveManager.

signal xp_changed(total_xp: int, delta: int, progress: float)
signal level_changed(new_level: int, old_level: int)
signal levels_gained(from_level: int, to_level: int, count: int)

const ProgressionConfigScript = preload("res://scripts/gameplay/progression_config.gd")
const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")

var _total_xp := 0


func _ready() -> void:
	call_deferred("_bind_customer_queue")


func reset_for_new_game() -> void:
	_total_xp = ProgressionConfigScript.STARTING_TOTAL_XP
	_emit_state(0, false)


func get_total_xp() -> int:
	return _total_xp


func get_xp() -> int:
	return ProgressionConfigScript.xp_into_current_level(_total_xp)


func get_level() -> int:
	return ProgressionConfigScript.level_from_total_xp(_total_xp)


func get_progress() -> float:
	return ProgressionConfigScript.progress_ratio(_total_xp)


func set_total_xp(value: int) -> void:
	var old_level := get_level()
	_total_xp = maxi(0, value)
	_emit_after_change(old_level, 0, false)


func add_xp(amount: int, _reason: String = "") -> int:
	if amount <= 0:
		return 0
	var old_level := get_level()
	_total_xp += amount
	_emit_after_change(old_level, amount, true)
	return amount


func grant_fulfillment_xp(meta: Dictionary) -> int:
	var source := String(meta.get("source", CustomerQueueScript.SOURCE_IN_PERSON))
	var reward := ProgressionConfigScript.xp_reward_for_fulfillment(source)
	var granted := add_xp(reward, "order_fulfilled:%s" % source)
	if granted > 0:
		_notify_fulfillment_xp(granted, source)
	return granted


func _emit_state(delta: int, animate_ui: bool) -> void:
	var progress := get_progress()
	xp_changed.emit(_total_xp, delta, progress)
	if not animate_ui:
		return


func _emit_after_change(old_level: int, delta: int, _animate_ui: bool) -> void:
	var new_level := get_level()
	var progress := get_progress()
	xp_changed.emit(_total_xp, delta, progress)
	if new_level != old_level:
		level_changed.emit(new_level, old_level)
		levels_gained.emit(old_level, new_level, new_level - old_level)


func _bind_customer_queue() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for queue in tree.get_nodes_in_group("customer_queue"):
		_connect_queue(queue)
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


func register_customer_queue(queue: Node) -> void:
	_connect_queue(queue)


func is_customer_queue_connected(queue: Node) -> bool:
	if queue == null or not queue.has_signal("order_fulfilled"):
		return false
	return queue.order_fulfilled.is_connected(_on_order_fulfilled)


func _on_node_added(node: Node) -> void:
	if node.is_in_group("customer_queue"):
		call_deferred("_connect_queue", node)


func _connect_queue(queue: Node) -> void:
	if not queue.has_signal("order_fulfilled"):
		return
	if queue.order_fulfilled.is_connected(_on_order_fulfilled):
		return
	queue.order_fulfilled.connect(_on_order_fulfilled)


func _notify_fulfillment_xp(amount: int, source: String) -> void:
	var alerts := get_node_or_null("/root/AlertMessages")
	if alerts == null or not alerts.has_method("info"):
		return
	var label := "In-person order" if source == CustomerQueueScript.SOURCE_IN_PERSON else "Online order"
	alerts.info("+%d XP — %s fulfilled." % [amount, label])


func _on_order_fulfilled(meta: Dictionary) -> void:
	grant_fulfillment_xp(meta)
