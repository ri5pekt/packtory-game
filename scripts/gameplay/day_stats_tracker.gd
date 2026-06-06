extends Node

## Per-day counters for the end-of-day summary screen.

const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")

var _in_person_orders := 0
var _online_orders := 0
var _total_earnings := 0
var _delivery_expenses := 0
var _reputation_start := 0
var _tracking := false


func _ready() -> void:
	add_to_group("day_stats_tracker")
	call_deferred("_bind_sources")


func reset_for_new_game() -> void:
	_reset_counters()
	_tracking = false
	_reputation_start = _read_reputation()


func begin_day_tracking() -> void:
	_reset_counters()
	_reputation_start = _read_reputation()
	_tracking = true


func is_tracking() -> bool:
	return _tracking


func get_in_person_orders() -> int:
	return _in_person_orders


func get_online_orders() -> int:
	return _online_orders


func get_total_earnings() -> int:
	return _total_earnings


func get_delivery_expenses() -> int:
	return _delivery_expenses


func export_save_state() -> Dictionary:
	return {
		"tracking": _tracking,
		"in_person_orders": _in_person_orders,
		"online_orders": _online_orders,
		"total_earnings": _total_earnings,
		"delivery_expenses": _delivery_expenses,
		"reputation_start": _reputation_start,
	}


func apply_save_state(data: Dictionary) -> void:
	_in_person_orders = int(data.get("in_person_orders", 0))
	_online_orders = int(data.get("online_orders", 0))
	_total_earnings = int(data.get("total_earnings", 0))
	_delivery_expenses = int(data.get("delivery_expenses", 0))
	_reputation_start = int(data.get("reputation_start", _read_reputation()))
	_tracking = bool(data.get("tracking", false))


func build_summary(payroll: Dictionary) -> Dictionary:
	var expenses: Array = payroll.get("expenses", [])
	var salary_total := int(payroll.get("total_salary", 0))
	var delivery_total := maxi(
		_delivery_expenses,
		_sum_expenses_by_category(expenses, _get_delivery_category())
	)
	var reputation_end := _read_reputation()
	var earnings := _total_earnings
	var net_profit := earnings - delivery_total - salary_total
	var summary := payroll.duplicate(true)
	summary.merge({
		"in_person_orders": _in_person_orders,
		"online_orders": _online_orders,
		"total_earnings": earnings,
		"delivery_expenses": delivery_total,
		"worker_salaries": salary_total,
		"net_profit": net_profit,
		"reputation_start": _reputation_start,
		"reputation_end": reputation_end,
		"reputation_delta": reputation_end - _reputation_start,
	})
	return summary


func _reset_counters() -> void:
	_in_person_orders = 0
	_online_orders = 0
	_total_earnings = 0
	_delivery_expenses = 0


func _bind_sources() -> void:
	var session := _get_session()
	if session and session.has_signal("day_started"):
		if not session.day_started.is_connected(_on_day_started):
			session.day_started.connect(_on_day_started)
	if session and session.is_gameplay_active():
		begin_day_tracking()
	_bind_customer_queue()
	_bind_economy()


func _on_day_started() -> void:
	begin_day_tracking()


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


func _on_node_added(node: Node) -> void:
	if node.is_in_group("customer_queue"):
		call_deferred("_connect_queue", node)


func _connect_queue(queue: Node) -> void:
	if not queue.has_signal("order_fulfilled"):
		return
	if queue.order_fulfilled.is_connected(_on_order_fulfilled):
		return
	queue.order_fulfilled.connect(_on_order_fulfilled)


func _bind_economy() -> void:
	var economy := _get_economy()
	if economy == null:
		return
	if economy.has_signal("expense_recorded"):
		if not economy.expense_recorded.is_connected(_on_expense_recorded):
			economy.expense_recorded.connect(_on_expense_recorded)


func _on_order_fulfilled(meta: Dictionary) -> void:
	if not _tracking:
		return
	var source := String(meta.get("source", CustomerQueueScript.SOURCE_IN_PERSON))
	var reward := EconomyConfigScript.reward_for_fulfillment(source)
	if source == CustomerQueueScript.SOURCE_ONLINE:
		_online_orders += 1
	else:
		_in_person_orders += 1
	_total_earnings += reward


func _on_expense_recorded(entry: Dictionary) -> void:
	if not _tracking:
		return
	if String(entry.get("category", "")) != _get_delivery_category():
		return
	_delivery_expenses += int(entry.get("amount", 0))


func _sum_expenses_by_category(expenses: Array, category: String) -> int:
	var total := 0
	for entry in expenses:
		if not entry is Dictionary:
			continue
		if String(entry.get("category", "")) != category:
			continue
		total += int(entry.get("amount", 0))
	return total


func _get_delivery_category() -> String:
	var economy := _get_economy()
	if economy and economy.has_method("get_expense_category_delivery"):
		return economy.get_expense_category_delivery()
	return "delivery"


func _read_reputation() -> int:
	var reputation := _get_reputation()
	if reputation and reputation.has_method("get_reputation"):
		return int(reputation.get_reputation())
	return 0


func _get_session() -> Node:
	return get_node_or_null("/root/GameSession")


func _get_economy() -> Node:
	return get_node_or_null("/root/EconomyManager")


func _get_reputation() -> Node:
	return get_node_or_null("/root/ReputationManager")
