extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/worker_cleaning_test.gd

const GarbageDropManagerScript = preload("res://scripts/gameplay/garbage_drop_manager.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const QueuedActionScript = preload("res://scripts/gameplay/queued_action.gd")
const WorkerAutomationQueueScript = preload("res://scripts/gameplay/worker_automation_queue.gd")
const WorkerCleaningPlannerScript = preload("res://scripts/gameplay/worker_cleaning_planner.gd")
const WorkerTaskConfigScript = preload("res://scripts/gameplay/worker_task_config.gd")
const WorkerTaskManagerScript = preload("res://scripts/gameplay/worker_task_manager.gd")
const WORKER_SCENE := preload("res://scenes/worker/worker.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("planner finds nearest garbage", await _test_planner_finds_garbage())
	failed += _assert("planner returns null when floor is clean", await _test_planner_no_garbage())
	failed += _assert("disabled cleaning skips automation", await _test_disabled_cleaning_skips())
	failed += _assert("enabled cleaning cleans garbage", await _test_enabled_cleaning_cleans())
	failed += _assert("executor removes garbage", await _test_executor_cleans_garbage())
	failed += _assert("cleaning takes priority over storage", await _test_cleaning_priority_over_storage())
	failed += _assert("manual clean still works", _test_manual_clean_still_works())

	if failed == 0:
		print("worker_cleaning_test: ALL PASSED")
		quit(0)
	else:
		push_error("worker_cleaning_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _clear_scene() -> void:
	var manager := root.get_node_or_null("WorkerTaskManager")
	if manager != null and manager.has_method("reset_for_new_game"):
		manager.reset_for_new_game()
	var garbage_mgr := root.get_node_or_null("GarbageDropManager")
	if garbage_mgr != null and garbage_mgr.has_method("clear_all_garbage"):
		garbage_mgr.clear_all_garbage()
	for child in root.get_children():
		if child.name in ["GridService", "WorkerTaskManager", "GarbageDropManager"]:
			continue
		child.free()
	await process_frame


func _ensure_autoloads() -> void:
	if root.get_node_or_null("GridService") == null:
		var grid: WarehouseGrid = GridScript.new()
		grid.name = "GridService"
		root.add_child(grid)
	if root.get_node_or_null("GarbageDropManager") == null:
		var garbage: Node = GarbageDropManagerScript.new()
		garbage.name = "GarbageDropManager"
		root.add_child(garbage)
	if root.get_node_or_null("WorkerTaskManager") == null:
		var tasks: Node = WorkerTaskManagerScript.new()
		tasks.name = "WorkerTaskManager"
		root.add_child(tasks)
	var manager := root.get_node("WorkerTaskManager")
	manager.set_process(false)


func _make_worker() -> Worker:
	var worker: Worker = WORKER_SCENE.instantiate()
	worker.apply_roster_profile({
		"worker_id": "helper_alex",
		"display_name": "Alex",
		"is_manager": false,
	})
	root.add_child(worker)
	await process_frame
	return worker


func _spawn_garbage(position: Vector3):
	return root.get_node("GarbageDropManager").spawn_garbage_at(position)


func _test_planner_finds_garbage() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	worker.global_position = Vector3(10.0, 0.0, 10.0)
	var near = _spawn_garbage(Vector3(10.5, 0.0, 10.2))
	_spawn_garbage(Vector3(14.0, 0.0, 14.0))
	await process_frame
	var action := WorkerCleaningPlannerScript.plan_next(worker, self, [])
	return (
		action != null
		and action.type == QueuedActionScript.Type.CLEAN_GARBAGE
		and action.target == near
	)


func _test_planner_no_garbage() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	return WorkerCleaningPlannerScript.plan_next(worker, self, []) == null


func _test_disabled_cleaning_skips() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	_spawn_garbage(Vector3(10.0, 0.0, 10.0))
	var manager: Node = root.get_node("WorkerTaskManager")
	manager.call("_tick_workers")
	var queue = manager.get_queue_for_worker(worker)
	return queue != null and not bool(queue.has_pending())


func _test_enabled_cleaning_cleans() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_CLEANING, true)
	var garbage = _spawn_garbage(Vector3(10.0, 0.0, 10.0))
	var manager: Node = root.get_node("WorkerTaskManager")
	manager.call("_tick_workers")
	return await _await_garbage_removed(garbage)


func _test_executor_cleans_garbage() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	var garbage = _spawn_garbage(Vector3(10.0, 0.0, 10.0))
	await process_frame
	var action := QueuedActionScript.make_clean_garbage(garbage)
	var queue = WorkerAutomationQueueScript.new()
	worker.add_child(queue)
	queue.bind_worker(worker)
	if not queue.enqueue(action):
		return false
	return await _await_garbage_removed(garbage)


func _test_cleaning_priority_over_storage() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_CLEANING, true)
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE, true)
	_spawn_garbage(Vector3(10.0, 0.0, 10.0))
	var DeliveryBoxScript = preload("res://scripts/gameplay/delivery_box.gd")
	var box: DeliveryBox = DeliveryBoxScript.new()
	root.add_child(box)
	box.setup("mouse", 6, Vector3(1.0, 0.0, 1.0), 0.0)
	await process_frame
	var manager: Node = root.get_node("WorkerTaskManager")
	var action: QueuedAction = manager.call("_plan_next_action", worker, self, [])
	return action != null and action.type == QueuedActionScript.Type.CLEAN_GARBAGE


func _await_garbage_removed(garbage) -> bool:
	for _i in range(60):
		if not is_instance_valid(garbage) or garbage.is_queued_for_deletion():
			return true
		for node in get_nodes_in_group("workers"):
			if node is Worker and node.is_moving():
				node.call("_finish_walk")
		await process_frame
	return false


func _test_manual_clean_still_works() -> bool:
	var garbage = _spawn_garbage(Vector3(12.0, 0.0, 12.0))
	garbage.clean()
	return not is_instance_valid(garbage) or garbage.is_queued_for_deletion()
