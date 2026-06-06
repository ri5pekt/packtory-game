class_name Pathfinding
extends RefCounted

const ARRIVE_DISTANCE := 0.05

var _grid: WarehouseGrid
var _astar: AStarGrid2D


func _init(grid: WarehouseGrid) -> void:
	_grid = grid
	_build_grid()
	for cell in grid.get_blocked_cells():
		mark_blocked(cell)


func _build_grid() -> void:
	_astar = AStarGrid2D.new()
	var region := _grid.navigable_region()
	_astar.region = region
	_astar.cell_size = Vector2.ONE * WarehouseGrid.CELL_SIZE
	_astar.offset = Vector2(0.5, 0.5) * WarehouseGrid.CELL_SIZE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	_astar.update()
	# Cells inside the bounding rect that aren't navigable are walls.
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var cell := Vector2i(x, y)
			if not _grid.is_navigable_cell(cell):
				_astar.set_point_solid(cell, true)


func mark_blocked(cell: Vector2i) -> void:
	if not _grid.is_navigable_cell(cell):
		return
	_astar.set_point_solid(cell, true)


func mark_unblocked(cell: Vector2i) -> void:
	if not _grid.is_navigable_cell(cell):
		return
	_astar.set_point_solid(cell, false)


func is_walkable(cell: Vector2i) -> bool:
	if not _grid.is_navigable_cell(cell):
		return false
	return not _astar.is_point_solid(cell)


func find_path(from_cell: Vector2i, to_cell: Vector2i) -> PackedVector2Array:
	if not _grid.is_navigable_cell(from_cell) or not _grid.is_navigable_cell(to_cell):
		return PackedVector2Array()
	if not is_walkable(to_cell):
		return PackedVector2Array()
	return _astar.get_point_path(from_cell, to_cell)


func is_world_walkable(world: Vector3) -> bool:
	var cell := _grid.world_to_cell(world)
	if not _grid.is_navigable_cell(cell):
		return true
	return is_walkable(cell)


func is_segment_walkable(from_world: Vector3, to_world: Vector3) -> bool:
	if not is_world_walkable(to_world):
		return false
	var from_cell := _grid.world_to_cell(from_world)
	var to_cell := _grid.world_to_cell(to_world)
	if not _grid.is_navigable_cell(from_cell) or not _grid.is_navigable_cell(to_cell):
		return true
	return _has_clear_path(from_world, to_world)


func path_as_world_array(from_world: Vector3, to_world: Vector3) -> Array[Vector3]:
	var path := find_path_world(from_world, to_world)
	var points: Array[Vector3] = []
	for i in range(path.size()):
		if i == 0 and from_world.distance_to(path[i]) <= ARRIVE_DISTANCE:
			continue
		points.append(path[i])
	return points


func find_path_world(from_world: Vector3, to_world: Vector3) -> PackedVector3Array:
	var start_cell := _grid.world_to_cell(from_world)
	var goal := _resolve_goal_world(to_world)
	var goal_cell := _grid.world_to_cell(goal)
	goal.y = _grid.walk_surface_y(goal_cell)

	if not _grid.is_navigable_cell(start_cell) or not is_walkable(start_cell):
		return PackedVector3Array()
	if not is_walkable(goal_cell):
		return PackedVector3Array()

	if _has_clear_path(from_world, goal):
		return PackedVector3Array([goal])

	var grid_path := find_path(start_cell, goal_cell)
	if grid_path.is_empty():
		return PackedVector3Array()

	return _string_pull_world(from_world, grid_path, goal)


func rebuild() -> void:
	_build_grid()
	for cell in _grid.get_blocked_cells():
		mark_blocked(cell)


func _resolve_goal_world(requested: Vector3) -> Vector3:
	var cell := _grid.world_to_cell(requested)
	if is_walkable(cell):
		return requested

	var nearest := _find_nearest_walkable_cell(cell)
	if nearest == Vector2i(-1, -1):
		return requested
	return _closest_point_on_cell(requested, nearest)


func _closest_point_on_cell(point: Vector3, cell: Vector2i) -> Vector3:
	var margin := 0.08
	return Vector3(
		clampf(point.x, float(cell.x) + margin, float(cell.x + 1) - margin),
		point.y,
		clampf(point.z, float(cell.y) + margin, float(cell.y + 1) - margin)
	)


func _find_nearest_walkable_cell(goal: Vector2i) -> Vector2i:
	for radius in range(1, 4):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var cell := goal + Vector2i(dx, dy)
				if is_walkable(cell):
					return cell
	return Vector2i(-1, -1)


func _has_clear_path(from_world: Vector3, to_world: Vector3) -> bool:
	var from_cell := _grid.world_to_cell(from_world)
	var to_cell := _grid.world_to_cell(to_world)
	for cell in _cells_along_line(from_cell, to_cell):
		if not is_walkable(cell):
			return false
	return true


func _cells_along_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
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


func _string_pull_world(
	from_world: Vector3,
	grid_path: PackedVector2Array,
	goal_world: Vector3
) -> PackedVector3Array:
	var points: Array[Vector3] = []
	for point: Vector2 in grid_path:
		var cell := _grid.world_to_cell(Vector3(point.x, 0.0, point.y))
		points.append(Vector3(point.x, _grid.walk_surface_y(cell), point.y))

	if points.is_empty():
		return PackedVector3Array([goal_world])

	var result := PackedVector3Array()
	result.append(from_world)

	var current := 0
	while current < points.size():
		var chosen := current
		var anchor := result[result.size() - 1]
		for index in range(points.size() - 1, current - 1, -1):
			if _has_clear_path(anchor, points[index]):
				chosen = index
				break
		result.append(points[chosen])
		current = chosen + 1

	var last := result[result.size() - 1]
	if last.distance_to(goal_world) > ARRIVE_DISTANCE:
		result.append(goal_world)

	return result
