extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/storage_worker_test.gd

const DeliveryBoxScript = preload("res://scripts/gameplay/delivery_box.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const ProductShelfScript = preload("res://scripts/warehouse/product_shelf.gd")
const QueuedActionScript = preload("res://scripts/gameplay/queued_action.gd")
const StorageShelfScript = preload("res://scripts/warehouse/storage_shelf.gd")
const WorkerAutomationQueueScript = preload("res://scripts/gameplay/worker_automation_queue.gd")
const WorkerStoragePlannerScript = preload("res://scripts/gameplay/worker_storage_planner.gd")
const WorkerTaskConfigScript = preload("res://scripts/gameplay/worker_task_config.gd")
const WorkerTaskManagerScript = preload("res://scripts/gameplay/worker_task_manager.gd")
const WORKER_SCENE := preload("res://scenes/worker/worker.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("disabled storage skips automation", await _test_disabled_storage_skips_automation())
	failed += _assert("planner picks up dock box", await _test_plan_pickup_box())
	failed += _assert("planner stores carried box on storage shelf", await _test_plan_store_box())
	failed += _assert("worker stores picked up box on storage shelf", await _test_pickup_and_store_flow())
	failed += _assert("planner withdraws for empty product shelf", await _test_plan_withdraw_for_empty_shelf())
	failed += _assert("worker refills empty shelf from storage", await _test_refill_empty_shelf_flow())
	failed += _assert("full storage shelf is not selected", await _test_respects_storage_capacity())
	failed += _assert("automation queue enqueues storage actions", await _test_automation_queue_enqueue())

	if failed == 0:
		print("storage_worker_test: ALL PASSED")
		quit(0)
	else:
		push_error("storage_worker_test: %d FAILED" % failed)
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
	for child in root.get_children():
		if child.name in ["GridService", "WorkerTaskManager"]:
			continue
		child.free()
	await process_frame


func _ensure_autoloads() -> void:
	if root.get_node_or_null("GridService") == null:
		var grid: WarehouseGrid = GridScript.new()
		grid.name = "GridService"
		root.add_child(grid)
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


func _make_storage() -> StorageShelf:
	var storage: StorageShelf = StorageShelfScript.new()
	root.add_child(storage)
	storage.setup(Vector3(2.0, 0.0, 2.0), 0.0)
	await process_frame
	return storage


func _make_product_shelf(product_id: String = "", start_count: int = 0) -> ProductShelf:
	var shelf: ProductShelf = ProductShelfScript.new()
	root.add_child(shelf)
	shelf.setup(Vector3(4.0, 0.0, 2.0), 0.0)
	shelf.add_to_group("shelves")
	if product_id != "" and start_count > 0:
		shelf.stock_product(product_id, start_count)
	await process_frame
	return shelf


func _spawn_delivery_box(product_id: String, count: int, position: Vector3) -> DeliveryBox:
	var box: DeliveryBox = DeliveryBoxScript.new()
	root.add_child(box)
	box.setup(product_id, count, position, 0.0)
	return box


func _test_disabled_storage_skips_automation() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	var manager: Node = root.get_node("WorkerTaskManager")
	_spawn_delivery_box("mouse", 6, Vector3(1.0, 0.0, 1.0))
	manager.call("_tick_workers")
	var queue = manager.get_queue_for_worker(worker)
	return queue != null and not bool(queue.has_pending())


func _test_plan_pickup_box() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE, true)
	var box := _spawn_delivery_box("mouse", 6, Vector3(1.0, 0.0, 1.0))
	var action := WorkerStoragePlannerScript.plan_next(worker, self, [])
	return (
		action != null
		and action.type == QueuedActionScript.Type.PICKUP_BOX
		and action.target == box
	)


func _test_plan_store_box() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE, true)
	var storage := await _make_storage()
	worker.add_delivery_box("keyboard", 4)
	var action := WorkerStoragePlannerScript.plan_next(worker, self, [])
	return (
		action != null
		and action.type == QueuedActionScript.Type.STORE_BOX_ON_STORAGE
		and action.target == storage
	)


func _test_pickup_and_store_flow() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE, true)
	var storage := await _make_storage()
	var box := _spawn_delivery_box("mouse", 6, Vector3(1.0, 0.0, 1.0))
	var pickup := WorkerStoragePlannerScript.plan_next(worker, self, [])
	if pickup == null or pickup.type != QueuedActionScript.Type.PICKUP_BOX:
		return false
	if not box.pickup_into(worker):
		return false
	await process_frame
	var store := WorkerStoragePlannerScript.plan_next(worker, self, [])
	if store == null or store.type != QueuedActionScript.Type.STORE_BOX_ON_STORAGE:
		return false
	return (
		worker.deposit_box_to_storage(int(store.stock_from_box_id), storage)
		and storage.get_box_count() == 1
	)


func _test_plan_withdraw_for_empty_shelf() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE, true)
	var storage := await _make_storage()
	var shelf := await _make_product_shelf("mouse", 0)
	storage.store_box("mouse", 6)
	var action := WorkerStoragePlannerScript.plan_next(worker, self, [])
	return (
		action != null
		and action.type == QueuedActionScript.Type.WITHDRAW_BOX_FROM_STORAGE
		and action.target == storage
		and shelf.count == 0
	)


func _test_refill_empty_shelf_flow() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE, true)
	var storage := await _make_storage()
	var shelf := await _make_product_shelf("mouse", 0)
	storage.store_box("mouse", 6)
	var storage_box_id := int(storage.get_stored_boxes()[0].get("id", -1))

	var withdraw := WorkerStoragePlannerScript.plan_next(worker, self, [])
	if withdraw == null or withdraw.type != QueuedActionScript.Type.WITHDRAW_BOX_FROM_STORAGE:
		return false
	if not worker.withdraw_box_to_inventory(storage, storage_box_id):
		return false

	var stock := WorkerStoragePlannerScript.plan_next(worker, self, [])
	if stock == null or stock.type != QueuedActionScript.Type.STOCK_SHELF:
		return false
	var worker_box_id := int(worker.get_carried_boxes()[0].get("id", -1))
	var stocked := worker.stock_from_box_id(worker_box_id, shelf, 6)
	return stocked == 6 and shelf.count == 6 and shelf.product_id == "mouse"


func _test_respects_storage_capacity() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE, true)
	var storage := await _make_storage()
	for i in range(StorageShelfScript.MAX_BOX_SLOTS):
		storage.store_box("mouse", 1)
	worker.add_delivery_box("mouse", 6)
	var action := WorkerStoragePlannerScript.plan_next(worker, self, [])
	return action == null


func _test_automation_queue_enqueue() -> bool:
	await _clear_scene()
	var worker := await _make_worker()
	worker.set_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE, true)
	_spawn_delivery_box("mouse", 6, Vector3(1.0, 0.0, 1.0))
	var queue = WorkerAutomationQueueScript.new()
	worker.add_child(queue)
	queue.bind_worker(worker)
	var action := WorkerStoragePlannerScript.plan_next(worker, self, [])
	if action == null:
		return false
	return queue.enqueue(action)
