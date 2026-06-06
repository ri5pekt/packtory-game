extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/warehouse_edit_test.gd

const GridScript = preload("res://scripts/autoload/grid_service.gd")
const ProductShelfScript = preload("res://scripts/warehouse/product_shelf.gd")
const PackingTableScript = preload("res://scripts/warehouse/packing_table.gd")
const ReceptionTableScript = preload("res://scripts/warehouse/reception_table.gd")
const ComputerWorkstationScript = preload("res://scripts/warehouse/computer_workstation.gd")


func _init() -> void:
	var failed := 0
	var grid := _make_grid()
	failed += _assert("shelf occupies one cell", _test_shelf_footprint(grid))
	failed += _assert("packing table rotates footprint", _test_table_rotation(grid))
	failed += _assert("computer desk has three-cell footprint", _test_desk_footprint(grid))
	failed += _assert("computer desk can sit against wall", _test_desk_wall_placement(grid))
	failed += _assert("blocked cell rejects placement", _test_blocked_rejection(grid))
	failed += _assert("ignore cells allow self-overlap while moving", _test_ignore_cells(grid))
	failed += _assert("reception move updates queue slot", _test_reception_relocate(grid))
	failed += _assert("outside warehouse is invalid", _test_outside_warehouse(grid))
	failed += _assert("south apron ring is paved floor", _test_south_apron_floor(grid))
	failed += _assert("entrance doorway has interior floor lip", _test_entrance_door_floor(grid))
	failed += _assert("entrance walkway is paved floor", _test_entrance_walkway_floor(grid))
	failed += _assert("dock southeast corner is apron floor", _test_dock_corner_apron_floor(grid))
	failed += _assert("dock east apron is paved floor", _test_dock_apron_floor(grid))
	failed += _assert("exterior apron is not white interior", _test_exterior_uses_apron_floor(grid))
	failed += _assert("front corner padding is paved apron", _test_front_corner_padding(grid))
	failed += _assert("road band is continuous under walkway", _test_road_under_walkway(grid))
	failed += _assert("road band reaches southeast corner", _test_road_corner(grid))
	failed += _assert("interior warehouse has no road overlap", _test_interior_not_road(grid))
	failed += _assert("road sits close to warehouse entrance", _test_road_near_warehouse(grid))
	failed += _assert("entrance crosswalk spans road columns", _test_entrance_crosswalk(grid))
	failed += _assert("entrance path reaches south sidewalk", _test_entrance_path_to_south_sidewalk(grid))
	failed += _assert("entrance door lip uses dark apron", _test_entrance_lip_dark_apron(grid))
	failed += _assert("entrance road columns are asphalt", _test_entrance_road_columns(grid))
	failed += _assert("grass south of south sidewalk", _test_grass_south_of_south_sidewalk(grid))

	if failed == 0:
		print("warehouse_edit_test: ALL PASSED")
		quit(0)
	else:
		push_error("warehouse_edit_test: %d FAILED" % failed)
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
	return grid


func _test_shelf_footprint(grid: WarehouseGrid) -> bool:
	var shelf: ProductShelf = ProductShelfScript.new()
	root.add_child(shelf)
	var cell := Vector2i(14, 14)
	shelf.setup(grid.cell_to_world(cell), 0.0)
	var cells: Array[Vector2i] = shelf.get_footprint_cells_at(cell, 0.0)
	return cells.size() == 1 and cells[0] == cell


func _test_table_rotation(grid: WarehouseGrid) -> bool:
	var table: PackingTable = PackingTableScript.new()
	root.add_child(table)
	var anchor := Vector2i(15, 16)
	table.setup(grid.cell_to_world(anchor), 0.0)
	var yaw0 := table.get_footprint_cells_at(anchor, 0.0)
	var yaw90 := table.get_footprint_cells_at(anchor, 90.0)
	return yaw0.size() == 3 and yaw90.size() == 3 and yaw0 != yaw90


func _test_desk_footprint(grid: WarehouseGrid) -> bool:
	var desk: Node3D = ComputerWorkstationScript.new()
	root.add_child(desk)
	var anchor := Vector2i(14, 14)
	desk.setup(grid.cell_to_world(anchor), 0.0)
	var cells: Array[Vector2i] = desk.get_footprint_cells_at(anchor, 0.0)
	return cells.size() == 3


func _test_desk_wall_placement(grid: WarehouseGrid) -> bool:
	var west_col := grid.warehouse_origin.x
	var row := grid.warehouse_origin.y + 3
	grid.register_wall_cell(Vector2i(west_col, row))
	var desk: Node3D = ComputerWorkstationScript.new()
	root.add_child(desk)
	var anchor := Vector2i(west_col + 1, row)
	var cells: Array[Vector2i] = desk.get_footprint_cells_at(anchor, 0.0)
	return cells.has(Vector2i(west_col, row)) and grid.can_occupy_cells(cells, [])


func _test_blocked_rejection(grid: WarehouseGrid) -> bool:
	var blocker := Vector2i(16, 16)
	grid.block_cell(blocker)
	var table: PackingTable = PackingTableScript.new()
	root.add_child(table)
	var anchor := Vector2i(15, 16)
	var cells: Array[Vector2i] = table.get_footprint_cells_at(anchor, 0.0)
	return not grid.can_occupy_cells(cells, [])


func _test_ignore_cells(grid: WarehouseGrid) -> bool:
	var shelf: ProductShelf = ProductShelfScript.new()
	root.add_child(shelf)
	var cell := Vector2i(14, 14)
	shelf.setup(grid.cell_to_world(cell), 0.0)
	var ignore := shelf.get_ignore_cells()
	return grid.can_occupy_cells([cell], ignore)


func _test_reception_relocate(grid: WarehouseGrid) -> bool:
	var table: Node3D = ReceptionTableScript.new()
	table.use_grid(grid)
	root.add_child(table)
	table.setup(grid.cell_to_world(Vector2i(16, 15)), 0.0)
	var before_x: float = table.position.x
	var slot_before: Vector3 = table.get_slot(0)
	table.apply_placement(Vector2i(18, 15), 0.0)
	var moved_table := not is_equal_approx(table.position.x, before_x)
	var slot_after: Vector3 = table.get_slot(0)
	var moved_slot := slot_before.distance_to(slot_after) > 0.5
	return moved_table and moved_slot


func _test_outside_warehouse(grid: WarehouseGrid) -> bool:
	var outside := grid.warehouse_origin + Vector2i(-1, 0)
	return not grid.is_warehouse_cell(outside)


func _test_south_apron_floor(grid: WarehouseGrid) -> bool:
	var south_row := grid.warehouse_origin.y + WarehouseGrid.WAREHOUSE_SIZE.y
	# One cell beside the walkway should pick up apron ring paving.
	var cell := Vector2i(WarehouseGrid.ENTRANCE_COL_A - 1, south_row + 1)
	return grid.is_warehouse_floor_cell(cell) and grid.is_warehouse_border_cell(cell)


func _test_entrance_door_floor(grid: WarehouseGrid) -> bool:
	var lip := Vector2i(WarehouseGrid.ENTRANCE_COL_A, WarehouseGrid.WALKWAY_NORTH_ROW)
	var beside := Vector2i(WarehouseGrid.ENTRANCE_COL_A - 1, WarehouseGrid.WALKWAY_NORTH_ROW)
	return (
		grid.is_entrance_door_floor_cell(lip)
		and not grid.uses_interior_warehouse_floor(lip)
		and not grid.uses_interior_warehouse_floor(beside)
		and grid.is_warehouse_floor_cell(lip)
	)


func _test_entrance_walkway_floor(grid: WarehouseGrid) -> bool:
	var lip := Vector2i(WarehouseGrid.ENTRANCE_COL_A, WarehouseGrid.WALKWAY_NORTH_ROW)
	var north_sidewalk := Vector2i(
		WarehouseGrid.ENTRANCE_COL_A,
		WarehouseGrid.DECORATIVE_SIDEWALK_NORTH_ROW
	)
	return (
		grid.is_entrance_apron_cell(lip)
		and grid.is_warehouse_floor_cell(lip)
		and grid.is_entrance_apron_cell(north_sidewalk)
		and grid.is_decorative_walkway_cell(north_sidewalk)
	)


func _test_dock_corner_apron_floor(grid: WarehouseGrid) -> bool:
	var corner := Vector2i(
		grid.warehouse_origin.x + WarehouseGrid.WAREHOUSE_SIZE.x,
		grid.warehouse_origin.y + WarehouseGrid.WAREHOUSE_SIZE.y
	)
	return (
		grid.is_warehouse_floor_cell(corner)
		and not grid.uses_interior_warehouse_floor(corner)
	)


func _test_dock_apron_floor(grid: WarehouseGrid) -> bool:
	var cell := Vector2i(WarehouseGrid.DOCK_EAST_COL + 2, WarehouseGrid.DOCK_NORTH_ROW)
	return grid.is_warehouse_floor_cell(cell) and grid.is_dock_apron_cell(cell)


func _test_exterior_uses_apron_floor(grid: WarehouseGrid) -> bool:
	var o := grid.warehouse_origin
	var s := WarehouseGrid.WAREHOUSE_SIZE
	var south_lip := Vector2i(o.x, o.y + s.y)
	var west_border := Vector2i(o.x - 1, o.y + 3)
	var walkway := Vector2i(WarehouseGrid.ENTRANCE_COL_A, WarehouseGrid.WALKWAY_NORTH_ROW)
	return (
		grid.is_warehouse_floor_cell(south_lip)
		and not grid.uses_interior_warehouse_floor(south_lip)
		and grid.is_warehouse_floor_cell(west_border)
		and not grid.uses_interior_warehouse_floor(west_border)
		and grid.is_warehouse_floor_cell(walkway)
		and not grid.uses_interior_warehouse_floor(walkway)
	)


func _test_front_corner_padding(grid: WarehouseGrid) -> bool:
	var o := grid.warehouse_origin
	var s := WarehouseGrid.WAREHOUSE_SIZE
	var wedge := Vector2i(o.x - 2, o.y + s.y + 1)
	return (
		grid.is_warehouse_border_padding_cell(wedge)
		and grid.is_warehouse_floor_cell(wedge)
		and not grid.uses_interior_warehouse_floor(wedge)
	)


func _test_road_under_walkway(grid: WarehouseGrid) -> bool:
	var cells := [
		Vector2i(WarehouseGrid.ENTRANCE_COL_A, WarehouseGrid.DECORATIVE_ROAD_ROW),
		Vector2i(
			WarehouseGrid.ENTRANCE_COL_B,
			WarehouseGrid.DECORATIVE_ROAD_ROW + WarehouseGrid.DECORATIVE_ROAD_LANE_COUNT - 1
		),
	]
	for cell in cells:
		if not grid.is_decorative_road_cell(cell):
			return false
		if grid.is_entrance_crosswalk_cell(cell):
			return false
	return true


func _test_road_corner(grid: WarehouseGrid) -> bool:
	var cell := Vector2i(grid.total_size.x - 1, WarehouseGrid.DECORATIVE_ROAD_ROW)
	return grid.is_decorative_road_cell(cell) and not grid.is_warehouse_floor_cell(cell)


func _test_interior_not_road(grid: WarehouseGrid) -> bool:
	var cell := grid.warehouse_origin + Vector2i(2, 2)
	return grid.is_warehouse_floor_cell(cell) and not grid.is_decorative_road_cell(cell)


func _test_road_near_warehouse(grid: WarehouseGrid) -> bool:
	var south_line := grid.warehouse_origin.y + WarehouseGrid.WAREHOUSE_SIZE.y
	var gap := WarehouseGrid.DECORATIVE_ROAD_ROW - south_line
	return gap == WarehouseGrid.ROAD_GAP_ROWS and gap <= 3


func _test_entrance_crosswalk(grid: WarehouseGrid) -> bool:
	var col_a := Vector2i(WarehouseGrid.ENTRANCE_COL_A, WarehouseGrid.DECORATIVE_ROAD_ROW)
	var col_b := Vector2i(
		WarehouseGrid.ENTRANCE_COL_B,
		WarehouseGrid.DECORATIVE_ROAD_ROW + WarehouseGrid.DECORATIVE_ROAD_LANE_COUNT - 1
	)
	return (
		grid.is_decorative_road_cell(col_a)
		and grid.is_decorative_road_cell(col_b)
		and not grid.is_entrance_crosswalk_cell(col_a)
		and not grid.is_grass_cell(col_a)
	)


func _test_entrance_path_to_south_sidewalk(grid: WarehouseGrid) -> bool:
	var cell := Vector2i(
		WarehouseGrid.ENTRANCE_COL_B,
		WarehouseGrid.DECORATIVE_SIDEWALK_SOUTH_ROW
	)
	return grid.is_decorative_walkway_cell(cell) and not grid.is_grass_cell(cell)


func _test_entrance_lip_dark_apron(grid: WarehouseGrid) -> bool:
	var south_row := grid.warehouse_origin.y + WarehouseGrid.WAREHOUSE_SIZE.y
	for col in [WarehouseGrid.ENTRANCE_COL_A, WarehouseGrid.ENTRANCE_COL_B]:
		var cell := Vector2i(col, south_row)
		if not grid.is_warehouse_floor_cell(cell):
			return false
		if grid.uses_interior_warehouse_floor(cell):
			return false
	return true


func _test_entrance_road_columns(grid: WarehouseGrid) -> bool:
	for col in [WarehouseGrid.ENTRANCE_COL_A, WarehouseGrid.ENTRANCE_COL_B]:
		for row in range(
			WarehouseGrid.DECORATIVE_ROAD_ROW,
			WarehouseGrid.DECORATIVE_ROAD_ROW + WarehouseGrid.DECORATIVE_ROAD_LANE_COUNT
		):
			var cell := Vector2i(col, row)
			if not grid.is_decorative_road_cell(cell):
				return false
			if grid.is_decorative_sidewalk_cell(cell):
				return false
	return true


func _test_grass_south_of_south_sidewalk(grid: WarehouseGrid) -> bool:
	var south_row := WarehouseGrid.DECORATIVE_SIDEWALK_SOUTH_ROW
	for col in range(13, 19):
		for row in [south_row + 1, south_row + 2]:
			var cell := Vector2i(col, row)
			if grid.is_warehouse_floor_cell(cell):
				return false
			if not grid.is_grass_cell(cell):
				return false
	return true
