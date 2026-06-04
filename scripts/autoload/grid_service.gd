class_name WarehouseGrid
extends Node

## Authoritative cell model for the whole lot.
##
## Layout (rows run south as y increases):
##   [grass margin] [warehouse 12x12] [grass yard] [sidewalk][road][sidewalk] [grass margin]
## A north-south walkway joins the warehouse entrance to the road-side sidewalk.

const CELL_SIZE := 1.0
const WAREHOUSE_SIZE := Vector2i(12, 12)
const GROUND_PADDING := 11

# Decorative road sits well south of the warehouse, across the grass yard.
const ROAD_GAP_ROWS := 5
const DECORATIVE_ROAD_LANE_COUNT := 2
const DECORATIVE_ROAD_ROW := GROUND_PADDING + WAREHOUSE_SIZE.y + ROAD_GAP_ROWS
# Starter Kit tiles are thin (~0.06 m tall); props/cars sit just on top.
const DECORATIVE_ROAD_SURFACE_Y := 0.07

const DECORATIVE_SIDEWALK_NORTH_ROW := DECORATIVE_ROAD_ROW - 1
const DECORATIVE_SIDEWALK_SOUTH_ROW := DECORATIVE_ROAD_ROW + DECORATIVE_ROAD_LANE_COUNT
const DECORATIVE_SIDEWALK_SURFACE_Y := 0.07

# Entrance: which 2 m south-wall module is the doorway, and the walkway it feeds.
const ENTRANCE_MODULE_INDEX := 2
const ENTRANCE_COL_A := GROUND_PADDING + ENTRANCE_MODULE_INDEX * 2
const ENTRANCE_COL_B := ENTRANCE_COL_A + 1
const WALKWAY_NORTH_ROW := GROUND_PADDING + WAREHOUSE_SIZE.y
const WALKWAY_SOUTH_ROW := DECORATIVE_SIDEWALK_NORTH_ROW - 1

# --- Loading dock (east of the warehouse, reached via a back door in the east
# wall). The dock + connector are navigable so the manager can walk out to it. ---
const EAST_DOOR_MODULE_INDEX := 2          # which 2 m east-wall module is the door
const BACK_DOOR_ROW_A := 15
const BACK_DOOR_ROW_B := 16
const BACK_DOOR_CONNECTOR_COL := GROUND_PADDING + WAREHOUSE_SIZE.x  # just outside the east wall (23)
const DOCK_WEST_COL := BACK_DOOR_CONNECTOR_COL + 1   # 24
const DOCK_EAST_COL := DOCK_WEST_COL + 2             # 26 (3 cells wide)
const DOCK_NORTH_ROW := 14
const DOCK_SOUTH_ROW := 17
const DOCK_ROAD_COL := DOCK_EAST_COL + 1             # east-side spur to the main road

signal navigation_changed

var pathfinding: Pathfinding

var _blocked_cells: Dictionary = {}

var warehouse_origin: Vector2i:
	get:
		return Vector2i(GROUND_PADDING, GROUND_PADDING)


var total_size: Vector2i:
	get:
		return WAREHOUSE_SIZE + Vector2i(GROUND_PADDING * 2, GROUND_PADDING * 2)


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		(cell.x + 0.5) * CELL_SIZE,
		0.0,
		(cell.y + 0.5) * CELL_SIZE
	)


func world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(floori(world.x / CELL_SIZE), floori(world.z / CELL_SIZE))


func is_in_bounds(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < total_size.x
		and cell.y < total_size.y
	)


func is_warehouse_cell(cell: Vector2i) -> bool:
	var relative := cell - warehouse_origin
	return (
		relative.x >= 0
		and relative.y >= 0
		and relative.x < WAREHOUSE_SIZE.x
		and relative.y < WAREHOUSE_SIZE.y
	)


func register_blocked_cell(cell: Vector2i) -> void:
	if is_warehouse_cell(cell):
		_blocked_cells[cell] = true


func block_cell(cell: Vector2i) -> void:
	if not is_warehouse_cell(cell):
		return
	if _blocked_cells.has(cell):
		return
	_blocked_cells[cell] = true
	if pathfinding != null:
		pathfinding.mark_blocked(cell)
	navigation_changed.emit()


func unblock_cell(cell: Vector2i) -> void:
	if not _blocked_cells.erase(cell):
		return
	if pathfinding != null:
		pathfinding.mark_unblocked(cell)
	navigation_changed.emit()


func is_cell_blocked(cell: Vector2i) -> bool:
	return _blocked_cells.has(cell)


func get_blocked_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _blocked_cells.keys():
		cells.append(cell)
	return cells


func is_warehouse_border_cell(cell: Vector2i) -> bool:
	if is_warehouse_cell(cell):
		return false
	if is_decorative_walkway_cell(cell):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if is_warehouse_cell(cell + Vector2i(dx, dy)):
				return true
	return false


func is_decorative_road_cell(cell: Vector2i) -> bool:
	if is_warehouse_cell(cell) or is_warehouse_border_cell(cell):
		return false
	return (
		cell.y >= DECORATIVE_ROAD_ROW
		and cell.y < DECORATIVE_ROAD_ROW + DECORATIVE_ROAD_LANE_COUNT
	)


## Paved spur from the main road up the east lot edge to the loading dock.
func is_dock_road_connector_cell(cell: Vector2i) -> bool:
	if cell.x != DOCK_ROAD_COL:
		return false
	return (
		cell.y > DOCK_SOUTH_ROW + 2
		and cell.y <= DECORATIVE_ROAD_ROW + DECORATIVE_ROAD_LANE_COUNT - 1
	)


func is_decorative_sidewalk_cell(cell: Vector2i) -> bool:
	if is_warehouse_cell(cell) or is_warehouse_border_cell(cell):
		return false
	if is_decorative_road_cell(cell):
		return false
	return (
		cell.y == DECORATIVE_SIDEWALK_NORTH_ROW
		or cell.y == DECORATIVE_SIDEWALK_SOUTH_ROW
	)


func is_decorative_walkway_cell(cell: Vector2i) -> bool:
	if cell.x != ENTRANCE_COL_A and cell.x != ENTRANCE_COL_B:
		return false
	return cell.y >= WALKWAY_NORTH_ROW and cell.y <= WALKWAY_SOUTH_ROW


func is_dock_apron_cell(cell: Vector2i) -> bool:
	# Dock + back-door connector + a little surround for the truck.
	return (
		cell.x >= BACK_DOOR_CONNECTOR_COL
		and cell.x <= DOCK_EAST_COL + 1
		and cell.y >= DOCK_NORTH_ROW - 1
		and cell.y <= DOCK_SOUTH_ROW + 2
	)


func is_paved_cell(cell: Vector2i) -> bool:
	return (
		is_decorative_road_cell(cell)
		or is_dock_road_connector_cell(cell)
		or is_decorative_sidewalk_cell(cell)
		or is_decorative_walkway_cell(cell)
		or is_dock_apron_cell(cell)
	)


func is_grass_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	if is_warehouse_cell(cell):
		return false
	if is_paved_cell(cell):
		return false
	return not is_warehouse_border_cell(cell)


func get_decorative_road_lane_z(lane_index: int) -> float:
	var clamped_lane := clampi(lane_index, 0, DECORATIVE_ROAD_LANE_COUNT - 1)
	return (float(DECORATIVE_ROAD_ROW + clamped_lane) + 0.5) * CELL_SIZE


func get_decorative_road_lane_position(lane_index: int) -> Vector3:
	return Vector3(0.0, DECORATIVE_ROAD_SURFACE_Y, get_decorative_road_lane_z(lane_index))


func get_decorative_road_x_bounds() -> Vector2:
	return Vector2(-1.0, float(total_size.x) + 1.0)


func get_decorative_sidewalk_z(side: int) -> float:
	var row := (
		DECORATIVE_SIDEWALK_NORTH_ROW
		if side == 0
		else DECORATIVE_SIDEWALK_SOUTH_ROW
	)
	return (float(row) + 0.5) * CELL_SIZE


func get_decorative_sidewalk_position(side: int) -> Vector3:
	return Vector3(0.0, DECORATIVE_SIDEWALK_SURFACE_Y, get_decorative_sidewalk_z(side))


func get_walkway_x() -> float:
	return (float(ENTRANCE_COL_A) + float(ENTRANCE_COL_B) + 1.0) * 0.5 * CELL_SIZE


func get_walkway_z_bounds() -> Vector2:
	# From just outside the entrance to the road-side sidewalk centre.
	var near_z := (float(WALKWAY_NORTH_ROW) + 0.4) * CELL_SIZE
	var far_z := get_decorative_sidewalk_z(0)
	return Vector2(near_z, far_z)


func get_entrance_world() -> Vector3:
	# Interior receiving spot a few cells inside the south doorway.
	var cell := Vector2i(ENTRANCE_COL_A, warehouse_origin.y + WAREHOUSE_SIZE.y - 3)
	return cell_to_world(cell)


func get_warehouse_center_world() -> Vector3:
	var center_cell := warehouse_origin + WAREHOUSE_SIZE / 2
	return cell_to_world(center_cell)


# --- Loading dock navigation ---------------------------------------------------

func is_dock_cell(cell: Vector2i) -> bool:
	return (
		cell.x >= DOCK_WEST_COL and cell.x <= DOCK_EAST_COL
		and cell.y >= DOCK_NORTH_ROW and cell.y <= DOCK_SOUTH_ROW
	)


func is_back_door_connector_cell(cell: Vector2i) -> bool:
	return (
		cell.x == BACK_DOOR_CONNECTOR_COL
		and (cell.y == BACK_DOOR_ROW_A or cell.y == BACK_DOOR_ROW_B)
	)


## Cells the manager (not customers) may path through: interior + back door + dock.
func is_navigable_cell(cell: Vector2i) -> bool:
	return (
		is_warehouse_cell(cell)
		or is_back_door_connector_cell(cell)
		or is_dock_cell(cell)
	)


## Interior cells just inside the east back door (kept unblocked by the wall).
func back_door_interior_cells() -> Array[Vector2i]:
	var col := warehouse_origin.x + WAREHOUSE_SIZE.x - 1  # east edge interior col (22)
	return [Vector2i(col, BACK_DOOR_ROW_A), Vector2i(col, BACK_DOOR_ROW_B)]


## Bounding rect (in cells) that the pathfinding grid must cover.
func navigable_region() -> Rect2i:
	return Rect2i(
		Vector2i(GROUND_PADDING, GROUND_PADDING),
		Vector2i(DOCK_EAST_COL - GROUND_PADDING + 1, WAREHOUSE_SIZE.y)
	)


func clamp_world_to_navigable(world: Vector3) -> Vector3:
	var region := navigable_region()
	var margin := 0.08
	return Vector3(
		clampf(world.x, float(region.position.x) + margin, float(region.end.x) - margin),
		world.y,
		clampf(world.z, float(region.position.y) + margin, float(region.end.y) - margin)
	)


func get_dock_world() -> Vector3:
	var center := Vector2i((DOCK_WEST_COL + DOCK_EAST_COL) / 2, (DOCK_NORTH_ROW + DOCK_SOUTH_ROW) / 2)
	return cell_to_world(center)


func get_dock_road_junction_world() -> Vector3:
	var cell := Vector2i(
		DOCK_ROAD_COL,
		DECORATIVE_ROAD_ROW + int(DECORATIVE_ROAD_LANE_COUNT / 2)
	)
	var world := cell_to_world(cell)
	world.y = DECORATIVE_ROAD_SURFACE_Y
	return world
