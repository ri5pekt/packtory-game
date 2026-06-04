extends Node3D

## Street furniture from the KayKit City-Builder Bits kit: streetlights arching over
## the road, plus a few benches, hydrants, a bin, a dumpster and a water-tower
## landmark. Greenery (trees) is handled by the grass-tree tiles in grid_floor.gd.

const KAY := "res://blender/assets/KayKit_City_Builder_Bits_1.0_FREE/Assets/gltf/"
const BENCH := KAY + "bench.gltf"
const STREETLIGHT := KAY + "streetlight.gltf"
const HYDRANT := KAY + "firehydrant.gltf"
const TRASH := KAY + "trash_A.gltf"
const DUMPSTER := KAY + "dumpster.gltf"
const WATERTOWER := KAY + "watertower.gltf"

const PROP_Y := 0.06
const DECOR_SEED := 1337

# Streetlight arm points toward the road from each sidewalk.
const LIGHT_YAW_NORTH := 90.0
const LIGHT_YAW_SOUTH := 270.0

var _grid: WarehouseGrid
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_rng.seed = DECOR_SEED
	_place_streetlights()
	_place_anchored_props()
	print("GrassDecorations: placed KayKit street furniture")


func _place_streetlights() -> void:
	for x in range(4, _grid.total_size.x - 2, 5):
		_place(STREETLIGHT, Vector2i(x, WarehouseGrid.DECORATIVE_SIDEWALK_NORTH_ROW), 1.3, LIGHT_YAW_NORTH)
		_place(STREETLIGHT, Vector2i(x, WarehouseGrid.DECORATIVE_SIDEWALK_SOUTH_ROW), 1.3, LIGHT_YAW_SOUTH)


func _place_anchored_props() -> void:
	var origin := _grid.warehouse_origin
	var size := WarehouseGrid.WAREHOUSE_SIZE
	var south := origin.y + size.y  # first apron row south of the building

	# Benches flanking the entrance walkway, facing it.
	_place(BENCH, Vector2i(WarehouseGrid.ENTRANCE_COL_A - 2, south), 1.4, 90.0)
	_place(BENCH, Vector2i(WarehouseGrid.ENTRANCE_COL_B + 2, south), 1.4, -90.0)

	# Bins and a hydrant near the entrance apron.
	_place(TRASH, Vector2i(WarehouseGrid.ENTRANCE_COL_A - 3, south), 1.4, 0.0)
	_place(HYDRANT, Vector2i(WarehouseGrid.ENTRANCE_COL_B + 3, south), 1.4, 0.0)

	# Dumpster against the east apron, hydrant at the road corner.
	_place(DUMPSTER, Vector2i(origin.x + size.x, origin.y + 2), 1.3, -90.0)
	_place(HYDRANT, Vector2i(2, WarehouseGrid.DECORATIVE_SIDEWALK_NORTH_ROW), 1.4, 0.0)

	# Water-tower landmark in the open north-west corner.
	_place(WATERTOWER, Vector2i(3, 3), 1.6, 0.0)


func _place(path: String, cell: Vector2i, scale: float, yaw_deg: float) -> bool:
	if not _grid.is_in_bounds(cell):
		return false
	var scene: PackedScene = load(path)
	if scene == null:
		push_warning("GrassDecorations: failed to load %s" % path)
		return false

	var prop: Node3D = scene.instantiate()
	prop.name = path.get_file().get_basename()
	var jitter := Vector3(
		_rng.randf_range(-0.12, 0.12), 0.0, _rng.randf_range(-0.12, 0.12)
	)
	prop.position = Vector3(cell.x + 0.5, PROP_Y, cell.y + 0.5) + jitter
	prop.rotation.y = deg_to_rad(yaw_deg)
	prop.scale = Vector3.ONE * scale
	add_child(prop)
	return true
