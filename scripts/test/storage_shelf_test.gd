extends SceneTree

## Run with: godot --headless --path . --script res://scripts/test/storage_shelf_test.gd

const WorkerScript = preload("res://scripts/worker/worker.gd")
const ProductShelfScript = preload("res://scripts/warehouse/product_shelf.gd")
const StorageShelfScript = preload("res://scripts/warehouse/storage_shelf.gd")
const ProjectedStateScript = preload("res://scripts/gameplay/projected_state.gd")
const QueuedActionScript = preload("res://scripts/gameplay/queued_action.gd")


func _init() -> void:
	var failed := 0
	failed += _assert("storage shelf label", _test_storage_label())
	failed += _assert("store box keeps sealed on shelf", _test_store_keeps_sealed())
	failed += _assert("store does not unpack to loose inventory", _test_no_loose_inventory())
	failed += _assert("product shelf stays empty after storage deposit", _test_product_shelf_empty())
	failed += _assert("withdraw then unpack restocks product shelf", _test_withdraw_and_restock())
	failed += _assert("move box between storage shelves", _test_storage_to_storage())
	failed += _assert("projected store reserves worker box slot", _test_projected_store())
	failed += _assert("projected withdraw does not mutate shelf", _test_projected_withdraw_no_mutation())
	failed += _assert("full storage shelf rejects deposit", _test_full_storage())

	if failed == 0:
		print("storage_shelf_test: ALL PASSED")
		quit(0)
	else:
		push_error("storage_shelf_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _make_worker() -> Worker:
	var worker: Worker = WorkerScript.new()
	worker.name = "TestWorker"
	var root := Node3D.new()
	root.name = "Root"
	root.add_child(worker)
	root.add_child(_make_grid_stub())
	return worker


func _make_grid_stub() -> Node:
	var grid := Node.new()
	grid.name = "GridService"
	grid.set_script(load("res://scripts/autoload/grid_service.gd"))
	return grid


func _make_storage() -> Node:
	var shelf: Node = StorageShelfScript.new()
	shelf.setup(Vector3.ZERO, 0.0)
	return shelf


func _test_storage_label() -> bool:
	var shelf: Node = StorageShelfScript.new()
	return shelf.get_placeable_label() == "Storage Shelf"


func _test_store_keeps_sealed() -> bool:
	var worker := _make_worker()
	var storage := _make_storage()
	if not worker.add_delivery_box("mouse", 6):
		return false
	var box_id := int(worker.get_carried_boxes()[0].get("id", -1))
	if not worker.deposit_box_to_storage(box_id, storage):
		return false
	var stored: Array = storage.get_stored_boxes()
	return (
		worker.get_carried_boxes().is_empty()
		and stored.size() == 1
		and String(stored[0].get("product_id", "")) == "mouse"
		and int(stored[0].get("count", 0)) == 6
	)


func _test_no_loose_inventory() -> bool:
	var worker := _make_worker()
	var storage := _make_storage()
	worker.add_delivery_box("mouse", 6)
	var box_id := int(worker.get_carried_boxes()[0].get("id", -1))
	worker.deposit_box_to_storage(box_id, storage)
	return worker.count_product("mouse") == 0 and worker.get_total_units() == 0


func _test_product_shelf_empty() -> bool:
	var worker := _make_worker()
	var storage := _make_storage()
	var product_shelf: ProductShelf = ProductShelfScript.new()
	product_shelf.setup(Vector3.ZERO, 0.0)
	worker.add_delivery_box("mouse", 6)
	var box_id := int(worker.get_carried_boxes()[0].get("id", -1))
	worker.deposit_box_to_storage(box_id, storage)
	return product_shelf.count == 0 and product_shelf.product_id == ""


func _test_withdraw_and_restock() -> bool:
	var worker := _make_worker()
	var storage := _make_storage()
	var product_shelf: ProductShelf = ProductShelfScript.new()
	product_shelf.setup(Vector3.ZERO, 0.0)
	storage.store_box("mouse", 6)
	var storage_box_id := int(storage.get_stored_boxes()[0].get("id", -1))
	if not worker.withdraw_box_to_inventory(storage, storage_box_id):
		return false
	if storage.get_box_count() != 0:
		return false
	var worker_box_id := int(worker.get_carried_boxes()[0].get("id", -1))
	var stocked := worker.stock_from_box_id(worker_box_id, product_shelf, 6)
	return (
		stocked == 6
		and product_shelf.count == 6
		and product_shelf.product_id == "mouse"
		and worker.get_carried_boxes().is_empty()
	)


func _test_storage_to_storage() -> bool:
	var worker := _make_worker()
	var storage_a := _make_storage()
	var storage_b := _make_storage()
	storage_a.store_box("keyboard", 4)
	var storage_box_id := int(storage_a.get_stored_boxes()[0].get("id", -1))
	if not worker.withdraw_box_to_inventory(storage_a, storage_box_id):
		return false
	var worker_box_id := int(worker.get_carried_boxes()[0].get("id", -1))
	if not worker.deposit_box_to_storage(worker_box_id, storage_b):
		return false
	var stored_b: Array = storage_b.get_stored_boxes()
	return storage_a.get_box_count() == 0 and stored_b.size() == 1 \
		and String(stored_b[0].get("product_id", "")) == "keyboard" \
		and int(stored_b[0].get("count", 0)) == 4


func _test_projected_store() -> bool:
	var worker := _make_worker()
	var storage := _make_storage()
	worker.add_delivery_box("mouse", 6)
	var box_id := int(worker.get_carried_boxes()[0].get("id", -1))
	var action := QueuedActionScript.make_store_box_on_storage(storage, box_id, "mouse")
	var state := ProjectedStateScript.from_game(worker, null)
	if not state.apply(action):
		return false
	return state.carried_boxes.is_empty() and storage.can_store_box()


func _test_projected_withdraw_no_mutation() -> bool:
	var worker := _make_worker()
	var storage := _make_storage()
	storage.store_box("mouse", 6)
	var storage_box_id := int(storage.get_stored_boxes()[0].get("id", -1))
	var action := QueuedActionScript.make_withdraw_box_from_storage(storage, storage_box_id)
	var state := ProjectedStateScript.from_game(worker, null)
	if not state.apply(action):
		return false
	return (
		storage.get_box_count() == 1
		and state.carried_boxes.size() == 1
		and int(state.carried_boxes[0].get("count", 0)) == 6
	)


func _test_full_storage() -> bool:
	var worker := _make_worker()
	var storage := _make_storage()
	for i in range(StorageShelfScript.MAX_BOX_SLOTS):
		storage.store_box("mouse", 1)
	worker.add_delivery_box("mouse", 6)
	var box_id := int(worker.get_carried_boxes()[0].get("id", -1))
	return not worker.deposit_box_to_storage(box_id, storage)
