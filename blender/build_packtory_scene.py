"""
Build blender/packtory_warehouse.blend from the same Kenney assets used in Godot.

Run from project root:
  "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" ^
    --background --python blender/build_packtory_scene.py
"""

import math
import os
import sys

import bpy
from mathutils import Euler, Vector

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_ROOT = os.path.join(PROJECT_ROOT, "assets", "kenney")
BLEND_PATH = os.path.join(PROJECT_ROOT, "blender", "packtory_warehouse.blend")

SOURCE_FILES = {
	"grass_tile": os.path.join(ASSETS_ROOT, "grass", "roadTile_163.gltf"),
	"floor_tile": os.path.join(
		PROJECT_ROOT,
		"blender",
		"assets",
		"kenney_mini-market",
		"Models",
		"GLB format",
		"floor.glb",
	),
	"wall": os.path.join(
		PROJECT_ROOT,
		"blender",
		"assets",
		"kenney_mini-market",
		"Models",
		"GLB format",
		"wall.glb",
	),
	"wall_corner": os.path.join(
		PROJECT_ROOT,
		"blender",
		"assets",
		"kenney_mini-market",
		"Models",
		"GLB format",
		"wall-corner.glb",
	),
	"manager": os.path.join(ASSETS_ROOT, "mini-characters", "character-male-d.glb"),
}

ROT_WALL_NORTH = -90.0
ROT_WALL_WEST = 180.0
ROT_CORNER_NW = 0.0
CELL_SIZE = 1.0
WAREHOUSE_SIZE = (12, 12)
GROUND_PADDING = 8
WAREHOUSE_ORIGIN = (GROUND_PADDING, GROUND_PADDING)
TOTAL_SIZE = (
	WAREHOUSE_SIZE[0] + GROUND_PADDING * 2,
	WAREHOUSE_SIZE[1] + GROUND_PADDING * 2,
)
GRASS_TILE_UNITS = 3.0
GRASS_SCALE = 1.0 / GRASS_TILE_UNITS


def _reset_scene() -> None:
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete(use_global=False)
	for block in (
		bpy.data.meshes,
		bpy.data.materials,
		bpy.data.images,
		bpy.data.collections,
	):
		for item in list(block):
			if item.users == 0:
				block.remove(item)


def _get_or_create_collection(name: str, parent: bpy.types.Collection | None = None) -> bpy.types.Collection:
	collection = bpy.data.collections.get(name)
	if collection is None:
		collection = bpy.data.collections.new(name)
		if parent is None:
			bpy.context.scene.collection.children.link(collection)
		else:
			parent.children.link(collection)
	return collection


def _unlink_from_all_collections(obj: bpy.types.Object) -> None:
	for collection in obj.users_collection:
		collection.objects.unlink(obj)


def _move_objects_to_collection(objects: list[bpy.types.Object], collection: bpy.types.Collection) -> None:
	for obj in objects:
		_unlink_from_all_collections(obj)
		collection.objects.link(obj)


def _import_file(filepath: str) -> list[bpy.types.Object]:
	if not os.path.isfile(filepath):
		raise FileNotFoundError(f"Missing asset: {filepath}")

	before = set(bpy.data.objects)
	ext = os.path.splitext(filepath)[1].lower()
	if ext == ".glb" or ext == ".gltf":
		bpy.ops.import_scene.gltf(filepath=filepath)
	else:
		raise ValueError(f"Unsupported asset type: {filepath}")

	return [obj for obj in bpy.data.objects if obj not in before]


def _pick_root_object(imported: list[bpy.types.Object]) -> bpy.types.Object:
	meshes = [obj for obj in imported if obj.type == "MESH"]
	if len(meshes) == 1:
		return meshes[0]
	if len(meshes) > 1:
		bpy.ops.object.select_all(action="DESELECT")
		for obj in meshes:
			obj.select_set(True)
		bpy.context.view_layer.objects.active = meshes[0]
		bpy.ops.object.join()
		return bpy.context.view_layer.objects.active
	for obj in imported:
		if obj.type == "EMPTY":
			return obj
	raise RuntimeError("Import produced no usable mesh objects.")


def _import_source_asset(key: str, filepath: str, source_collection: bpy.types.Collection) -> bpy.types.Object:
	imported = _import_file(filepath)
	root = _pick_root_object(imported)
	root.name = f"SRC_{key}"
	_move_objects_to_collection([root], source_collection)
	return root


def _cell_to_world(cell_x: int, cell_y: int) -> Vector:
	return Vector(((cell_x + 0.5) * CELL_SIZE, 0.0, (cell_y + 0.5) * CELL_SIZE))


def _is_warehouse_cell(cell_x: int, cell_y: int) -> bool:
	relative_x = cell_x - WAREHOUSE_ORIGIN[0]
	relative_y = cell_y - WAREHOUSE_ORIGIN[1]
	return (
		0 <= relative_x < WAREHOUSE_SIZE[0]
		and 0 <= relative_y < WAREHOUSE_SIZE[1]
	)


def _duplicate_linked(
	source: bpy.types.Object,
	location: Vector,
	rotation_y_deg: float,
	scale: Vector,
	collection: bpy.types.Collection,
	name: str,
) -> bpy.types.Object:
	duplicate = source.copy()
	duplicate.data = source.data
	duplicate.name = name
	duplicate.location = location
	duplicate.rotation_euler = Euler((0.0, math.radians(rotation_y_deg), 0.0))
	duplicate.scale = scale
	collection.objects.link(duplicate)
	return duplicate


def _build_grass(source: bpy.types.Object, game_collection: bpy.types.Collection) -> None:
	grass_folder = _get_or_create_collection("Grass", game_collection)
	scale = Vector((GRASS_SCALE, GRASS_SCALE, GRASS_SCALE))
	count = 0
	for cell_x in range(TOTAL_SIZE[0]):
		for cell_y in range(TOTAL_SIZE[1]):
			if _is_warehouse_cell(cell_x, cell_y):
				continue
			origin = Vector(
				float(cell_x) * CELL_SIZE,
				0.0,
				float(cell_y + 1) * CELL_SIZE,
			)
			_duplicate_linked(
				source,
				origin,
				0.0,
				scale,
				grass_folder,
				f"Grass_{count:04d}",
			)
			count += 1
	print(f"Placed {count} grass tiles.")


def _build_warehouse_floor(source: bpy.types.Object, game_collection: bpy.types.Collection) -> None:
	floor_folder = _get_or_create_collection("WarehouseFloor", game_collection)
	count = 0
	for x in range(WAREHOUSE_SIZE[0]):
		for y in range(WAREHOUSE_SIZE[1]):
			cell_x = WAREHOUSE_ORIGIN[0] + x
			cell_y = WAREHOUSE_ORIGIN[1] + y
			_duplicate_linked(
				source,
				Vector((cell_x + 0.5, 0.0, cell_y + 0.5)),
				0.0,
				Vector((1.0, 1.0, 1.0)),
				floor_folder,
				f"Floor_{count:04d}",
			)
			count += 1
	print(f"Placed {count} warehouse floor tiles.")


def _build_walls(
	wall_source: bpy.types.Object,
	corner_source: bpy.types.Object,
	game_collection: bpy.types.Collection,
) -> None:
	walls_folder = _get_or_create_collection("Walls", game_collection)
	min_x = float(WAREHOUSE_ORIGIN[0])
	min_z = float(WAREHOUSE_ORIGIN[1])

	_duplicate_linked(
		corner_source,
		Vector((min_x, 0.0, min_z)),
		ROT_CORNER_NW,
		Vector((1.0, 1.0, 1.0)),
		walls_folder,
		"WallCorner_NW",
	)

	for index in range(1, WAREHOUSE_SIZE[1]):
		z = min_z + float(index) + 0.5
		_duplicate_linked(
			wall_source,
			Vector((min_x, 0.0, z)),
			ROT_WALL_WEST,
			Vector((1.0, 1.0, 1.0)),
			walls_folder,
			f"Wall_West_{index:02d}",
		)

	for index in range(1, WAREHOUSE_SIZE[0]):
		x = min_x + float(index) + 0.5
		_duplicate_linked(
			wall_source,
			Vector((x, 0.0, min_z)),
			ROT_WALL_NORTH,
			Vector((1.0, 1.0, 1.0)),
			walls_folder,
			f"Wall_North_{index:02d}",
		)


def _build_manager(source: bpy.types.Object, game_collection: bpy.types.Collection) -> None:
	center_cell_x = WAREHOUSE_ORIGIN[0] + WAREHOUSE_SIZE[0] // 2
	center_cell_y = WAREHOUSE_ORIGIN[1] + WAREHOUSE_SIZE[1] // 2
	_duplicate_linked(
		source,
		_cell_to_world(center_cell_x, center_cell_y),
		180.0,
		Vector((1.0, 1.0, 1.0)),
		game_collection,
		"Manager",
	)


def _layout_source_assets(source_collection: bpy.types.Collection, sources: dict[str, bpy.types.Object]) -> None:
	offset_x = 0.0
	for key, obj in sources.items():
		obj.location = Vector((offset_x, 0.0, -8.0))
		offset_x += 3.0
		obj.hide_render = True
		obj.hide_viewport = False


def main() -> int:
	for key, path in SOURCE_FILES.items():
		if not os.path.isfile(path):
			print(f"ERROR: missing source file for {key}: {path}", file=sys.stderr)
			return 1

	_reset_scene()
	source_collection = _get_or_create_collection("SourceAssets")
	game_collection = _get_or_create_collection("GameScene")

	sources: dict[str, bpy.types.Object] = {}
	for key, path in SOURCE_FILES.items():
		print(f"Importing {key} from {path}")
		sources[key] = _import_source_asset(key, path, source_collection)

	_layout_source_assets(source_collection, sources)
	_build_grass(sources["grass_tile"], game_collection)
	_build_warehouse_floor(sources["floor_tile"], game_collection)
	_build_walls(sources["wall"], sources["wall_corner"], game_collection)
	_build_manager(sources["manager"], game_collection)

	bpy.context.scene.name = "PacktoryWarehouse"
	os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
	print(f"Saved {BLEND_PATH}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
