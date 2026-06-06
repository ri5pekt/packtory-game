extends SceneTree

## Run with: godot --headless --path . --script res://scripts/test/reception_queue_test.gd

const ReceptionTableScript = preload("res://scripts/warehouse/reception_table.gd")
const QueueAreaLayoutScript = preload("res://scripts/warehouse/queue_area_layout.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const PathfindingScript = preload("res://scripts/pathfinding/pathfinding.gd")


func _init() -> void:
	var failed := 0
	failed += _assert("slot 0 uses queue start marker", _test_slot_zero_at_marker())
	failed += _assert("moving reception table moves queue slots", _test_table_move_updates_slots())
	failed += _assert("queue layout binds reception table", _test_layout_bind())
	failed += _assert("slot spacing lines up behind start", _test_slot_spacing())
	failed += _assert("default queue slots form a straight line", _test_slots_form_straight_line())
	failed += _assert("wall near desk still finds spaced queue slots", _test_angled_queue_near_wall())
	failed += _assert("queue slots stay one meter apart", _test_slot_spacing_one_meter())

	if failed == 0:
		print("reception_queue_test: ALL PASSED")
		quit(0)
	else:
		push_error("reception_queue_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _make_table(at: Vector3) -> Node3D:
	var table: Node3D = ReceptionTableScript.new()
	table.name = "ReceptionTable"
	root.add_child(table)
	table.setup(at, 0.0)
	QueueAreaLayoutScript.bind(table)
	return table


func _test_slot_zero_at_marker() -> bool:
	var table := _make_table(Vector3(16.5, 0.0, 15.5))
	var start: Vector3 = table.get_queue_start_world()
	var slot0: Vector3 = QueueAreaLayoutScript.get_slot(0)
	return start.distance_to(slot0) < 0.05


func _test_table_move_updates_slots() -> bool:
	var grid := _make_grid()
	var table: Node3D = ReceptionTableScript.new()
	table.use_grid(grid)
	root.add_child(table)
	table.setup(grid.cell_to_world(Vector2i(10, 10)), 0.0)
	QueueAreaLayoutScript.bind(table)
	var before: Vector3 = QueueAreaLayoutScript.get_slot(1)
	table.apply_placement(Vector2i(15, 8), 0.0)
	var after: Vector3 = QueueAreaLayoutScript.get_slot(1)
	return not before.is_equal_approx(after)


func _test_layout_bind() -> bool:
	var table := _make_table(Vector3(16.5, 0.0, 15.5))
	return QueueAreaLayoutScript.get_reception() == table


func _test_slot_spacing() -> bool:
	var table := _make_table(Vector3(16.5, 0.0, 15.5))
	var s0 := QueueAreaLayoutScript.get_slot(0)
	var s1 := QueueAreaLayoutScript.get_slot(1)
	var spacing := s0.distance_to(s1)
	return is_equal_approx(spacing, ReceptionTableScript.SLOT_SPACING)


func _test_slots_form_straight_line() -> bool:
	var grid := _make_grid()
	var table: Node3D = ReceptionTableScript.new()
	table.use_grid(grid)
	root.add_child(table)
	table.setup(grid.cell_to_world(Vector2i(16, 15)), 0.0)
	QueueAreaLayoutScript.bind(table)

	var primary: Vector3 = table.get_line_direction()
	var start: Vector3 = QueueAreaLayoutScript.get_slot(0)
	for i in range(1, ReceptionTableScript.MAX_QUEUE):
		var slot: Vector3 = QueueAreaLayoutScript.get_slot(i)
		var expected: Vector3 = start + primary * ReceptionTableScript.SLOT_SPACING * float(i)
		if slot.distance_to(expected) > 0.08:
			return false
	return true


func _make_grid() -> WarehouseGrid:
	var grid: WarehouseGrid = GridScript.new()
	grid.name = "GridService"
	root.add_child(grid)
	grid.pathfinding = PathfindingScript.new(grid)
	return grid


func _test_angled_queue_near_wall() -> bool:
	var grid := _make_grid()
	var table: Node3D = ReceptionTableScript.new()
	table.use_grid(grid)
	root.add_child(table)
	table.setup(grid.cell_to_world(Vector2i(20, 15)), 90.0)
	QueueAreaLayoutScript.bind(table)

	# East wall / obstacle directly in front of the rotated desk queue line.
	for x in range(21, 24):
		grid.block_cell(Vector2i(x, 15))

	var s0 := QueueAreaLayoutScript.get_slot(0)
	var s1 := QueueAreaLayoutScript.get_slot(1)
	var s2 := QueueAreaLayoutScript.get_slot(2)
	return (
		s0.distance_to(s1) >= ReceptionTableScript.SLOT_SPACING * 0.65
		and s1.distance_to(s2) >= ReceptionTableScript.SLOT_SPACING * 0.65
		and not s0.is_equal_approx(s1)
		and not s1.is_equal_approx(s2)
	)


func _test_slot_spacing_one_meter() -> bool:
	var table := _make_table(Vector3(16.5, 0.0, 15.5))
	var s0 := QueueAreaLayoutScript.get_slot(0)
	var s1 := QueueAreaLayoutScript.get_slot(1)
	var s2 := QueueAreaLayoutScript.get_slot(2)
	return (
		is_equal_approx(s0.distance_to(s1), 1.15)
		and is_equal_approx(s1.distance_to(s2), 1.15)
	)
