extends Node3D

## Spawns three empty shelves in the north work zone. Shelves are unassigned —
## any product can be stocked on them; they self-assign when first stocked and
## become unassigned again when emptied.

const ProductShelfScript = preload("res://scripts/warehouse/product_shelf.gd")

const SHELF_CELLS := [
	Vector2i(14, 14),
	Vector2i(17, 14),
	Vector2i(20, 14),
]
const SHELF_YAW := 0.0

var _grid: WarehouseGrid


func _ready() -> void:
	add_to_group("warehouse_shelves")
	_grid = get_node("/root/GridService") as WarehouseGrid
	for cell in SHELF_CELLS:
		_spawn_shelf(cell)


func _spawn_shelf(cell: Vector2i) -> void:
	if not _grid.is_warehouse_cell(cell):
		push_error("WarehouseShelves: cell %s is outside warehouse" % cell)
		return

	var shelf: ProductShelf = ProductShelfScript.new()
	shelf.name = "Shelf_%d_%d" % [cell.x, cell.y]
	shelf.add_to_group("shelves")
	add_child(shelf)
	shelf.setup(_grid.cell_to_world(cell), SHELF_YAW)
