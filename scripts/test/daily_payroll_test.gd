extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/daily_payroll_test.gd

const DayEndManagerScript = preload("res://scripts/gameplay/day_end_manager.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")
const EconomyManagerScript = preload("res://scripts/gameplay/economy_manager.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const PayrollServiceScript = preload("res://scripts/gameplay/payroll_service.gd")
const DayEndFlowScript = preload("res://scripts/gameplay/day_end_flow.gd")
const WorkerHireManagerScript = preload("res://scripts/gameplay/worker_hire_manager.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("manager has no payroll entry", _test_manager_excluded())
	failed += _assert("payroll totals hired salaries", await _test_payroll_total())
	failed += _assert("end day deducts salary coins", await _test_end_day_deducts())
	failed += _assert("salary expense is recorded", await _test_expense_recorded())
	failed += _assert("insufficient funds allow negative balance", await _test_negative_balance())
	failed += _assert("payroll only runs once per day", await _test_single_settlement_per_day())
	failed += _assert("store close triggers automatic payroll", await _test_store_close_trigger())

	if failed == 0:
		print("daily_payroll_test: ALL PASSED")
		quit(0)
	else:
		push_error("daily_payroll_test: %d FAILED" % failed)
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
	if root.get_node_or_null("WorkerHireManager") == null:
		var hire: Node = WorkerHireManagerScript.new()
		hire.name = "WorkerHireManager"
		root.add_child(hire)
	if root.get_node_or_null("DayEndManager") == null:
		var day_end: Node = DayEndManagerScript.new()
		day_end.name = "DayEndManager"
		root.add_child(day_end)
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


func _day_end() -> Node:
	return root.get_node("DayEndManager")


func _hire_manager() -> Node:
	return root.get_node("WorkerHireManager")


func _time() -> Node:
	return root.get_node("GameTimeManager")


func _reset_state() -> void:
	for node in root.get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(node):
			node.free()
	_economy().reset_for_new_game()
	_day_end().reset_for_new_game()
	_economy().set_coins(200)
	_time().set_time(1, 480)


func _test_manager_excluded() -> bool:
	_reset_state()
	_hire_manager().spawn_default_manager()
	var entries: Array = PayrollServiceScript.collect_payroll_entries(root)
	return entries.is_empty()


func _test_payroll_total() -> bool:
	_reset_state()
	_hire_manager().hire_worker("helper_alex")
	_hire_manager().hire_worker("helper_jordan")
	await process_frame
	var entries: Array = PayrollServiceScript.collect_payroll_entries(root)
	var total := PayrollServiceScript.total_payroll_amount(entries)
	var expected := EconomyConfigScript.SALARY_PLACEHOLDER * 2
	return entries.size() == 2 and total == expected


func _test_end_day_deducts() -> bool:
	_reset_state()
	_hire_manager().hire_worker("helper_alex")
	await process_frame
	var before: int = _economy().get_coins()
	var summary: Dictionary = _day_end().end_day(true)
	var salary: int = EconomyConfigScript.SALARY_PLACEHOLDER
	return (
		int(summary.get("total_salary", 0)) == salary
		and _economy().get_coins() == before - salary
	)


func _test_expense_recorded() -> bool:
	_reset_state()
	_hire_manager().hire_worker("helper_sam")
	await process_frame
	_day_end().end_day(true)
	var expenses: Array = _economy().get_day_expenses()
	if expenses.size() != 1:
		return false
	var entry: Dictionary = expenses[0]
	return (
		String(entry.get("category", "")) == _economy().get_expense_category_salary()
		and int(entry.get("amount", 0)) == EconomyConfigScript.SALARY_PLACEHOLDER
		and String(entry.get("meta", {}).get("worker_id", "")) == "helper_sam"
		and _economy().get_salary_expense_total() == EconomyConfigScript.SALARY_PLACEHOLDER
	)


func _test_negative_balance() -> bool:
	_reset_state()
	_hire_manager().hire_worker("helper_alex")
	_hire_manager().hire_worker("helper_jordan")
	await process_frame
	_economy().set_coins(10)
	var summary: Dictionary = _day_end().end_day(true)
	var owed := EconomyConfigScript.SALARY_PLACEHOLDER * 2
	return (
		bool(summary.get("went_negative", false))
		and _economy().get_coins() == 10 - owed
		and _economy().get_coins() < 0
	)


func _test_single_settlement_per_day() -> bool:
	_reset_state()
	_hire_manager().hire_worker("helper_riley")
	await process_frame
	var before: int = _economy().get_coins()
	_day_end().end_day(true)
	var after_first: int = _economy().get_coins()
	_day_end().end_day(false)
	return after_first == before - EconomyConfigScript.SALARY_PLACEHOLDER \
		and _economy().get_coins() == after_first


func _test_store_close_trigger() -> bool:
	_reset_state()
	_hire_manager().hire_worker("helper_alex")
	await process_frame
	_time().set_time(1, 1190)
	await process_frame
	_time().advance_by_game_minutes(15.0)
	await process_frame
	return (
		_day_end().is_payroll_settled_for_day(1)
		and _economy().get_salary_expense_total() == EconomyConfigScript.SALARY_PLACEHOLDER
	)
