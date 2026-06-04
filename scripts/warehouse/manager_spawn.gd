extends Node3D

const WORKER_SCENE := preload("res://scenes/worker/worker.tscn")

var _grid: WarehouseGrid


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_spawn_manager()


func _spawn_manager() -> void:
	var manager: Worker = WORKER_SCENE.instantiate()
	manager.name = "Manager"
	# Work zone, west of the queue lane and its rails.
	manager.position = _grid.cell_to_world(Vector2i(13, 16))
	manager.rotation_degrees.y = 180.0
	add_child(manager)
