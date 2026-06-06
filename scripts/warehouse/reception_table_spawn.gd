extends Node3D

## Places the reception counter that anchors the customer queue lane.

const ReceptionTableScript = preload("res://scripts/warehouse/reception_table.gd")

# Default desk cell; queue slots follow the desk's child markers when moved in edit mode.
const TABLE_CELL := Vector2i(16, 15)
const TABLE_YAW := 0.0

var _grid: WarehouseGrid


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_spawn_table()


func _spawn_table() -> void:
	if not _grid.is_warehouse_cell(TABLE_CELL):
		push_error("ReceptionTableSpawn: cell %s is outside warehouse" % TABLE_CELL)
		return

	var table: Node3D = ReceptionTableScript.new()
	table.name = "ReceptionTable"
	add_child(table)
	table.setup(_grid.cell_to_world(TABLE_CELL), TABLE_YAW)
