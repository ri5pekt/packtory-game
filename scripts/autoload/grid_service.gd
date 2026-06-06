class_name WarehouseGrid
extends Node

const WarehousePlaceableScript = preload("res://scripts/warehouse/warehouse_placeable.gd")

## Authoritative cell model for the whole lot.
##
## Layout (rows run south as y increases):
##   [grass margin] [warehouse 12x12] [apron + walkway] [sidewalk][road][sidewalk] [grass margin]
## A north-south walkway joins the warehouse entrance to the road-side sidewalk.

const CELL_SIZE := 1.0
const WAREHOUSE_SIZE := Vector2i(12, 12)
const GROUND_PADDING := 11

# Rows from the south wall line to the first road row (includes apron, walkway, sidewalk).
const ROAD_GAP_ROWS := 2
const DECORATIVE_ROAD_LANE_COUNT := 2
const DECORATIVE_ROAD_ROW := GROUND_PADDING + WAREHOUSE_SIZE.y + ROAD_GAP_ROWS
# Walkable tops of ground meshes when tile origins sit at y = 0 (from GLB bounds).
const GROUND_TILE_SURFACE_Y := 0.06
const WAREHOUSE_FLOOR_SURFACE_Y := 0.10

# Starter Kit tiles are thin (~0.06 m tall); props/cars sit just on top.
const DECORATIVE_ROAD_SURFACE_Y := GROUND_TILE_SURFACE_Y + 0.01

const DECORATIVE_SIDEWALK_NORTH_ROW := DECORATIVE_ROAD_ROW - 1
const DECORATIVE_SIDEWALK_SOUTH_ROW := DECORATIVE_ROAD_ROW + DECORATIVE_ROAD_LANE_COUNT
const DECORATIVE_SIDEWALK_SURFACE_Y := GROUND_TILE_SURFACE_Y + 0.01

# Entrance: which 2 m south-wall module is the doorway, and the walkway it feeds.
const ENTRANCE_MODULE_INDEX := 2
const ENTRANCE_COL_A := GROUND_PADDING + ENTRANCE_MODULE_INDEX * 2
const ENTRANCE_COL_B := ENTRANCE_COL_A + 1
const WALKWAY_NORTH_ROW := GROUND_PADDING + WAREHOUSE_SIZE.y
const WALKWAY_SOUTH_ROW := DECORATIVE_SIDEWALK_SOUTH_ROW

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
var _wall_cells: Dictionary = {}
var _furniture_cells: Dictionary = {}

var warehouse_origin: Vector2i:
	get:
		return Vector2i(GROUND_PADDING, GROUND_PADDING)


var total_size: Vector2i:
	get:
		return WAREHOUSE_SIZE + Vector2i(GROUND_PADDING * 2, GROUND_PADDING * 2)


func walk_surface_y(cell: Vector2i) -> float:
	if is_entrance_crosswalk_cell(cell):
		return DECORATIVE_ROAD_SURFACE_Y
	if is_warehouse_floor_cell(cell):
		return WAREHOUSE_FLOOR_SURFACE_Y
	if is_decorative_walkway_cell(cell):
		return WAREHOUSE_FLOOR_SURFACE_Y
	if is_decorative_road_cell(cell) or is_dock_road_connector_cell(cell):
		return DECORATIVE_ROAD_SURFACE_Y
	if is_decorative_sidewalk_cell(cell):
		return DECORATIVE_SIDEWALK_SURFACE_Y
	return GROUND_TILE_SURFACE_Y


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		(cell.x + 0.5) * CELL_SIZE,
		walk_surface_y(cell),
		(cell.y + 0.5) * CELL_SIZE
	)


func world_on_surface(x: float, z: float) -> Vector3:
	var cell := Vector2i(floori(x), floori(z))
	return Vector3(x, walk_surface_y(cell), z)


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
	register_wall_cell(cell)


func register_wall_cell(cell: Vector2i) -> void:
	if is_warehouse_cell(cell):
		_wall_cells[cell] = true
		_blocked_cells[cell] = true


func is_wall_perimeter_cell(cell: Vector2i) -> bool:
	return _wall_cells.has(cell)


func register_furniture_cell(cell: Vector2i) -> void:
	_furniture_cells[cell] = true


func unregister_furniture_cell(cell: Vector2i) -> void:
	_furniture_cells.erase(cell)


func is_furniture_cell(cell: Vector2i) -> bool:
	return _furniture_cells.has(cell)


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
	if _wall_cells.has(cell):
		return
	if not _blocked_cells.erase(cell):
		return
	if pathfinding != null:
		pathfinding.mark_unblocked(cell)
	navigation_changed.emit()


func is_cell_blocked(cell: Vector2i) -> bool:
	return _blocked_cells.has(cell)


func can_occupy_cells(cells: Array[Vector2i], ignore_cells: Array[Vector2i] = []) -> bool:
	return WarehousePlaceableScript.can_occupy(self, cells, ignore_cells)


func get_blocked_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _blocked_cells.keys():
		cells.append(cell)
	return cells


func is_warehouse_border_cell(cell: Vector2i) -> bool:
	if is_warehouse_cell(cell) or _is_paved_anchor_cell(cell):
		return false
	# Apron ring stops at the south sidewalk — grass continues beyond that band.
	if cell.y > DECORATIVE_SIDEWALK_SOUTH_ROW:
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if _is_paved_anchor_cell(cell + Vector2i(dx, dy)):
				return true
	return false


func _is_paved_anchor_cell(cell: Vector2i) -> bool:
	return (
		_is_core_warehouse_floor_cell(cell)
		or is_entrance_apron_cell(cell)
		or is_decorative_walkway_cell(cell)
	)


func _is_core_warehouse_floor_cell(cell: Vector2i) -> bool:
	return (
		is_warehouse_cell(cell)
		or is_south_threshold_cell(cell)
		or is_dock_cell(cell)
		or is_back_door_connector_cell(cell)
	)


func is_decorative_road_cell(cell: Vector2i) -> bool:
	if is_warehouse_cell(cell):
		return false
	if is_entrance_crosswalk_cell(cell):
		return false
	return (
		cell.y >= DECORATIVE_ROAD_ROW
		and cell.y < DECORATIVE_ROAD_ROW + DECORATIVE_ROAD_LANE_COUNT
	)


## Paved spur from the loading dock down to the main road (stops before the E-W band).
func is_dock_road_connector_cell(cell: Vector2i) -> bool:
	if cell.x != DOCK_ROAD_COL:
		return false
	return cell.y > DOCK_SOUTH_ROW + 2 and cell.y < DECORATIVE_ROAD_ROW


func is_decorative_sidewalk_cell(cell: Vector2i) -> bool:
	if is_warehouse_cell(cell):
		return false
	if is_decorative_road_cell(cell):
		return false
	return (
		cell.y == DECORATIVE_SIDEWALK_NORTH_ROW
		or cell.y == DECORATIVE_SIDEWALK_SOUTH_ROW
	)


func is_south_threshold_cell(cell: Vector2i) -> bool:
	var south_row := warehouse_origin.y + WAREHOUSE_SIZE.y
	return (
		cell.y == south_row
		and cell.x >= warehouse_origin.x
		and cell.x < warehouse_origin.x + WAREHOUSE_SIZE.x
	)


## South lip under the south wall and the entrance walkway use the same Kenney
## floor height as the interior so tiles meet flush at the doorway (no sky gaps).
func is_entrance_door_floor_cell(cell: Vector2i) -> bool:
	if cell.x != ENTRANCE_COL_A and cell.x != ENTRANCE_COL_B:
		return false
	return cell.y == warehouse_origin.y + WAREHOUSE_SIZE.y


func is_warehouse_interior_edge_cell(cell: Vector2i) -> bool:
	if not is_warehouse_cell(cell):
		return false
	var relative := cell - warehouse_origin
	return (
		relative.x == 0
		or relative.y == 0
		or relative.x == WAREHOUSE_SIZE.x - 1
		or relative.y == WAREHOUSE_SIZE.y - 1
	)


func is_warehouse_south_edge_cell(cell: Vector2i) -> bool:
	if not is_warehouse_cell(cell):
		return false
	return (cell - warehouse_origin).y == WAREHOUSE_SIZE.y - 1


func uses_interior_warehouse_floor(cell: Vector2i) -> bool:
	# Light interior tile only inside the warehouse shell (not the doorway lip).
	return is_warehouse_cell(cell)


## Kenney floor + dark apron (interior, walkway, dock pad, apron ring + corner fill).
## Decorative road/sidewalk bands use ground tiles only — never double-stack apron here.
func is_warehouse_floor_cell(cell: Vector2i) -> bool:
	if (
		is_decorative_road_cell(cell)
		or is_entrance_crosswalk_cell(cell)
		or is_decorative_sidewalk_cell(cell)
		or is_dock_road_connector_cell(cell)
	):
		return false
	if is_warehouse_cell(cell) or is_entrance_door_floor_cell(cell):
		return true
	if is_entrance_apron_cell(cell):
		return true
	if is_south_threshold_cell(cell):
		return true
	if is_dock_cell(cell) or is_back_door_connector_cell(cell):
		return true
	if is_dock_apron_cell(cell):
		return true
	if is_warehouse_border_cell(cell):
		return true
	if is_warehouse_border_padding_cell(cell):
		return true
	return false


## Diagonal wedges beside the apron ring (e.g. front-left of the entrance).
func is_warehouse_border_padding_cell(cell: Vector2i) -> bool:
	if is_warehouse_cell(cell) or _is_paved_anchor_cell(cell):
		return false
	if cell.y > DECORATIVE_SIDEWALK_SOUTH_ROW:
		return false
	if is_warehouse_border_cell(cell):
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if is_warehouse_border_cell(cell + Vector2i(dx, dy)):
				return true
	return false


func get_warehouse_floor_cells() -> Array[Vector2i]:
	var cells: Dictionary = {}
	for x in range(total_size.x):
		for y in range(total_size.y):
			var cell := Vector2i(x, y)
			if is_warehouse_floor_cell(cell):
				cells[cell] = true
	var ordered: Array[Vector2i] = []
	for cell in cells:
		ordered.append(cell)
	return ordered


func is_decorative_walkway_cell(cell: Vector2i) -> bool:
	if not is_entrance_path_column(cell.x):
		return false
	return cell.y >= WALKWAY_NORTH_ROW and cell.y <= DECORATIVE_SIDEWALK_SOUTH_ROW


func is_entrance_path_column(col: int) -> bool:
	return col == ENTRANCE_COL_A or col == ENTRANCE_COL_B


## Pavement strip across the road at the warehouse entrance (disabled — road runs through).
func is_entrance_crosswalk_cell(_cell: Vector2i) -> bool:
	return false


## Raised Kenney apron from the doorway through the north sidewalk (entrance columns only).
func is_entrance_apron_cell(cell: Vector2i) -> bool:
	if not is_entrance_path_column(cell.x):
		return false
	if is_entrance_crosswalk_cell(cell):
		return false
	return cell.y >= WALKWAY_NORTH_ROW and cell.y <= DECORATIVE_SIDEWALK_NORTH_ROW


func is_dock_apron_cell(cell: Vector2i) -> bool:
	# Dock + back-door connector + paved surround for trucks and the delivery van.
	return (
		cell.x >= BACK_DOOR_CONNECTOR_COL
		and cell.x <= DOCK_EAST_COL + 2
		and cell.y >= DOCK_NORTH_ROW - 1
		and cell.y <= DOCK_SOUTH_ROW + 2
	)


func is_warehouse_perimeter_sidewalk_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	var o := warehouse_origin
	var s := WAREHOUSE_SIZE
	var x_min := o.x - 1
	var x_max := o.x + s.x
	var y_min := o.y - 1
	var y_max := o.y + s.y
	var on_ns := (cell.y == y_min or cell.y == y_max) and cell.x >= x_min and cell.x <= x_max
	var on_we := (cell.x == x_min or cell.x == x_max) and cell.y >= y_min and cell.y <= y_max
	if not (on_ns or on_we):
		return false
	# East back-door rows are navigable connector cells, not sidewalk
	if cell.x == x_max and (cell.y == BACK_DOOR_ROW_A or cell.y == BACK_DOOR_ROW_B):
		return false
	# Don't override dock apron tiles
	if is_dock_apron_cell(cell):
		return false
	return true


func get_warehouse_perimeter_corners() -> Array[Vector2i]:
	var o := warehouse_origin
	var s := WAREHOUSE_SIZE
	var corners: Array[Vector2i] = [
		Vector2i(o.x - 1, o.y - 1),
		Vector2i(o.x + s.x, o.y - 1),
		Vector2i(o.x - 1, o.y + s.y),
		Vector2i(o.x + s.x, o.y + s.y),
	]
	return corners


func is_paved_cell(cell: Vector2i) -> bool:
	return (
		is_decorative_road_cell(cell)
		or is_entrance_crosswalk_cell(cell)
		or is_dock_road_connector_cell(cell)
		or is_decorative_sidewalk_cell(cell)
		or is_decorative_walkway_cell(cell)
		or is_dock_apron_cell(cell)
		or is_warehouse_perimeter_sidewalk_cell(cell)
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
	# From the warehouse doorway to the far-side sidewalk across the road.
	var near_z := (float(WALKWAY_NORTH_ROW) + 0.4) * CELL_SIZE
	var far_z := get_decorative_sidewalk_z(1)
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
