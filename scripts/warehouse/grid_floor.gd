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
const ROAD_CORNER := SK + "road-corner.glb"
# rot=270 on road-corner.glb curves from East to North — used at the dock junction.
const CORNER_JUNCTION_YAW := 270.0

const FLOOR_TILE_PATH := BuildingLayout.FLOOR_PATH
const FLOOR_TINT := Color(0.68, 0.69, 0.72)

const GRASS_COLOR := Color(0.56, 0.74, 0.30)
# Warm multiply applied to the tree tiles so their foliage matches the warm lawn.
const TREE_TINT := Color(1.20, 1.02, 0.72)
const ROAD_YAW_DEG := 90.0  # tile road runs N-S by default; turn it to run E-W

# Tree-tile clustering (low frequency = larger, more organic clumps).
const DECOR_SEED := 842014
const NOISE_FREQUENCY := 0.11
const TREE_NOISE_THRESHOLD := 0.40
const TREE_FILL_CHANCE := 0.55  # thin trees out within a clump
const TREE_TALL_CHANCE := 0.4
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
		ROAD_CORNER: [] as Array[Transform3D],
	}

	for x in range(_grid.total_size.x):
		for y in range(_grid.total_size.y):
			var cell := Vector2i(x, y)
			if _grid.is_warehouse_cell(cell):
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
	# Junction where the dock spur meets the main road: curved corner tile.
	if (
		cell.x == WarehouseGrid.DOCK_ROAD_COL
		and cell.y == WarehouseGrid.DECORATIVE_ROAD_ROW
	):
		return ROAD_CORNER
	if _grid.is_decorative_road_cell(cell) or _grid.is_dock_road_connector_cell(cell):
		return ROAD
	if (
		_grid.is_decorative_sidewalk_cell(cell)
		or _grid.is_decorative_walkway_cell(cell)
		or _grid.is_warehouse_border_cell(cell)
		or _grid.is_dock_apron_cell(cell)
	):
		return PAVEMENT
	return GRASS


func _tree_tile_for_cell(cell: Vector2i) -> String:
	# Clumped via noise, thinned by chance, kept clear of the building front.
	if _is_foreground(cell):
		return ""
	if _noise.get_noise_2d(cell.x, cell.y) <= TREE_NOISE_THRESHOLD:
		return ""
	if _rng.randf() > TREE_FILL_CHANCE:
		return ""
	return GRASS_TREES_TALL if _rng.randf() < TREE_TALL_CHANCE else GRASS_TREES


func _tree_transform(cell: Vector2i) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(cell.x + 0.5, -TREE_SINK, cell.y + 0.5))


func _is_foreground(cell: Vector2i) -> bool:
	var origin := _grid.warehouse_origin
	var size := WarehouseGrid.WAREHOUSE_SIZE
	return cell.y > origin.y + size.y - 1 or cell.x > origin.x + size.x - 1


func _tile_transform(cell: Vector2i, path: String) -> Transform3D:
	var yaw := 0.0
	if path == ROAD:
		# Dock spur runs N-S (rot=0); main road runs E-W (rot=90).
		yaw = 0.0 if _grid.is_dock_road_connector_cell(cell) else ROAD_YAW_DEG
	elif path == ROAD_CORNER:
		yaw = CORNER_JUNCTION_YAW
	var basis := Basis.from_euler(Vector3(0.0, deg_to_rad(yaw), 0.0))
	return Transform3D(basis, Vector3(cell.x + 0.5, 0.0, cell.y + 0.5))


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
	var floor := KenneyMeshLoader.load_renderable(FLOOR_TILE_PATH)
	var floor_mesh: Mesh = floor.get("mesh")
	if floor_mesh == null:
		return

	var instances: Array[Transform3D] = []
	var origin := _grid.warehouse_origin
	for x in range(WarehouseGrid.WAREHOUSE_SIZE.x):
		for y in range(WarehouseGrid.WAREHOUSE_SIZE.y):
			var cell := origin + Vector2i(x, y)
			instances.append(BuildingLayout.floor_tile_transform(cell))

	var material := _floor_material(floor.get("material") as Material)
	var mesh := KenneyMeshLoader.mesh_with_material(floor_mesh, material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = instances.size()
	for i in range(instances.size()):
		multi.set_instance_transform(i, instances[i])

	var host := MultiMeshInstance3D.new()
	host.name = "WarehouseFloor"
	host.multimesh = multi
	host.material_override = material
	add_child(host)


func _floor_material(source: Material) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	if source is StandardMaterial3D:
		var base := source as StandardMaterial3D
		material.albedo_texture = base.albedo_texture
		material.normal_texture = base.normal_texture
		material.roughness = base.roughness
		material.metallic = base.metallic
	material.albedo_color = FLOOR_TINT
	return material
