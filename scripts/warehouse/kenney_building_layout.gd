class_name KenneyBuildingLayout
extends RefCounted

## Kenney building-kit geometry for the warehouse shell.
##
## Wall pieces share a 2 m module: 0.1 m thick along local X, 2 m wide along local
## Z, 2.4 m tall (wall-low is 1.2 m). A piece with no Y rotation runs along Z, so
## west/east walls place it as-is and north/south walls rotate it 90 degrees.
## floor-quarter.glb is a flat 1 m floor tile.

const MODELS := "res://blender/assets/kenney_building-kit/Models/GLB format/"

const FLOOR_PATH := MODELS + "floor-quarter.glb"
const WALL_PATH := MODELS + "wall.glb"
const WALL_LOW_PATH := MODELS + "wall-low.glb"
const WINDOW_SQUARE_PATH := MODELS + "wall-window-square.glb"
const WINDOW_ROUND_PATH := MODELS + "wall-window-round.glb"
const DOORWAY_PATH := MODELS + "wall-doorway-square.glb"
const COLUMN_PATH := MODELS + "column.glb"

const MODULE := 2.0
const FLOOR_TILE_SCALE := 1.004


static func floor_tile_transform(cell: Vector2i) -> Transform3D:
	var origin := Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)
	return Transform3D(Basis.from_scale(Vector3.ONE * FLOOR_TILE_SCALE), origin)


static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)


## Wall module running along Z (west and east walls): no rotation needed.
static func z_run_transform(line_x: float, center_z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(line_x, 0.0, center_z))


## Wall module running along X (north and south walls): rotate the Z-facing piece.
static func x_run_transform(center_x: float, line_z: float) -> Transform3D:
	var basis := Basis.from_euler(Vector3(0.0, deg_to_rad(90.0), 0.0))
	return Transform3D(basis, Vector3(center_x, 0.0, line_z))


static func column_transform(corner: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, corner)
