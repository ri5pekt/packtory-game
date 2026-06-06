extends Node3D

## Ground tiler. Paves the whole lot with Starter-Kit City-Builder 1 m tiles
## (grass, grass-with-trees, pavement, asphalt road) mapped one-per-cell, and lays
## the Kenney floor inside the warehouse. One MultiMesh per tile type.
##
## Plain grass is drawn as a clean solid green (with subtle per-tile variation) so
## the lot reads smoothly instead of showing the texture's dark speckles.

const BuildingLayout = preload("res://scripts/warehouse/kenney_building_layout.gd")

const SK := "res://blender/assets/starter_kit_city/"
const GRASS := SK + "grass.glb"
const GRASS_TREES := SK + "grass-trees.glb"
const GRASS_TREES_TALL := SK + "grass-trees-tall.glb"
const PAVEMENT := SK + "pavement.glb"
const ROAD := SK + "road-straight.glb"
const ROAD_SPLIT := SK + "road-split.glb"
# T junction: spur from the dock (north) meets the E-W main road.
const SPLIT_JUNCTION_YAW := 180.0

const FLOOR_TILE_PATH := BuildingLayout.FLOOR_PATH
## Interior: clean light warm-grey, flat (no texture) so the floor reads as one
## smooth surface with no tiling seams.
const FLOOR_TINT := Color(0.80, 0.81, 0.84)
## Apron: same Kenney tile and height as interior, darker tint for outdoor pads.
const APRON_TINT := Color(0.42, 0.43, 0.49)

const GRASS_COLOR := Color(0.56, 0.74, 0.30)
# Warm multiply applied to the tree tiles so their foliage matches the warm lawn.
const TREE_TINT := Color(1.20, 1.02, 0.72)
const ROAD_YAW_DEG := 90.0  # tile road runs N-S by default; turn it to run E-W

# Tree scatter on grass cells — medium-frequency noise so clumps appear yard-wide.
const DECOR_SEED := 842014
const NOISE_FREQUENCY := 0.22
const TREE_NOISE_THRESHOLD := 0.12
const TREE_FILL_CHANCE := 0.42
const TREE_TALL_CHANCE := 0.4
# Hidden under exterior apron tiles only — must sit below the Kenney floor mesh top.
const FLOOR_FILLER_SINK_Y := -0.14
# Tree tiles are dropped below the solid grass so their own base is hidden.
const TREE_SINK := 0.12

var _grid: WarehouseGrid
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_rng.seed = DECOR_SEED
	_noise.seed = DECOR_SEED
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = NOISE_FREQUENCY

	_build_ground()
	_build_warehouse_floor()


func _build_ground() -> void:
	var grass_tiles: Array[Transform3D] = []
	var grass_colors: PackedColorArray = PackedColorArray()
	var textured := {
		GRASS_TREES: [] as Array[Transform3D],
		GRASS_TREES_TALL: [] as Array[Transform3D],
		PAVEMENT: [] as Array[Transform3D],
		ROAD: [] as Array[Transform3D],
		ROAD_SPLIT: [] as Array[Transform3D],
	}

	for x in range(_grid.total_size.x):
		for y in range(_grid.total_size.y):
			var cell := Vector2i(x, y)
			if _grid.is_warehouse_floor_cell(cell):
				# Exterior apron only: hidden grass underlay so edge seams never show sky.
				if not _grid.uses_interior_warehouse_floor(cell):
					grass_tiles.append(_filler_transform(cell))
					grass_colors.append(_grass_color(cell))
				continue
			var path := _ground_tile_for_cell(cell)
			if path == GRASS:
				# Solid grass everywhere; tree tiles overlay on top, sunk to hide
				# their own base so the ground colour stays uniform.
				grass_tiles.append(_tile_transform(cell, GRASS))
				grass_colors.append(_grass_color(cell))
				var tree := _tree_tile_for_cell(cell)
				if tree != "":
					textured[tree].append(_tree_transform(cell))
			else:
				textured[path].append(_tile_transform(cell, path))

	_add_grass_multimesh(grass_tiles, grass_colors)
	for path in textured:
		_add_tile_multimesh(path, textured[path])


func _grass_color(cell: Vector2i) -> Color:
	# Smooth, low-frequency variation so the lawn reads as soft patches, not a grid.
	var n := _noise.get_noise_2d(cell.x * 0.6, cell.y * 0.6)
	var v := 1.0 + n * 0.07
	return Color(GRASS_COLOR.r * v, GRASS_COLOR.g * v, GRASS_COLOR.b * v)


func _ground_tile_for_cell(cell: Vector2i) -> String:
	if _is_dock_road_split_cell(cell):
		return ROAD_SPLIT
	if _grid.is_entrance_crosswalk_cell(cell):
		return PAVEMENT
	if _grid.is_decorative_road_cell(cell) or _grid.is_dock_road_connector_cell(cell):
		return ROAD
	if (
		_grid.is_decorative_sidewalk_cell(cell)
		or _grid.is_decorative_walkway_cell(cell)
	):
		return PAVEMENT
	return GRASS


func _tree_tile_for_cell(cell: Vector2i) -> String:
	if not _grid.is_grass_cell(cell):
		return ""
	if _noise.get_noise_2d(float(cell.x), float(cell.y)) <= TREE_NOISE_THRESHOLD:
		return ""
	if _rng.randf() > TREE_FILL_CHANCE:
		return ""
	return GRASS_TREES_TALL if _rng.randf() < TREE_TALL_CHANCE else GRASS_TREES


func _filler_transform(cell: Vector2i) -> Transform3D:
	return Transform3D(
		Basis.IDENTITY,
		Vector3(cell.x + 0.5, FLOOR_FILLER_SINK_Y, cell.y + 0.5)
	)


func _tree_transform(cell: Vector2i) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(cell.x + 0.5, -TREE_SINK, cell.y + 0.5))


func _is_dock_road_split_cell(cell: Vector2i) -> bool:
	return (
		cell.x == WarehouseGrid.DOCK_ROAD_COL
		and cell.y == WarehouseGrid.DECORATIVE_ROAD_ROW
	)


func _tile_transform(cell: Vector2i, path: String) -> Transform3D:
	var yaw := 0.0
	if path == ROAD:
		# Dock spur runs N-S (rot=0); main road runs E-W (rot=90).
		yaw = 0.0 if _grid.is_dock_road_connector_cell(cell) else ROAD_YAW_DEG
	elif path == ROAD_SPLIT:
		yaw = SPLIT_JUNCTION_YAW
	var basis := Basis.from_euler(Vector3(0.0, deg_to_rad(yaw), 0.0))
	var y := _ground_tile_y(cell, path)
	return Transform3D(basis, Vector3(cell.x + 0.5, y, cell.y + 0.5))


func _ground_tile_y(_cell: Vector2i, _path: String) -> float:
	return 0.0


func _add_grass_multimesh(instances: Array[Transform3D], colors: PackedColorArray) -> void:
	if instances.is_empty():
		return
	var renderable: Dictionary = KenneyMeshLoader.load_renderable(GRASS)
	var mesh: Mesh = renderable.get("mesh")
	if mesh == null:
		return

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.roughness = 1.0

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = KenneyMeshLoader.mesh_with_material(mesh, material)
	multi.instance_count = instances.size()
	for i in range(instances.size()):
		multi.set_instance_transform(i, instances[i])
		multi.set_instance_color(i, colors[i])

	var host := MultiMeshInstance3D.new()
	host.name = "Grass"
	host.multimesh = multi
	host.material_override = material
	add_child(host)


func _add_tile_multimesh(path: String, instances: Array[Transform3D]) -> void:
	if instances.is_empty():
		return
	var renderable: Dictionary = KenneyMeshLoader.load_renderable(path)
	var mesh: Mesh = renderable.get("mesh")
	if mesh == null:
		push_warning("GridFloor: failed to load %s" % path)
		return
	var material: Material = renderable.get("material")
	if (path == GRASS_TREES or path == GRASS_TREES_TALL) and material is StandardMaterial3D:
		var tinted := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
		tinted.albedo_color = tinted.albedo_color * TREE_TINT
		material = tinted

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = KenneyMeshLoader.mesh_with_material(mesh, material)
	multi.instance_count = instances.size()
	for i in range(instances.size()):
		multi.set_instance_transform(i, instances[i])

	var host := MultiMeshInstance3D.new()
	host.name = path.get_file().get_basename()
	host.multimesh = multi
	if material:
		host.material_override = material
	add_child(host)


func _build_warehouse_floor() -> void:
	var interior: Array[Transform3D] = []
	var apron: Array[Transform3D] = []

	for cell in _grid.get_warehouse_floor_cells():
		var is_interior := _grid.uses_interior_warehouse_floor(cell)
		var transform := BuildingLayout.floor_tile_transform(cell, BuildingLayout.FLOOR_TILE_SCALE)
		if is_interior:
			interior.append(transform)
		else:
			apron.append(transform)

	var floor := KenneyMeshLoader.load_renderable(FLOOR_TILE_PATH)
	var floor_mesh: Mesh = floor.get("mesh")
	if floor_mesh == null:
		return

	if not interior.is_empty():
		var mat := _floor_material(floor.get("material") as Material)
		_spawn_floor_multimesh("WarehouseFloor", floor_mesh, mat, interior)

	if not apron.is_empty():
		var apron_mat := _apron_material()
		_spawn_floor_multimesh("WarehouseApron", floor_mesh, apron_mat, apron)


func _apron_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = APRON_TINT
	material.roughness = 1.0
	material.metallic = 0.0
	return material


func _spawn_floor_multimesh(
	host_name: String,
	floor_mesh: Mesh,
	material: Material,
	instances: Array[Transform3D]
) -> void:
	var mesh := KenneyMeshLoader.mesh_with_material(floor_mesh, material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = instances.size()
	for i in range(instances.size()):
		multi.set_instance_transform(i, instances[i])
	var host := MultiMeshInstance3D.new()
	host.name = host_name
	host.multimesh = multi
	host.material_override = material
	add_child(host)




## Flat, untextured material — no albedo_texture means no tiling seams, giving a
## perfectly smooth uniform floor. `source` is ignored on purpose.
func _floor_material(_source: Material) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = FLOOR_TINT
	material.roughness = 1.0
	material.metallic = 0.0
	return material
