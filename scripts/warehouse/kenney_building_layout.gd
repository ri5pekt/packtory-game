class_name KenneyBuildingLayout
extends RefCounted

## Kenney building-kit geometry for the warehouse shell.
##
## Wall pieces share a 2 m module: 0.1 m thick along local X, 2 m wide along local
## Z, 2.4 m tall (wall-low is 1.2 m). A piece with no Y rotation runs along Z, so
## west/east walls place it as-is and north/south walls rotate it 90 degrees.
## floor-quarter.glb is a flat 1 m floor tile (origin on the +Z edge — see FLOOR_MESH_CENTER_OFFSET).

const MODELS := "res://blender/assets/kenney_building-kit/Models/GLB format/"

const FLOOR_PATH := MODELS + "floor-quarter.glb"
const WALL_PATH := MODELS + "wall.glb"
const WALL_LOW_PATH := MODELS + "wall-low.glb"
const WALL_CORNER_PATH := MODELS + "wall-corner.glb"
const WALL_CORNER_COLUMN_PATH := MODELS + "wall-corner-column.glb"
const WINDOW_SQUARE_PATH := MODELS + "wall-window-square.glb"
const WINDOW_ROUND_PATH := MODELS + "wall-window-round.glb"
const DOORWAY_PATH := MODELS + "wall-doorway-square.glb"
const COLUMN_PATH := MODELS + "column.glb"
const COLUMN_WIDE_PATH := MODELS + "column-wide.glb"
const COLUMN_BASE_MAX_Y := 0.4

const MODULE := 2.0
const FLOOR_TILE_SCALE := 1.0
## floor-quarter.glb is 1 m wide but its origin is on the tile's +Z edge, not the center
## (mesh AABB center ≈ (0, 0.05, -0.5)). Subtract this so the tile covers the cell.
const FLOOR_MESH_CENTER_OFFSET := Vector3(0.0, 0.0, -0.5)
## Legacy inset kept for reference if edge seams return at scale 1.0.
const FLOOR_EDGE_TILE_SCALE := 0.994
## Walls are centered on the tile boundary (the light-interior / dark-apron seam)
## so the 0.1 m-thick wall covers the floor tiles' slight overhang on BOTH sides.
## A non-zero inset left a sliver of interior floor poking out past the wall.
const WALL_HALF_THICK := 0.0


static func floor_tile_transform(cell: Vector2i, tile_scale: float = FLOOR_TILE_SCALE) -> Transform3D:
	var origin := Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)
	origin -= FLOOR_MESH_CENTER_OFFSET * tile_scale
	return Transform3D(Basis.from_scale(Vector3.ONE * tile_scale), origin)


static func module_center(origin: float, module_index: int) -> float:
	return origin + 1.0 + float(module_index) * MODULE


static func west_wall_line_x(origin_x: float) -> float:
	return origin_x + WALL_HALF_THICK


static func east_wall_line_x(origin_x: float, size_x: int) -> float:
	return origin_x + float(size_x) - WALL_HALF_THICK


static func north_wall_line_z(origin_z: float) -> float:
	return origin_z + WALL_HALF_THICK


static func south_wall_line_z(origin_z: float, size_y: int) -> float:
	return origin_z + float(size_y) - WALL_HALF_THICK


static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)


## Wall module running along Z (west and east walls): no rotation needed.
static func z_run_transform(line_x: float, center_z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(line_x, 0.0, center_z))


## Wall module running along X (north and south walls): rotate the Z-facing piece.
static func x_run_transform(center_x: float, line_z: float) -> Transform3D:
	var basis := Basis.from_euler(Vector3(0.0, deg_to_rad(90.0), 0.0))
	return Transform3D(basis, Vector3(center_x, 0.0, line_z))


static func northwest_corner_transform(origin: Vector2i) -> Transform3D:
	return Transform3D(
		Basis.IDENTITY,
		Vector3(west_wall_line_x(float(origin.x)), 0.0, north_wall_line_z(float(origin.y)))
	)


static func northeast_corner(origin: Vector2i, size: Vector2i) -> Vector3:
	return Vector3(
		east_wall_line_x(float(origin.x), size.x),
		0.0,
		north_wall_line_z(float(origin.y))
	)


static func southwest_corner(origin: Vector2i, size: Vector2i) -> Vector3:
	return Vector3(
		west_wall_line_x(float(origin.x)),
		0.0,
		south_wall_line_z(float(origin.y), size.y)
	)


static func southeast_corner(origin: Vector2i, size: Vector2i) -> Vector3:
	return Vector3(
		east_wall_line_x(float(origin.x), size.x),
		0.0,
		south_wall_line_z(float(origin.y), size.y)
	)


static func column_transform(corner: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, corner)
