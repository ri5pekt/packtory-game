extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/customer_queue_movement_test.gd

const CustomerScript = preload("res://scripts/gameplay/customer.gd")
const QueueAreaLayoutScript = preload("res://scripts/warehouse/queue_area_layout.gd")
const ReceptionTableScript = preload("res://scripts/warehouse/reception_table.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const PathfindingScript = preload("res://scripts/pathfinding/pathfinding.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failed := 0
	failed += _assert(
		"queue move routes around blocked wall cells",
		_test_queue_move_avoids_wall()
	)
	failed += _assert(
		"adjacent queue slots still move directly",
		_test_adjacent_queue_slots_direct()
	)

	if failed == 0:
		print("customer_queue_movement_test: ALL PASSED")
		quit(0)
	else:
		push_error("customer_queue_movement_test: %d FAILED" % failed)
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


func _make_reception(grid: WarehouseGrid) -> Node3D:
	var table: Node3D = ReceptionTableScript.new()
	table.use_grid(grid)
	root.add_child(table)
	table.setup(grid.cell_to_world(Vector2i(16, 15)), 0.0)
	QueueAreaLayoutScript.bind(table)
	return table


func _test_queue_move_avoids_wall() -> bool:
	var grid := _make_grid()
	_make_reception(grid)

	var entry := QueueAreaLayoutScript.get_entry_point()
	var slot := QueueAreaLayoutScript.get_slot(2)
	var pf: Pathfinding = grid.pathfinding

	# Block the straight line between entry and the slot so direct movement is invalid.
	var from_cell := grid.world_to_cell(entry)
	var to_cell := grid.world_to_cell(slot)
	for cell in _cells_between(from_cell, to_cell):
		if cell != from_cell and cell != to_cell:
			grid.block_cell(cell)

	if pf.is_segment_walkable(entry, slot):
		return false

	var customer: Customer = CustomerScript.new()
	root.add_child(customer)
	customer.setup(
		"res://blender/assets/kenney_mini-characters/Models/GLB format/character-male-a.glb",
		[entry, slot],
		{},
		slot,
		true
	)

	var waypoints: Array[Vector3] = customer.build_path_for_test([entry, slot])
	customer.queue_free()
	if waypoints.is_empty():
		return false
	if waypoints.size() == 1 and waypoints[0].is_equal_approx(slot):
		return false
	return true


func _test_adjacent_queue_slots_direct() -> bool:
	var grid := _make_grid()
	_make_reception(grid)

	var slot0 := QueueAreaLayoutScript.get_slot(0)
	var slot1 := QueueAreaLayoutScript.get_slot(1)

	var customer: Customer = CustomerScript.new()
	root.add_child(customer)
	customer.global_position = slot1
	customer.assigned_slot = slot0
	customer.state = Customer.State.REPOSITIONING
	customer._bind_pathfinding()

	var waypoints: Array[Vector3] = customer.build_path_for_test([slot0])
	customer.queue_free()
	return not waypoints.is_empty() and waypoints[-1].is_equal_approx(slot0)


func _cells_between(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x0 := from_cell.x
	var y0 := from_cell.y
	var x1 := to_cell.x
	var y1 := to_cell.y
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		cells.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return cells
