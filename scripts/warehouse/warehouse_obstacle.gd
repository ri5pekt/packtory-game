class_name WarehouseObstacle
extends Node

var _grid: WarehouseGrid
var _cells: Array[Vector2i] = []


func occupy(cells: Array[Vector2i]) -> void:
	_ensure_grid()
	if _grid == null:
		return
	for cell in cells:
		if cell in _cells:
			continue
		_cells.append(cell)
		_grid.register_furniture_cell(cell)
		if not _grid.is_wall_perimeter_cell(cell):
			_grid.block_cell(cell)


func _ensure_grid() -> void:
	if _grid != null:
		return
	if is_inside_tree():
		_grid = get_tree().root.get_node_or_null("GridService") as WarehouseGrid
	if _grid == null and Engine.is_editor_hint():
		_grid = get_node_or_null("/root/GridService") as WarehouseGrid


func release() -> void:
	if _grid == null:
		_cells.clear()
		return
	for cell in _cells:
		_grid.unregister_furniture_cell(cell)
		if not _grid.is_wall_perimeter_cell(cell):
			_grid.unblock_cell(cell)
	_cells.clear()


func _exit_tree() -> void:
	release()
