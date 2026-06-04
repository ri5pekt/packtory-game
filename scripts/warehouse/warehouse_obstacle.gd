class_name WarehouseObstacle
extends Node

var _grid: WarehouseGrid
var _cells: Array[Vector2i] = []


func occupy(cells: Array[Vector2i]) -> void:
	if _grid == null:
		_grid = get_node("/root/GridService") as WarehouseGrid
	for cell in cells:
		if cell in _cells:
			continue
		_cells.append(cell)
		_grid.block_cell(cell)


func release() -> void:
	if _grid == null:
		_cells.clear()
		return
	for cell in _cells:
		_grid.unblock_cell(cell)
	_cells.clear()


func _exit_tree() -> void:
	release()
