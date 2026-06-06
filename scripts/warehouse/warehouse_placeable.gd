class_name WarehousePlaceable
extends RefCounted

## Shared grid placement helpers for warehouse edit mode.


static func yaw_steps(yaw_deg: float) -> int:
	return int(round(yaw_deg / 90.0)) % 4


static func rotate_offset(offset: Vector2i, steps: int) -> Vector2i:
	var result := offset
	var turns := ((steps % 4) + 4) % 4
	for _i in range(turns):
		result = Vector2i(-result.y, result.x)
	return result


static func rotated_footprint(
	anchor_cell: Vector2i,
	offsets: Array[Vector2i],
	yaw_deg: float
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var steps := yaw_steps(yaw_deg)
	for offset in offsets:
		cells.append(anchor_cell + rotate_offset(offset, steps))
	return cells


static func can_occupy(
	grid: WarehouseGrid,
	cells: Array[Vector2i],
	ignore_cells: Array[Vector2i] = []
) -> bool:
	if grid == null or cells.is_empty():
		return false
	var ignore: Dictionary = {}
	for cell in ignore_cells:
		ignore[cell] = true
	for cell in cells:
		if not grid.is_warehouse_cell(cell):
			return false
		if ignore.has(cell):
			continue
		if grid.is_furniture_cell(cell):
			return false
		if grid.is_cell_blocked(cell):
			if grid.is_wall_perimeter_cell(cell):
				continue
			return false
	return true


static func cells_overlap(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	var lookup: Dictionary = {}
	for cell in a:
		lookup[cell] = true
	for cell in b:
		if lookup.has(cell):
			return true
	return false


static func is_placeable(node: Node) -> bool:
	return (
		node != null
		and node.is_in_group("warehouse_placeables")
		and node.has_method("get_anchor_cell")
		and node.has_method("apply_placement")
	)
