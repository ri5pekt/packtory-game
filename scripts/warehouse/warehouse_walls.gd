extends Node3D

## Warehouse shell with open door gaps on the south (entrance) and east (loading dock).
## Far walls (north/west) stay tall with windows as a backdrop; near walls (south/east)
## are short knee walls so the isometric camera can see desks, shelves, and shoppers.

const BuildingLayout = preload("res://scripts/warehouse/kenney_building_layout.gd")

const MODULES_PER_SIDE := 6
# wall-low is 1.2 m; scale down the camera-facing segments to ~0.45 m.
const NEAR_WALL_HEIGHT_SCALE := 0.38
# Dark blue-grey tint to match the "dark" Kenney building-kit variant
const WALL_TINT := Color(0.46, 0.48, 0.58)

# Window mix for the tall far walls — alternates solid, square and round windows.
const TALL_PATTERN := [
	BuildingLayout.WALL_PATH,
	BuildingLayout.WINDOW_SQUARE_PATH,
	BuildingLayout.WINDOW_ROUND_PATH,
	BuildingLayout.WALL_PATH,
	BuildingLayout.WINDOW_SQUARE_PATH,
	BuildingLayout.WINDOW_ROUND_PATH,
]

var _grid: WarehouseGrid
var _cache: Dictionary = {}


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_build_walls()


func _build_walls() -> void:
	var origin := _grid.warehouse_origin
	var size := WarehouseGrid.WAREHOUSE_SIZE
	var x_west := BuildingLayout.west_wall_line_x(float(origin.x))
	var x_east := BuildingLayout.east_wall_line_x(float(origin.x), size.x)
	var z_north := BuildingLayout.north_wall_line_z(float(origin.y))
	var z_south := BuildingLayout.south_wall_line_z(float(origin.y), size.y)

	for module in range(MODULES_PER_SIDE):
		var run := BuildingLayout.module_center(float(origin.y), module)
		var run_x := BuildingLayout.module_center(float(origin.x), module)

		# West and north: tall windowed backdrop (full run).
		_place(TALL_PATTERN[module], BuildingLayout.z_run_transform(x_west, run))
		_place(TALL_PATTERN[module], BuildingLayout.x_run_transform(run_x, z_north))

		# East: short knee wall; leave the loading-dock module empty (no door frame).
		if module != WarehouseGrid.EAST_DOOR_MODULE_INDEX:
			_place_near_wall(
				BuildingLayout.WALL_LOW_PATH,
				BuildingLayout.z_run_transform(x_east, run)
			)

		# South: short knee wall; leave the entrance module empty (no door frame).
		if module != WarehouseGrid.ENTRANCE_MODULE_INDEX:
			_place_near_wall(
				BuildingLayout.WALL_LOW_PATH,
				BuildingLayout.x_run_transform(run_x, z_south)
			)

	_block_perimeter_cells()


func _block_perimeter_cells() -> void:
	var origin := _grid.warehouse_origin
	var size := WarehouseGrid.WAREHOUSE_SIZE
	for offset in range(size.x):
		var col := origin.x + offset
		var row := origin.y + offset
		_grid.register_blocked_cell(Vector2i(col, origin.y))               # north
		_grid.register_blocked_cell(Vector2i(origin.x, row))               # west
		# East edge stays open at the back-door rows (loading dock).
		if row != WarehouseGrid.BACK_DOOR_ROW_A and row != WarehouseGrid.BACK_DOOR_ROW_B:
			_grid.register_blocked_cell(Vector2i(origin.x + size.x - 1, row))  # east
		# South edge stays open at the doorway columns so the worker can reach it.
		if col != WarehouseGrid.ENTRANCE_COL_A and col != WarehouseGrid.ENTRANCE_COL_B:
			_grid.register_blocked_cell(Vector2i(col, origin.y + size.y - 1))


func _place_near_wall(path: String, transform: Transform3D) -> void:
	var basis := transform.basis.scaled(Vector3(1.0, NEAR_WALL_HEIGHT_SCALE, 1.0))
	_place(path, Transform3D(basis, transform.origin))


func _place(path: String, transform: Transform3D) -> void:
	var renderable: Dictionary = _load_renderable(path)
	var mesh: Mesh = renderable.get("mesh")
	if mesh == null:
		return

	var material: Material = _tinted_material(renderable.get("material") as Material)
	var instance := MeshInstance3D.new()
	instance.mesh = KenneyMeshLoader.mesh_with_material(mesh, material)
	instance.transform = transform
	if material:
		instance.material_override = material
	add_child(instance)

	StaticCollision.add_mesh_aabb(self, mesh, transform)


func _tinted_material(source: Material) -> Material:
	if source == null:
		return source
	var key := "%s:tinted" % str(source.get_instance_id())
	if _cache.has(key):
		return _cache[key] as Material
	if source is StandardMaterial3D:
		var mat := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.albedo_color = mat.albedo_color * WALL_TINT
		_cache[key] = mat
		return mat
	return source


func _load_renderable(path: String) -> Dictionary:
	if not _cache.has(path):
		_cache[path] = KenneyMeshLoader.load_renderable(path)
	return _cache[path]
