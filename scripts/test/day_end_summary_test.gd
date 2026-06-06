extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/day_end_summary_test.gd

const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const DayEndFlowScript = preload("res://scripts/gameplay/day_end_flow.gd")
const DayEndManagerScript = preload("res://scripts/gameplay/day_end_manager.gd")
const DayEndSummaryUIScript = preload("res://scripts/ui/day_end_summary_ui.gd")
const DayStatsTrackerScript = preload("res://scripts/gameplay/day_stats_tracker.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")
const EconomyManagerScript = preload("res://scripts/gameplay/economy_manager.gd")
const GameSessionScript = preload("res://scripts/gameplay/game_session.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const ReputationManagerScript = preload("res://scripts/gameplay/reputation_manager.gd")
const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")
const WorkerHireManagerScript = preload("res://scripts/gameplay/worker_hire_manager.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("stats tracker counts fulfilled orders", await _test_order_counts())
	failed += _assert("summary includes earnings and delivery expenses", await _test_summary_totals())
	failed += _assert("end day flow deducts worker salaries", await _test_salary_deduction())
	failed += _assert("summary ui displays stat rows", await _test_summary_ui())
	failed += _assert("continue starts next day at morning", await _test_continue_new_day())
	failed += _assert("gameplay pauses while summary is open", await _test_pause_during_summary())
	failed += _assert("reputation delta appears in summary", await _test_reputation_delta())

	if failed == 0:
		print("day_end_summary_test: ALL PASSED")
		quit(0)
	else:
		push_error("day_end_summary_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_autoloads() -> void:
	if root.get_node_or_null("GridService") == null:
		var grid: WarehouseGrid = GridScript.new()
		grid.name = "GridService"
		root.add_child(grid)
	if root.get_node_or_null("EconomyManager") == null:
		var economy: Node = EconomyManagerScript.new()
		economy.name = "EconomyManager"
		root.add_child(economy)
	if root.get_node_or_null("GameTimeManager") == null:
		var time: Node = GameTimeManagerScript.new()
		time.name = "GameTimeManager"
		root.add_child(time)
	if root.get_node_or_null("SaveManager") == null:
		var save: Node = SaveManagerScript.new()
		save.name = "SaveManager"
		root.add_child(save)
	if root.get_node_or_null("GameSession") == null:
		var session: Node = GameSessionScript.new()
		session.name = "GameSession"
		root.add_child(session)
	if root.get_node_or_null("ReputationManager") == null:
		var reputation: Node = ReputationManagerScript.new()
		reputation.name = "ReputationManager"
		root.add_child(reputation)
	if root.get_node_or_null("WorkerHireManager") == null:
		var hire: Node = WorkerHireManagerScript.new()
		hire.name = "WorkerHireManager"
		root.add_child(hire)
	if root.get_node_or_null("DayEndManager") == null:
		var day_end: Node = DayEndManagerScript.new()
		day_end.name = "DayEndManager"
		root.add_child(day_end)
	if root.get_node_or_null("DayStatsTracker") == null:
		var tracker: Node = DayStatsTrackerScript.new()
		tracker.name = "DayStatsTracker"
		root.add_child(tracker)
	if root.get_node_or_null("DayEndFlow") == null:
		var flow: Node = DayEndFlowScript.new()
		flow.name = "DayEndFlow"
		root.add_child(flow)
	_ensure_spawn_parent()


func _ensure_spawn_parent() -> void:
	if root.get_node_or_null("WorkerSpawn") != null:
		return
	var spawn := Node3D.new()
	spawn.name = "WorkerSpawn"
	spawn.add_to_group("worker_spawn")
	root.add_child(spawn)


func _economy() -> Node:
	return root.get_node("EconomyManager")


func _time() -> Node:
	return root.get_node("GameTimeManager")


func _session() -> Node:
	return root.get_node("GameSession")


func _day_end() -> Node:
	return root.get_node("DayEndManager")


func _flow() -> Node:
	return root.get_node("DayEndFlow")


func _tracker() -> Node:
	return root.get_node("DayStatsTracker")


func _reputation() -> Node:
	return root.get_node("ReputationManager")


func _hire() -> Node:
	return root.get_node("WorkerHireManager")


var _test_queue: Node


func _reset_state() -> void:
	for node in root.get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(node):
			node.free()
	if _test_queue != null and is_instance_valid(_test_queue):
		_test_queue.queue_free()
		_test_queue = null
	_flow().reset_summary_state()
	_economy().reset_for_new_game()
	_day_end().reset_for_new_game()
	_reputation().reset_for_new_game()
	_tracker().reset_for_new_game()
	_session().reset_for_new_day()
	_session().acknowledge_day_start()
	_economy().set_coins(500)
	_time().set_time(1, 1080)
	_time().set_running(true)
	_tracker().begin_day_tracking()


func _ensure_customer_queue() -> Node:
	if _test_queue != null and is_instance_valid(_test_queue):
		return _test_queue
	_test_queue = CustomerQueueScript.new()
	_test_queue.name = "TestCustomerQueue"
	_test_queue.add_to_group("customer_queue")
	root.add_child(_test_queue)
	return _test_queue


func _simulate_order(source: String) -> void:
	var queue := _ensure_customer_queue()
	queue.order_fulfilled.emit({"source": source})


func _test_order_counts() -> bool:
	_reset_state()
	_ensure_customer_queue()
	await process_frame
	_simulate_order(CustomerQueueScript.SOURCE_IN_PERSON)
	_simulate_order(CustomerQueueScript.SOURCE_IN_PERSON)
	_simulate_order(CustomerQueueScript.SOURCE_ONLINE)
	await process_frame
	return (
		_tracker().get_in_person_orders() == 2
		and _tracker().get_online_orders() == 1
		and _tracker().get_total_earnings() == EconomyConfigScript.IN_PERSON_ORDER_REWARD * 2
			+ EconomyConfigScript.ONLINE_ORDER_REWARD
	)


func _test_summary_totals() -> bool:
	_reset_state()
	_ensure_customer_queue()
	await process_frame
	_simulate_order(CustomerQueueScript.SOURCE_IN_PERSON)
	_economy().charge_expense(
		EconomyConfigScript.OUTBOUND_DISPATCH_FEE,
		"outbound_dispatch",
		_economy().get_expense_category_delivery(),
		{}
	)
	await process_frame
	var payroll: Dictionary = _day_end().end_day(true)
	var summary: Dictionary = _tracker().build_summary(payroll)
	var expected_earnings := EconomyConfigScript.IN_PERSON_ORDER_REWARD
	var expected_delivery := EconomyConfigScript.OUTBOUND_DISPATCH_FEE
	return (
		int(summary.get("in_person_orders", 0)) == 1
		and int(summary.get("total_earnings", 0)) == expected_earnings
		and int(summary.get("delivery_expenses", 0)) == expected_delivery
	)


func _test_salary_deduction() -> bool:
	_reset_state()
	_hire().hire_worker("helper_alex")
	await process_frame
	var before: int = _economy().get_coins()
	var summary: Dictionary = _flow().request_end_day(true)
	var salary: int = EconomyConfigScript.SALARY_PLACEHOLDER
	return (
		int(summary.get("worker_salaries", 0)) == salary
		and _economy().get_coins() == before - salary
		and _day_end().is_payroll_settled_for_day(1)
	)


func _test_summary_ui() -> bool:
	_reset_state()
	_ensure_customer_queue()
	await process_frame
	_simulate_order(CustomerQueueScript.SOURCE_ONLINE)
	var ui: Control = DayEndSummaryUIScript.new()
	ui.set_size(Vector2(1280.0, 720.0))
	root.add_child(ui)
	await process_frame
	_flow().call("_bind_summary_ui")
	var summary: Dictionary = _flow().request_end_day(true)
	await process_frame
	var ok: bool = (
		ui.is_open()
		and ui.get_stat_text("Online orders") == "1"
		and ui.get_stat_text("Total earnings") == "$%d" % EconomyConfigScript.ONLINE_ORDER_REWARD
		and int(summary.get("online_orders", 0)) == 1
	)
	ui.queue_free()
	return ok


func _test_continue_new_day() -> bool:
	_reset_state()
	_hire().hire_worker("helper_alex")
	await process_frame
	_flow().request_end_day(true)
	await process_frame
	_flow().continue_to_next_day()
	await process_frame
	return (
		_time().get_day() == 2
		and _time().get_game_minutes() == GameTimeConfigScript.DAY_START_MINUTES
		and not _time().is_running()
		and not _session().is_gameplay_active()
		and not _day_end().is_payroll_settled_for_day(2)
		and _economy().get_day_expenses().is_empty()
	)


func _test_pause_during_summary() -> bool:
	_reset_state()
	_time().set_running(true)
	_flow().request_end_day(true)
	await process_frame
	return not _time().is_running() and _flow().is_summary_open()


func _test_reputation_delta() -> bool:
	_reset_state()
	_reputation().change_reputation(-5)
	await process_frame
	var summary: Dictionary = _tracker().build_summary({"total_salary": 0, "expenses": []})
	return int(summary.get("reputation_delta", 0)) == -5
