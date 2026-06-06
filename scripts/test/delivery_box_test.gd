extends SceneTree

## Run with: godot --headless --path . --script res://scripts/test/delivery_box_test.gd

const WorkerScript = preload("res://scripts/worker/worker.gd")
const ProductShelfScript = preload("res://scripts/warehouse/product_shelf.gd")
const ProjectedStateScript = preload("res://scripts/gameplay/projected_state.gd")
const QueuedActionScript = preload("res://scripts/gameplay/queued_action.gd")
const DeliveryBoxScript = preload("res://scripts/gameplay/delivery_box.gd")


func _init() -> void:
	var failed := 0
	failed += _assert("pickup adds one boxed slot", _test_pickup_slot())
	failed += _assert("box does not add loose inventory", _test_not_loose())
	failed += _assert("unpack stocks shelf", _test_unpack_shelf())
	failed += _assert("partial unpack keeps box", _test_partial_unpack())
	failed += _assert("projected pickup reserves slot", _test_projected_pickup())

	if failed == 0:
		print("delivery_box_test: ALL PASSED")
		quit(0)
	else:
		push_error("delivery_box_test: %d FAILED" % failed)
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


func _test_pickup_slot() -> bool:
	var worker := _make_worker()
	if not worker.add_delivery_box("mouse", 6):
		return false
	var stacks := worker.get_inventory_stacks()
	return (
		stacks.size() == 1
		and bool(stacks[0].get("is_box", false))
		and int(stacks[0].get("count", 0)) == 6
	)


func _test_not_loose() -> bool:
	var worker := _make_worker()
	worker.add_delivery_box("mouse", 6)
	return worker.count_product("mouse") == 0 and worker.get_total_units() == 0


func _test_unpack_shelf() -> bool:
	var worker := _make_worker()
	worker.add_delivery_box("mouse", 6)
	var shelf: ProductShelf = ProductShelfScript.new()
	shelf.setup(Vector3.ZERO, 0.0)
	var box_id := int(worker.get_carried_boxes()[0].get("id", -1))
	var stocked := worker.stock_from_box_id(box_id, shelf, 6)
	return stocked == 6 and shelf.count == 6 and shelf.product_id == "mouse" \
		and worker.get_carried_boxes().is_empty()


func _test_partial_unpack() -> bool:
	var worker := _make_worker()
	worker.add_delivery_box("mouse", 6)
	var shelf: ProductShelf = ProductShelfScript.new()
	shelf.setup(Vector3.ZERO, 0.0)
	shelf.stock_product("mouse", 4)
	var box_id := int(worker.get_carried_boxes()[0].get("id", -1))
	var stocked := worker.stock_from_box_id(box_id, shelf, 6)
	return stocked == 2 and shelf.count == 6 and worker.get_carried_boxes().size() == 1 \
		and int(worker.get_carried_boxes()[0].get("count", 0)) == 4


func _test_projected_pickup() -> bool:
	var worker := _make_worker()
	var box: DeliveryBox = DeliveryBoxScript.new()
	box.setup("mouse", 6, Vector3.ZERO, 0.0)
	var action := QueuedActionScript.make_pickup_box(box)
	var state := ProjectedStateScript.from_game(worker, null)
	if not state.apply(action):
		return false
	return state.carried_boxes.size() == 1 and state._used_slots() == 1 \
		and state._free_carry_capacity() == WorkerScript.MAX_CARRIED_ENTRIES - 1
