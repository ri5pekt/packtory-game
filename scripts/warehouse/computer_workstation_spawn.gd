extends Node3D

## Places the office computer desk in the warehouse work zone.

const ComputerWorkstationScript = preload("res://scripts/warehouse/computer_workstation.gd")

# West-side office nook: near the manager spawn, clear of shelves and queue lane.
const WORKSTATION_CELL := Vector2i(12, 14)
const WORKSTATION_YAW := 0.0

var _grid: WarehouseGrid


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_spawn_workstation()


func _spawn_workstation() -> void:
	if not _grid.is_warehouse_cell(WORKSTATION_CELL):
		push_error("ComputerWorkstationSpawn: cell %s is outside warehouse" % WORKSTATION_CELL)
		return

	var workstation: Node3D = ComputerWorkstationScript.new()
	workstation.name = "ComputerWorkstation"
	add_child(workstation)
	workstation.setup(_grid.cell_to_world(WORKSTATION_CELL), WORKSTATION_YAW)
