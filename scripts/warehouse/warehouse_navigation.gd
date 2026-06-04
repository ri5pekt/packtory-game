extends Node

var _grid: WarehouseGrid


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	call_deferred("_build_pathfinding")


func _build_pathfinding() -> void:
	_grid.pathfinding = Pathfinding.new(_grid)
