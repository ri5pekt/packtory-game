extends Node3D

## Street furniture from the KayKit City-Builder Bits kit: streetlights arching over
## the road, plus a few benches, hydrants, a bin, and a dumpster.
## Greenery (trees) is handled by the grass-tree tiles in grid_floor.gd.

const KAY := "res://blender/assets/KayKit_City_Builder_Bits_1.0_FREE/Assets/gltf/"
const STREETLIGHT := KAY + "streetlight.gltf"
const HYDRANT := KAY + "firehydrant.gltf"
const DUMPSTER := KAY + "dumpster.gltf"

const LightingConfigScript = preload("res://scripts/gameplay/lighting_config.gd")
const DECOR_SEED := 1337

# Streetlight arm points toward the road from each sidewalk.
const LIGHT_YAW_NORTH := 90.0
const LIGHT_YAW_SOUTH := 270.0
## Place poles on the grass/apron edge of the sidewalk tile, not the walk lane.
const SIDEWALK_EDGE_INSET := 0.16
const SIDEWALK_JITTER_X := 0.08

var _grid: WarehouseGrid
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_rng.seed = DECOR_SEED
	_place_streetlights()
	_place_anchored_props()


func _place_streetlights() -> void:
	for x in range(4, _grid.total_size.x - 2, 5):
		_place_streetlight(
			Vector2i(x, WarehouseGrid.DECORATIVE_SIDEWALK_NORTH_ROW),
			LIGHT_YAW_NORTH,
			0
		)
		var south_row := WarehouseGrid.DECORATIVE_SIDEWALK_SOUTH_ROW
		if south_row < _grid.total_size.y:
			var south_cell := Vector2i(x, south_row)
			if not _grid.is_decorative_road_cell(south_cell):
				_place_streetlight(south_cell, LIGHT_YAW_SOUTH, 1)


func _place_anchored_props() -> void:
	var origin := _grid.warehouse_origin
	var size := WarehouseGrid.WAREHOUSE_SIZE
	var south := origin.y + size.y  # first apron row south of the building

	# Hydrant near the entrance apron (keep walkway tiles 12–13 and 18 clear).
	_place(HYDRANT, Vector2i(WarehouseGrid.ENTRANCE_COL_B + 3, south), 1.4, 0.0)

	# Dumpster against the east apron, hydrant at the road corner.
	_place(DUMPSTER, Vector2i(origin.x + size.x, origin.y + 2), 1.3, -90.0)
	_place(HYDRANT, Vector2i(2, WarehouseGrid.DECORATIVE_SIDEWALK_NORTH_ROW), 1.4, 0.0)


func _place_streetlight(cell: Vector2i, yaw_deg: float, sidewalk_side: int) -> bool:
	if not _grid.is_in_bounds(cell):
		return false
	var scene: PackedScene = load(STREETLIGHT)
	if scene == null:
		push_warning("GrassDecorations: failed to load %s" % STREETLIGHT)
		return false

	var prop: Node3D = scene.instantiate()
	prop.name = "Streetlight_%d_%d" % [cell.x, cell.y]
	prop.add_to_group("street_lamps")
	var jitter_x := _rng.randf_range(-SIDEWALK_JITTER_X, SIDEWALK_JITTER_X)
	prop.position = _streetlight_position(cell, sidewalk_side) + Vector3(jitter_x, 0.0, 0.0)
	prop.rotation.y = deg_to_rad(yaw_deg)
	prop.scale = Vector3.ONE * 1.3
	add_child(prop)

	var lamp := OmniLight3D.new()
	lamp.name = "LampLight"
	lamp.position = Vector3(0.0, LightingConfigScript.STREET_LAMP_LIGHT_HEIGHT, 0.0)
	lamp.light_color = Color(1.0, 0.9, 0.68)
	lamp.omni_range = LightingConfigScript.STREET_LAMP_RANGE
	lamp.omni_attenuation = 1.1
	lamp.shadow_enabled = false
	lamp.light_energy = 0.0
	lamp.visible = false
	prop.add_child(lamp)
	return true


func _streetlight_position(cell: Vector2i, sidewalk_side: int) -> Vector3:
	var x := float(cell.x) + 0.5
	var z := _streetlight_edge_z(cell, sidewalk_side)
	return Vector3(x, _grid.walk_surface_y(cell), z)


func _streetlight_edge_z(cell: Vector2i, sidewalk_side: int) -> float:
	# North sidewalk: tuck toward the apron/grass (lower Z). South: toward outer grass.
	if sidewalk_side == 0:
		return float(cell.y) + SIDEWALK_EDGE_INSET
	return float(cell.y + 1) - SIDEWALK_EDGE_INSET


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
	prop.position = Vector3(cell.x + 0.5, _grid.walk_surface_y(cell), cell.y + 0.5) + jitter
	prop.rotation.y = deg_to_rad(yaw_deg)
	prop.scale = Vector3.ONE * scale
	add_child(prop)
	return true
