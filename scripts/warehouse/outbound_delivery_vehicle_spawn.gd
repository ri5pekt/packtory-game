extends Node3D

## Spawns the player's outgoing online-order delivery van near the loading dock.

const OutboundDeliveryVehicleScript = preload(
	"res://scripts/warehouse/outbound_delivery_vehicle.gd"
)

# Northwest apron corner — parked at row 13 (one north of the delivery-box zone)
# so it doesn't share cells with the incoming truck's drop area.
const VAN_PARK_CELL := Vector2i(WarehouseGrid.DOCK_WEST_COL, WarehouseGrid.DOCK_NORTH_ROW - 1)
const VAN_YAW := 90.0

var _grid: WarehouseGrid


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_spawn_van()


func _spawn_van() -> void:
	if not _grid.is_dock_apron_cell(VAN_PARK_CELL) and not _grid.is_dock_cell(VAN_PARK_CELL):
		push_warning(
			"OutboundDeliveryVehicleSpawn: cell %s may be outside dock apron" % VAN_PARK_CELL
		)
	var van: Node3D = OutboundDeliveryVehicleScript.new()
	van.name = "OutboundDeliveryVan"
	add_child(van)
	van.setup(_grid.cell_to_world(VAN_PARK_CELL), VAN_YAW)
