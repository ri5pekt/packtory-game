extends Node

## Reusable coin economy — grants, spending, and persistence hooks for SaveManager.

signal coins_changed(new_balance: int, delta: int)
signal expense_recorded(expense: Dictionary)

const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")
const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")

const EXPENSE_CATEGORY_SALARY := "salary"
const EXPENSE_CATEGORY_DELIVERY := "delivery"

var _coins := 0
var _day_expenses: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_bind_customer_queue")


func reset_for_new_game() -> void:
	_coins = EconomyConfigScript.STARTING_COINS
	_day_expenses.clear()
	coins_changed.emit(_coins, 0)


func get_coins() -> int:
	return _coins


func set_coins(value: int) -> void:
	var next := maxi(0, value)
	var delta := next - _coins
	_coins = next
	if delta != 0:
		coins_changed.emit(_coins, delta)


func add_coins(amount: int, _reason: String = "") -> int:
	if amount <= 0:
		return 0
	_coins += amount
	coins_changed.emit(_coins, amount)
	return amount


func try_spend(amount: int, _reason: String = "") -> bool:
	if amount <= 0:
		return true
	if _coins < amount:
		return false
	_coins -= amount
	coins_changed.emit(_coins, -amount)
	return true


func get_expense_category_salary() -> String:
	return EXPENSE_CATEGORY_SALARY


func get_expense_category_delivery() -> String:
	return EXPENSE_CATEGORY_DELIVERY


func charge_expense(
	amount: int,
	reason: String,
	category: String,
	meta: Dictionary = {}
) -> Dictionary:
	var charge := maxi(0, amount)
	if charge <= 0:
		return {"charged": 0, "entry": {}}
	_coins -= charge
	coins_changed.emit(_coins, -charge)
	var entry := {
		"category": category,
		"amount": charge,
		"reason": reason,
		"meta": meta.duplicate(),
	}
	_day_expenses.append(entry)
	expense_recorded.emit(entry.duplicate())
	return {"charged": charge, "entry": entry.duplicate()}


func get_day_expenses() -> Array:
	return _day_expenses.duplicate(true)


func get_day_expense_total(category: String = "") -> int:
	var total := 0
	for entry in _day_expenses:
		if category != "" and String(entry.get("category", "")) != category:
			continue
		total += int(entry.get("amount", 0))
	return total


func get_salary_expense_total() -> int:
	return get_day_expense_total(EXPENSE_CATEGORY_SALARY)


func clear_day_expenses() -> void:
	_day_expenses.clear()


func restore_day_expenses(entries: Array) -> void:
	_day_expenses.clear()
	for entry in entries:
		if entry is Dictionary:
			_day_expenses.append(entry.duplicate())


func grant_fulfillment_reward(meta: Dictionary) -> int:
	var source := String(meta.get("source", CustomerQueueScript.SOURCE_IN_PERSON))
	var reward := EconomyConfigScript.reward_for_fulfillment(source)
	var granted := add_coins(reward, "order_fulfilled:%s" % source)
	if granted > 0:
		_notify_fulfillment_reward(granted, source)
	return granted


func register_customer_queue(queue: Node) -> void:
	_connect_queue(queue)


func is_customer_queue_connected(queue: Node) -> bool:
	if queue == null or not queue.has_signal("order_fulfilled"):
		return false
	return queue.order_fulfilled.is_connected(_on_order_fulfilled)


func _bind_customer_queue() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for queue in tree.get_nodes_in_group("customer_queue"):
		_connect_queue(queue)
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.is_in_group("customer_queue"):
		call_deferred("_connect_queue", node)


func _notify_fulfillment_reward(amount: int, source: String) -> void:
	var alerts := get_node_or_null("/root/AlertMessages")
	if alerts == null or not alerts.has_method("info"):
		return
	var label := "In-person order" if source == CustomerQueueScript.SOURCE_IN_PERSON else "Online order"
	alerts.info("+%d coins — %s fulfilled." % [amount, label])


func _connect_queue(queue: Node) -> void:
	if not queue.has_signal("order_fulfilled"):
		return
	if queue.order_fulfilled.is_connected(_on_order_fulfilled):
		return
	queue.order_fulfilled.connect(_on_order_fulfilled)


func _on_order_fulfilled(meta: Dictionary) -> void:
	grant_fulfillment_reward(meta)
