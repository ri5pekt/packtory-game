"""
Inspect Kenney mini-market tile placement by assembling a small reference room.

Run:
  blender --background --python blender/inspect_kenney_market_layout.py
"""

import json
import math
import os

import bpy
from mathutils import Euler, Vector

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT_ROOT = os.path.join(
	PROJECT_ROOT,
	"blender",
	"assets",
	"kenney_mini-market",
	"Models",
	"GLB format",
)
OUT_BLEND = os.path.join(PROJECT_ROOT, "blender", "kenney_market_reference.blend")
OUT_JSON = os.path.join(PROJECT_ROOT, "blender", "kenney_market_layout.json")

ROOM_SIZE = 6
# Kenney sample-room style (full perimeter, like the kit promo image).
KENNEY_LAYOUT = {
	"floor": {"path": "floor.glb", "rotation_y": 0.0},
	"wall": {"path": "wall.glb"},
	"wall_corner": {"path": "wall-corner.glb"},
	"perimeter": {
		"north": {"rotation_y": -90.0},
		"south": {"rotation_y": 90.0},
		"west": {"rotation_y": 180.0},
		"east": {"rotation_y": 0.0},
		"corners": {
			"nw": {"rotation_y": 0.0},
			"ne": {"rotation_y": -90.0},
			"se": {"rotation_y": 180.0},
			"sw": {"rotation_y": 90.0},
		},
	},
}


def _clear_scene() -> None:
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete(use_global=False)


def _import_glb(name: str) -> bpy.types.Object:
	path = os.path.join(KIT_ROOT, name)
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=path)
	imported = [obj for obj in bpy.data.objects if obj not in before]
	meshes = [obj for obj in imported if obj.type == "MESH"]
	if not meshes:
		raise RuntimeError(f"No mesh imported from {path}")
	if len(meshes) > 1:
		bpy.ops.object.select_all(action="DESELECT")
		for obj in meshes:
			obj.select_set(True)
		bpy.context.view_layer.objects.active = meshes[0]
		bpy.ops.object.join()
		return bpy.context.view_layer.objects.active
	return meshes[0]


def _duplicate(source: bpy.types.Object, name: str) -> bpy.types.Object:
	dup = source.copy()
	dup.data = source.data
	dup.name = name
	bpy.context.scene.collection.objects.link(dup)
	return dup


def _place(obj: bpy.types.Object, location: Vector, rotation_y: float) -> None:
	obj.location = location
	obj.rotation_euler = Euler((0.0, math.radians(rotation_y), 0.0))


def _record(obj: bpy.types.Object, kind: str, index: str) -> dict:
	return {
		"name": obj.name,
		"kind": kind,
		"index": index,
		"location": [round(obj.location.x, 4), round(obj.location.y, 4), round(obj.location.z, 4)],
		"rotation_y": round(math.degrees(obj.rotation_euler.y), 4),
	}


def main() -> int:
	_clear_scene()
	floor_src = _import_glb("floor.glb")
	wall_src = _import_glb("wall.glb")
	corner_src = _import_glb("wall-corner.glb")
	floor_src.hide_set(True)
	wall_src.hide_set(True)
	corner_src.hide_set(True)

	records: list[dict] = []
	perimeter = KENNEY_LAYOUT["perimeter"]

	for x in range(ROOM_SIZE):
		for z in range(ROOM_SIZE):
			obj = _duplicate(floor_src, f"Floor_{x}_{z}")
			_place(obj, Vector((x + 0.5, 0.0, z + 0.5)), 0.0)
			records.append(_record(obj, "floor", f"{x},{z}"))

	corner_points = {
		"nw": Vector((0.0, 0.0, 0.0)),
		"ne": Vector((float(ROOM_SIZE), 0.0, 0.0)),
		"se": Vector((float(ROOM_SIZE), 0.0, float(ROOM_SIZE))),
		"sw": Vector((0.0, 0.0, float(ROOM_SIZE))),
	}
	for key, pos in corner_points.items():
		obj = _duplicate(corner_src, f"Corner_{key.upper()}")
		_place(obj, pos, perimeter["corners"][key]["rotation_y"])
		records.append(_record(obj, "corner", key))

	for index in range(1, ROOM_SIZE):
		x = float(index) + 0.5
		z = float(index) + 0.5
		north = _duplicate(wall_src, f"Wall_N_{index}")
		_place(north, Vector((x, 0.0, 0.0)), perimeter["north"]["rotation_y"])
		records.append(_record(north, "wall_north", str(index)))

		south = _duplicate(wall_src, f"Wall_S_{index}")
		_place(south, Vector((x, 0.0, float(ROOM_SIZE))), perimeter["south"]["rotation_y"])
		records.append(_record(south, "wall_south", str(index)))

		west = _duplicate(wall_src, f"Wall_W_{index}")
		_place(west, Vector((0.0, 0.0, z)), perimeter["west"]["rotation_y"])
		records.append(_record(west, "wall_west", str(index)))

		east = _duplicate(wall_src, f"Wall_E_{index}")
		_place(east, Vector((float(ROOM_SIZE), 0.0, z)), perimeter["east"]["rotation_y"])
		records.append(_record(east, "wall_east", str(index)))

	with open(OUT_JSON, "w", encoding="utf-8") as handle:
		json.dump({"room_size": ROOM_SIZE, "layout": KENNEY_LAYOUT, "objects": records}, handle, indent=2)

	os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
	print(f"Saved {OUT_BLEND}")
	print(f"Saved {OUT_JSON}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
