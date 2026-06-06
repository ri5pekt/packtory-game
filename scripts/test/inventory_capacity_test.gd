extends SceneTree

## Run with: godot --headless --path . --script res://scripts/test/inventory_capacity_test.gd

const WorkerScript = preload("res://scripts/worker/worker.gd")
const ProjectedStateScript = preload("res://scripts/gameplay/projected_state.gd")
const QueuedActionScript = preload("res://scripts/gameplay/queued_action.gd")
const ProductShelfScript = preload("res://scripts/warehouse/product_shelf.gd")


func _init() -> void:
	var failed := 0
	failed += _assert("max capacity is 6", WorkerScript.MAX_CARRIED_ENTRIES == 6)
	failed += _assert("each loose unit counts as one entry", _test_loose_units())
	failed += _assert("each delivery box counts as one entry", _test_box_entry())
	failed += _assert("mixed loose items and boxes respect limit", _test_mixed_capacity())
	failed += _assert("seventh loose item is blocked", _test_seventh_loose_blocked())
	failed += _assert("collect respects free capacity", _test_projected_collect_capacity())

	if failed == 0:
		print("inventory_capacity_test: ALL PASSED")
		quit(0)
	else:
		push_error("inventory_capacity_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _make_worker() -> Worker:
	return WorkerScript.new()


func _test_loose_units() -> bool:
	var worker := _make_worker()
	for _i in range(6):
		if not worker.add_product("mouse"):
			return false
	return worker.used_inventory_slots() == 6 and worker.free_carry_capacity() == 0


func _test_box_entry() -> bool:
	var worker := _make_worker()
	for _i in range(6):
		if not worker.add_delivery_box("mouse", 12):
			return false
	return worker.used_inventory_slots() == 6 and worker.get_carried_boxes().size() == 6


func _test_mixed_capacity() -> bool:
	var worker := _make_worker()
	for _i in range(3):
		if not worker.add_product("mouse"):
			return false
	for _i in range(2):
		if not worker.add_delivery_box("headphones", 4):
			return false
	if not worker.add_product("book"):
		return false
	return (
		worker.used_inventory_slots() == 6
		and not worker.add_product("mouse")
		and not worker.add_delivery_box("mouse", 2)
	)


func _test_seventh_loose_blocked() -> bool:
	var worker := _make_worker()
	for _i in range(6):
		worker.add_product("mouse")
	return worker.is_inventory_full() and not worker.add_product("mouse")


func _test_projected_collect_capacity() -> bool:
	var worker := _make_worker()
	for _i in range(6):
		worker.add_product("mouse")
	var shelf: ProductShelf = ProductShelfScript.new()
	shelf.setup_with_product("mouse", Vector3.ZERO, 0.0, 4)
	var action := QueuedActionScript.make_collect(shelf, 1)
	var state := ProjectedStateScript.from_game(worker, null)
	return not state.can_collect_from_shelf(shelf, 1) and not state.apply(action)
