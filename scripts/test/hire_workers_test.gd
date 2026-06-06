extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/hire_workers_test.gd

const ComputerInterfaceUIScript = preload("res://scripts/ui/computer_interface_ui.gd")
const ComputerSectionsConfigScript = preload("res://scripts/gameplay/computer_sections_config.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")
const WorkerHireConfigScript = preload("res://scripts/gameplay/worker_hire_config.gd")

const ECONOMY_MANAGER_SCRIPT := "res://scripts/gameplay/economy_manager.gd"
const GRID_SERVICE_SCRIPT := "res://scripts/autoload/grid_service.gd"
const HIRE_WORKERS_SCREEN_SCRIPT := "res://scripts/ui/computer_hire_workers_screen.gd"
const SAVE_MANAGER_SCRIPT := "res://scripts/gameplay/save_manager.gd"
const WORKER_HIRE_MANAGER_SCRIPT := "res://scripts/gameplay/worker_hire_manager.gd"


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("hire section is implemented", _test_section_implemented())
	failed += _assert("catalog lists placeholder workers", _test_catalog_workers())
	failed += _assert("hire deducts coins", _test_hire_deducts_coins())
	failed += _assert("insufficient coins block hire", _test_insufficient_coins_blocked())
	failed += _assert("hired worker appears in warehouse", await _test_worker_appears())
	failed += _assert("hired worker has daily salary", await _test_worker_salary())
	failed += _assert("worker roster persists in save", await _test_worker_save_roundtrip())
	failed += _assert("computer navigates to hire workers", _test_computer_navigation())
	failed += _assert("cannot hire same worker twice", await _test_duplicate_hire_blocked())
	failed += _assert(
		"hire screen reports insufficient coins",
		_test_hire_screen_insufficient_feedback()
	)

	if failed == 0:
		print("hire_workers_test: ALL PASSED")
		quit(0)
	else:
		push_error("hire_workers_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_autoloads() -> void:
	if root.get_node_or_null("GridService") == null:
		var grid: WarehouseGrid = load(GRID_SERVICE_SCRIPT).new()
		grid.name = "GridService"
		root.add_child(grid)
	if root.get_node_or_null("EconomyManager") == null:
		var economy: Node = load(ECONOMY_MANAGER_SCRIPT).new()
		economy.name = "EconomyManager"
		root.add_child(economy)
	if root.get_node_or_null("WorkerHireManager") == null:
		var hire: Node = load(WORKER_HIRE_MANAGER_SCRIPT).new()
		hire.name = "WorkerHireManager"
		root.add_child(hire)
	if root.get_node_or_null("SaveManager") == null:
		var save: Node = load(SAVE_MANAGER_SCRIPT).new()
		save.name = "SaveManager"
		root.add_child(save)
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


func _hire_manager() -> Node:
	return root.get_node("WorkerHireManager")


func _clear_workers() -> void:
	for node in root.get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(node):
			node.free()


func _reset_state() -> void:
	_clear_workers()
	_economy().set_coins(200)


func _test_section_implemented() -> bool:
	return not ComputerSectionsConfigScript.is_placeholder(
		ComputerSectionsConfigScript.SECTION_HIRE_WORKERS
	)


func _test_catalog_workers() -> bool:
	var entries: Array = WorkerHireConfigScript.get_hireable_workers()
	if entries.is_empty():
		return false
	var first: Dictionary = entries[0]
	return (
		String(first.get("display_name", "")) != ""
		and int(first.get("daily_salary", 0)) == EconomyConfigScript.SALARY_PLACEHOLDER
		and String(first.get("specialization", "")) != ""
	)


func _test_hire_deducts_coins() -> bool:
	_reset_state()
	var before: int = _economy().get_coins()
	var cost: int = WorkerHireConfigScript.get_hire_cost("helper_alex")
	var result: Dictionary = _hire_manager().hire_worker("helper_alex")
	return bool(result.get("ok", false)) and _economy().get_coins() == before - cost


func _test_insufficient_coins_blocked() -> bool:
	_reset_state()
	_economy().set_coins(0)
	var result: Dictionary = _hire_manager().hire_worker("helper_alex")
	return (
		not bool(result.get("ok", false))
		and String(result.get("reason", "")) == "insufficient_coins"
		and _hire_manager().is_worker_hired("helper_alex") == false
	)


func _test_worker_appears() -> bool:
	_reset_state()
	var before_count := root.get_tree().get_nodes_in_group("workers").size()
	var result: Dictionary = _hire_manager().hire_worker("helper_alex")
	await process_frame
	await process_frame
	var after_count := root.get_tree().get_nodes_in_group("workers").size()
	return bool(result.get("ok", false)) and after_count == before_count + 1


func _test_worker_salary() -> bool:
	_reset_state()
	var result: Dictionary = _hire_manager().hire_worker("helper_jordan")
	if not bool(result.get("ok", false)):
		return false
	var worker: Node = result.get("worker", null)
	await process_frame
	return (
		worker != null
		and worker.has_method("get_daily_salary")
		and worker.get_daily_salary() == EconomyConfigScript.SALARY_PLACEHOLDER
		and worker.get_display_name() == "Jordan"
	)


func _test_worker_save_roundtrip() -> bool:
	_reset_state()
	var result: Dictionary = _hire_manager().hire_worker("helper_sam")
	if not bool(result.get("ok", false)):
		return false
	var worker: Node = result.get("worker", null)
	await process_frame
	if worker == null or not worker.has_method("export_save_state"):
		return false
	var exported: Dictionary = worker.export_save_state()
	return (
		String(exported.get("worker_id", "")) == "helper_sam"
		and String(exported.get("display_name", "")) == "Sam"
		and int(exported.get("daily_salary", -1)) == EconomyConfigScript.SALARY_PLACEHOLDER
		and String(exported.get("specialization", "")) == WorkerHireConfigScript.SPECIALIZATION_GENERAL
	)


func _test_computer_navigation() -> bool:
	var ui: Control = ComputerInterfaceUIScript.new()
	ui.set_size(Vector2(720.0, 520.0))
	root.add_child(ui)
	ui.open()
	ui.navigate_to(ComputerSectionsConfigScript.SECTION_HIRE_WORKERS)
	var screen: VBoxContainer = ui.get_hire_workers_screen()
	var ok: bool = (
		ui.get_active_screen() == ComputerSectionsConfigScript.SECTION_HIRE_WORKERS
		and screen != null
		and screen.has_method("get_catalog_card_count")
		and screen.get_catalog_card_count() >= 1
	)
	ui.close()
	return ok


func _test_duplicate_hire_blocked() -> bool:
	_reset_state()
	var first: Dictionary = _hire_manager().hire_worker("helper_riley")
	if not bool(first.get("ok", false)):
		return false
	await process_frame
	var second: Dictionary = _hire_manager().hire_worker("helper_riley")
	return not bool(second.get("ok", false)) and String(second.get("reason", "")) == "already_hired"


func _test_hire_screen_insufficient_feedback() -> bool:
	_reset_state()
	_economy().set_coins(0)
	var screen: VBoxContainer = load(HIRE_WORKERS_SCREEN_SCRIPT).new()
	root.add_child(screen)
	screen.ensure_ready()
	screen._request_hire("helper_alex")
	var status: String = screen.get_status_text()
	var cost := WorkerHireConfigScript.get_hire_cost("helper_alex")
	return (
		status.contains("Not enough coins")
		and status.contains("need %d" % cost)
		and status.contains("you have 0")
	)
