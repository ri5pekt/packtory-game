extends SceneTree

## Multi-day economy simulation + balance checks.
## Run with:
## godot --headless --path . --script res://scripts/test/economy_balance_test.gd

const CustomerTrafficConfigScript = preload("res://scripts/gameplay/customer_traffic_config.gd")
const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")
const EconomyManagerScript = preload("res://scripts/gameplay/economy_manager.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")
const OnlineOrderCatalogScript = preload("res://scripts/gameplay/online_order_catalog.gd")
const OutboundDispatchConfigScript = preload("res://scripts/gameplay/outbound_dispatch_config.gd")
const ProductReorderConfigScript = preload("res://scripts/gameplay/product_reorder_config.gd")
const WorkerHireConfigScript = preload("res://scripts/gameplay/worker_hire_config.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_ensure_economy()
	var failed := 0
	var report := _simulate_three_days()
	print(report)
	failed += _assert("in-person margin positive", EconomyConfigScript.IN_PERSON_ORDER_REWARD > 0)
	failed += _assert("online single-package margin non-negative",
		EconomyConfigScript.ONLINE_ORDER_REWARD >= OutboundDispatchConfigScript.dispatch_fee()
	)
	failed += _assert("starting balance covers first van dispatch",
		EconomyConfigScript.STARTING_COINS >= OutboundDispatchConfigScript.dispatch_fee()
	)
	failed += _assert("three-day sim ends solvent", _parse_solvency(report))
	failed += _assert("fulfilled online orders are hidden", _test_fulfilled_filter())
	if failed == 0:
		print("economy_balance_test: ALL PASSED")
		quit(0)
	else:
		push_error("economy_balance_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_economy() -> void:
	if root.get_node_or_null("EconomyManager") != null:
		return
	var economy: Node = EconomyManagerScript.new()
	economy.name = "EconomyManager"
	root.add_child(economy)


func _simulate_three_days() -> String:
	var open_minutes := GameTimeConfigScript.STORE_CLOSE_MINUTES - GameTimeConfigScript.STORE_OPEN_MINUTES
	var lines: PackedStringArray = []
	lines.append("=== Economy Balance Simulation (3 days) ===")
	lines.append("")
	lines.append("Assumptions:")
	lines.append("  Store hours: %d game min/day (~%.1f real min at 1 min/sec)" % [
		open_minutes, float(open_minutes) / 60.0
	])
	lines.append("  Avg in-person orders/day: conservative 18, busy 35")
	lines.append("  Online mock orders: %d total (one-time each after fix)" % OnlineOrderCatalogScript.MOCK_ORDERS.size())
	lines.append("  Opening stock: 24 units (free); reorder fee: $%d" % ProductReorderConfigScript.logistics_fee())
	lines.append("")
	var coins := EconomyConfigScript.STARTING_COINS
	var total_in_person := 0
	var total_online := 0
	var total_dispatch_fees := 0
	var total_salaries := 0
	var total_reorders := 0
	for day in range(1, 4):
		var in_person_orders := 18 + (day - 1) * 4
		var online_orders := mini(OnlineOrderCatalogScript.MOCK_ORDERS.size(), day)
		var in_person_revenue := in_person_orders * EconomyConfigScript.IN_PERSON_ORDER_REWARD
		var online_revenue := online_orders * EconomyConfigScript.ONLINE_ORDER_REWARD
		var dispatch_fees := online_orders * OutboundDispatchConfigScript.dispatch_fee()
		var salary := WorkerHireConfigScript.get_daily_salary("helper_alex") if day >= 2 else 0
		var reorder_spend := ProductReorderConfigScript.logistics_fee() if day >= 2 else 0
		coins += in_person_revenue + online_revenue
		coins -= dispatch_fees + salary + reorder_spend
		total_in_person += in_person_orders
		total_online += online_orders
		total_dispatch_fees += dispatch_fees
		total_salaries += salary
		total_reorders += 1 if reorder_spend > 0 else 0
		lines.append(
			"Day %d: in-person %d ($%d), online %d ($%d), dispatch -$%d, salary -$%d, reorder -$%d → balance $%d" % [
				day,
				in_person_orders,
				in_person_revenue,
				online_orders,
				online_revenue,
				dispatch_fees,
				salary,
				reorder_spend,
				coins,
			]
		)
	lines.append("")
	lines.append("Totals: %d in-person, %d online, dispatch fees $%d, salaries $%d" % [
		total_in_person, total_online, total_dispatch_fees, total_salaries
	])
	lines.append("Ending balance: $%d" % coins)
	lines.append("SOLVENT=%s" % str(coins >= 0))
	var spawn_mid := CustomerTrafficConfigScript.spawn_delay_range(780.0)
	lines.append("Afternoon spawn cadence: %.0f–%.0f game min" % [spawn_mid.x, spawn_mid.y])
	return "\n".join(lines)


func _parse_solvency(report: String) -> bool:
	return report.contains("SOLVENT=true")


func _test_fulfilled_filter() -> bool:
	var queue: Node = CustomerQueueScript.new()
	queue.name = "BalanceQueue"
	root.add_child(queue)
	queue.notify_online_package_shipped({"online_order_number": 1001})
	var available: Array = OnlineOrderCatalogScript.get_available_orders(queue.get_fulfilled_online_orders())
	queue.queue_free()
	for order in available:
		if int(order.get("order_number", 0)) == 1001:
			return false
	return available.size() == OnlineOrderCatalogScript.MOCK_ORDERS.size() - 1
