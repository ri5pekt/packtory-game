extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/customer_queue_line_test.gd

const CustomerScript = preload("res://scripts/gameplay/customer.gd")
const QueueAreaLayoutScript = preload("res://scripts/warehouse/queue_area_layout.gd")
const ReceptionTableScript = preload("res://scripts/warehouse/reception_table.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const PathfindingScript = preload("res://scripts/pathfinding/pathfinding.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failed := 0
	failed += _assert("queue slots stay separated", _test_slot_separation())
	failed += _assert("queue slot check uses tight tolerance", _test_is_at_queue_slot())
	failed += _assert("queue reposition steps along lane when desk blocks path", _test_queue_lane_waypoints())

	if failed == 0:
		print("customer_queue_line_test: ALL PASSED")
		quit(0)
	else:
		push_error("customer_queue_line_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _make_grid() -> WarehouseGrid:
	var grid: WarehouseGrid = GridScript.new()
	grid.name = "GridService"
	root.add_child(grid)
	grid.pathfinding = PathfindingScript.new(grid)
	return grid


func _bind_reception(grid: WarehouseGrid) -> Node3D:
	var table: Node3D = ReceptionTableScript.new()
	table.use_grid(grid)
	root.add_child(table)
	table.setup(grid.cell_to_world(Vector2i(16, 15)), 0.0)
	QueueAreaLayoutScript.bind(table)
	return table


func _test_slot_separation() -> bool:
	var grid := _make_grid()
	_bind_reception(grid)
	var min_body := CustomerScript.BODY_RADIUS * 2.0 + 0.05
	for i in range(ReceptionTableScript.MAX_QUEUE - 1):
		var a := QueueAreaLayoutScript.get_slot(i)
		var b := QueueAreaLayoutScript.get_slot(i + 1)
		if a.distance_to(b) + 0.001 < min_body:
			return false
	return true


func _test_is_at_queue_slot() -> bool:
	var grid := _make_grid()
	_bind_reception(grid)
	var slot := QueueAreaLayoutScript.get_slot(1)
	var customer: Customer = CustomerScript.new()
	root.add_child(customer)
	customer.global_position = slot + Vector3(0.04, 0.0, 0.0)
	var close := customer.is_at_queue_slot(slot)
	customer.global_position = slot + Vector3(0.2, 0.0, 0.0)
	var far := not customer.is_at_queue_slot(slot)
	customer.queue_free()
	return close and far


func _test_queue_lane_waypoints() -> bool:
	var grid := _make_grid()
	_bind_reception(grid)
	var slot0 := QueueAreaLayoutScript.get_slot(0)
	var slot2 := QueueAreaLayoutScript.get_slot(2)
	var customer: Customer = CustomerScript.new()
	root.add_child(customer)
	customer._bind_pathfinding()
	customer.state = CustomerScript.State.REPOSITIONING
	customer.global_position = slot2
	var path := customer.build_path_for_test([slot0])
	if path.is_empty():
		customer.queue_free()
		return false
	var primary: Vector3 = QueueAreaLayoutScript.get_reception().get_line_direction()
	for point in path:
		var offset := point - slot0
		offset.y = 0.0
		if absf(offset.cross(primary).y) > 0.2:
			customer.queue_free()
			return false
	customer.queue_free()
	return path[-1].distance_to(slot0) < 0.05
