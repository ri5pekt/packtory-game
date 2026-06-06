extends Node3D

## Places the packing table inside the warehouse.

const PackingTableScript = preload("res://scripts/warehouse/packing_table.gd")

# North work zone, centred above the queue lane (footprint covers x15-17 at z12).
const TABLE_CELL := Vector2i(16, 12)
const TABLE_YAW := 0.0

var _grid: WarehouseGrid


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_spawn_table()


func _spawn_table() -> void:
	if not _grid.is_warehouse_cell(TABLE_CELL):
		push_error("PackingTableSpawn: cell %s is outside warehouse" % TABLE_CELL)
		return

	var table: PackingTable = PackingTableScript.new()
	table.name = "PackingTable"
	table.add_to_group("packing_tables")
	add_child(table)
	table.setup(_grid.cell_to_world(TABLE_CELL), TABLE_YAW)
