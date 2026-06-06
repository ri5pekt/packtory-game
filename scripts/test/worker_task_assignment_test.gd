extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/worker_task_assignment_test.gd

const ContextMenuScene = preload("res://scenes/ui/context_menu.tscn")
const EconomyManagerScript = preload("res://scripts/gameplay/economy_manager.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const WorkerContextActionsScript = preload("res://scripts/gameplay/worker_context_actions.gd")
const WorkerHireManagerScript = preload("res://scripts/gameplay/worker_hire_manager.gd")
const WorkerTaskAssignmentFlowScript = preload(
	"res://scripts/shared/worker_task_assignment_flow.gd"
)
const WorkerTaskAssignmentUIScript = preload(
	"res://scripts/ui/worker_task_assignment_ui.gd"
)
const WorkerTaskConfigScript = preload("res://scripts/gameplay/worker_task_config.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("task categories are configured", _test_categories())
	failed += _assert("worker stores task toggles", _test_worker_task_state())
	failed += _assert("tasks persist in save export", _test_task_save_roundtrip())
	failed += _assert("worker has approach and face targets", _test_worker_approach_targets())
	failed += _assert("hired worker menu includes assign action", await _test_hired_worker_context_menu())
	failed += _assert("manager menu excludes assign action", await _test_manager_context_menu())
	failed += _assert("assignment flow waits for walk", _test_assignment_flow_walk_gate())
	failed += _assert("assignment screen opens after arrival", await _test_assignment_flow_opens_on_arrival())
	failed += _assert("UI toggles save to worker", await _test_ui_toggle_persistence())
	failed += _assert("enabled toggles are highlighted", await _test_toggle_highlighting())
	failed += _assert("manager walks before task screen opens", await _test_manager_walk_then_screen())

	if failed == 0:
		print("worker_task_assignment_test: ALL PASSED")
		quit(0)
	else:
		push_error("worker_task_assignment_test: %d FAILED" % failed)
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
	if root.get_node_or_null("WorkerHireManager") == null:
		var hire: Node = WorkerHireManagerScript.new()
		hire.name = "WorkerHireManager"
		root.add_child(hire)
	_ensure_spawn_parent()


func _ensure_spawn_parent() -> void:
	if root.get_node_or_null("WorkerSpawn") != null:
		return
	var spawn := Node3D.new()
	spawn.name = "WorkerSpawn"
	spawn.add_to_group("worker_spawn")
	root.add_child(spawn)


func _hire_manager() -> Node:
	return root.get_node("WorkerHireManager")


func _clear_workers() -> void:
	for node in root.get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(node):
			node.free()


func _spawn_manager_and_helper() -> void:
	_clear_workers()
	root.get_node("EconomyManager").set_coins(200)
	_hire_manager().spawn_default_manager()
	_hire_manager().hire_worker("helper_alex")
	await process_frame


func _find_hired_worker() -> Worker:
	for node in root.get_tree().get_nodes_in_group("workers"):
		if node is Worker and not node.is_manager():
			return node
	return null


func _find_manager() -> Worker:
	for node in root.get_tree().get_nodes_in_group("workers"):
		if node is Worker and node.is_manager():
			return node
	return null


func _test_categories() -> bool:
	var categories: Array = WorkerTaskConfigScript.categories()
	return (
		categories.size() == 3
		and WorkerTaskConfigScript.is_valid_category(WorkerTaskConfigScript.CATEGORY_STORAGE)
		and WorkerTaskConfigScript.is_valid_category(WorkerTaskConfigScript.CATEGORY_FULFILLMENT)
		and WorkerTaskConfigScript.is_valid_category(WorkerTaskConfigScript.CATEGORY_CLEANING)
	)


func _test_worker_task_state() -> bool:
	var worker := Worker.new()
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE, true)
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_FULFILLMENT, true)
	var tasks: Dictionary = worker.get_task_assignments()
	return (
		bool(tasks.get(WorkerTaskConfigScript.CATEGORY_STORAGE, false))
		and bool(tasks.get(WorkerTaskConfigScript.CATEGORY_FULFILLMENT, false))
		and not bool(tasks.get(WorkerTaskConfigScript.CATEGORY_CLEANING, false))
	)


func _test_task_save_roundtrip() -> bool:
	var worker := Worker.new()
	worker.apply_roster_profile({
		"worker_id": "helper_alex",
		"display_name": "Alex",
		"is_manager": false,
	})
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_CLEANING, true)
	var exported: Dictionary = worker.export_save_state()
	var restored := Worker.new()
	restored.apply_save_state(exported)
	return restored.is_task_enabled(WorkerTaskConfigScript.CATEGORY_CLEANING)


func _test_worker_approach_targets() -> bool:
	var worker := Worker.new()
	root.add_child(worker)
	worker.global_position = Vector3(4.0, 0.0, 6.0)
	var base_pos := worker.global_position
	var approach: Vector3 = worker.get_approach_position()
	var face: Vector3 = worker.get_face_target()
	worker.free()
	return approach.distance_to(base_pos) > 0.2 and face.y > base_pos.y


func _test_hired_worker_context_menu() -> bool:
	await _spawn_manager_and_helper()
	var worker := _find_hired_worker()
	var actions: Array = WorkerContextActionsScript.actions_for_worker(worker)
	var menu := _show_context_menu(actions)
	await process_frame
	var labels := _menu_action_labels(menu)
	return menu.visible and labels.has("Assign Worker Tasks") and labels.has("Select Worker")


func _test_manager_context_menu() -> bool:
	await _spawn_manager_and_helper()
	var manager := _find_manager()
	var actions: Array = WorkerContextActionsScript.actions_for_worker(manager)
	var menu := _show_context_menu(actions)
	await process_frame
	var labels := _menu_action_labels(menu)
	return menu.visible and not labels.has("Assign Worker Tasks") and labels.has("Select Worker")


func _test_assignment_flow_walk_gate() -> bool:
	var manager := _MockWorker.new()
	manager.is_manager_worker = true
	var target := _MockWorker.new()
	var ui := _make_task_ui()
	root.add_child(manager)
	root.add_child(target)
	var started := WorkerTaskAssignmentFlowScript.begin_assign(manager, target, ui)
	return started and not ui.is_open() and manager.is_moving()


func _test_assignment_flow_opens_on_arrival() -> bool:
	var manager := _MockWorker.new()
	manager.is_manager_worker = true
	var target := _MockWorker.new()
	var ui := _make_task_ui()
	root.add_child(manager)
	root.add_child(target)
	var result := {"opened": false}
	WorkerTaskAssignmentFlowScript.begin_assign(
		manager,
		target,
		ui,
		Callable(),
		func(success: bool) -> void:
			result.opened = success
	)
	manager.simulate_arrive()
	await process_frame
	return ui.is_open() and bool(result.opened) and manager.faced_target


func _test_ui_toggle_persistence() -> bool:
	var worker := Worker.new()
	worker.apply_roster_profile({
		"worker_id": "helper_jordan",
		"display_name": "Jordan",
		"is_manager": false,
	})
	var ui := _make_task_ui()
	ui.open_for_worker(worker)
	await process_frame
	var storage_btn: Button = ui.get_toggle_button(WorkerTaskConfigScript.CATEGORY_STORAGE)
	storage_btn.button_pressed = true
	storage_btn.toggled.emit(true)
	await process_frame
	var exported: Dictionary = worker.export_save_state()
	return (
		worker.is_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE)
		and bool(exported.get("tasks", {}).get(WorkerTaskConfigScript.CATEGORY_STORAGE, false))
	)


func _test_toggle_highlighting() -> bool:
	var worker := Worker.new()
	var ui := _make_task_ui()
	ui.open_for_worker(worker)
	await process_frame
	var storage_btn: Button = ui.get_toggle_button(WorkerTaskConfigScript.CATEGORY_STORAGE)
	var cleaning_btn: Button = ui.get_toggle_button(WorkerTaskConfigScript.CATEGORY_CLEANING)
	storage_btn.button_pressed = true
	storage_btn.toggled.emit(true)
	await process_frame
	return (
		ui.is_category_highlighted(WorkerTaskConfigScript.CATEGORY_STORAGE)
		and not ui.is_category_highlighted(WorkerTaskConfigScript.CATEGORY_CLEANING)
		and storage_btn.button_pressed
		and not cleaning_btn.button_pressed
	)


func _close_open_task_uis() -> void:
	for child in root.get_children():
		if child.has_method("is_open") and child.is_open():
			child.close()


func _test_manager_walk_then_screen() -> bool:
	_close_open_task_uis()
	await _spawn_manager_and_helper()
	var manager := _find_manager()
	var worker := _find_hired_worker()
	var grid: WarehouseGrid = root.get_node("GridService")
	var ui := _make_task_ui()
	if manager == null or worker == null:
		return false
	manager.global_position = grid.cell_to_world(Vector2i(8, 8))
	worker.global_position = grid.cell_to_world(Vector2i(14, 16))
	await process_frame
	if ui.is_open():
		return false
	if not WorkerTaskAssignmentFlowScript.begin_assign(manager, worker, ui):
		return false
	if manager.is_moving() and ui.is_open():
		return false
	if not ui.is_open():
		manager.global_position = worker.get_approach_position()
		manager.call("_finish_walk")
		await process_frame
	return ui.is_open() and ui.get_target_worker() == worker


func _make_task_ui() -> Control:
	var ui: Control = WorkerTaskAssignmentUIScript.new()
	ui.set_size(Vector2(720.0, 520.0))
	root.add_child(ui)
	return ui


func _show_context_menu(actions: Array) -> VBoxContainer:
	var menu: VBoxContainer = ContextMenuScene.instantiate()
	root.add_child(menu)
	menu.show_actions(Vector2(120.0, 140.0), actions)
	return menu


func _menu_action_labels(menu: Control) -> PackedStringArray:
	# The context menu adds button rows directly as its own children.
	var labels := PackedStringArray()
	var root: Node = menu.get_node_or_null("Actions")
	if root == null:
		root = menu
	_collect_button_labels(root, labels)
	return labels


func _collect_button_labels(node: Node, labels: PackedStringArray) -> void:
	for child in node.get_children():
		if child is Button:
			labels.append((child as Button).text)
		else:
			_collect_button_labels(child, labels)


class _MockWorker:
	extends Node3D

	var faced_target := false
	var is_manager_worker := false
	var _moving := false
	var _arrive_callback: Callable = Callable()

	func is_manager() -> bool:
		return is_manager_worker

	func is_packing() -> bool:
		return false

	func get_approach_position() -> Vector3:
		return global_position + Vector3(0.0, 0.0, 0.85)

	func get_face_target() -> Vector3:
		return global_position + Vector3(0.0, 0.75, 0.0)

	func walk_to_world(_world_position: Vector3, on_arrive: Callable = Callable()) -> void:
		_moving = true
		_arrive_callback = on_arrive

	func simulate_arrive() -> void:
		_moving = false
		if _arrive_callback.is_valid():
			_arrive_callback.call()

	func face_world(_target: Vector3) -> void:
		faced_target = true

	func is_moving() -> bool:
		return _moving
