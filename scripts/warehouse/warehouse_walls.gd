extends Node3D

## Warehouse shell: a full perimeter with a doorway on the south side (facing the
## road). The far walls (north/west) are full height and carry the windows so they
## read as a backdrop; the near walls (south/east) are low so the isometric camera
## sees into the interior. Corner columns cap the joints.

const BuildingLayout = preload("res://scripts/warehouse/kenney_building_layout.gd")

const MODULES_PER_SIDE := 6

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
	_build_corner_columns()


func _build_walls() -> void:
	var origin := _grid.warehouse_origin
	var x_min := float(origin.x)
	var x_max := float(origin.x + WarehouseGrid.WAREHOUSE_SIZE.x)
	var z_min := float(origin.y)
	var z_max := float(origin.y + WarehouseGrid.WAREHOUSE_SIZE.y)

	for module in range(MODULES_PER_SIDE):
		var run := x_min + 1.0 + float(module) * BuildingLayout.MODULE

		# West and north: tall windowed backdrop.
		_place(TALL_PATTERN[module], BuildingLayout.z_run_transform(x_min, run))
		_place(TALL_PATTERN[module], BuildingLayout.x_run_transform(run, z_min))

		# East: low near wall with the loading-dock back doorway.
		var east_path := (
			BuildingLayout.DOORWAY_PATH
			if module == WarehouseGrid.EAST_DOOR_MODULE_INDEX
			else BuildingLayout.WALL_LOW_PATH
		)
		_place(east_path, BuildingLayout.z_run_transform(x_max, run))

		# South: low near wall with the entrance doorway.
		var south_path := (
			BuildingLayout.DOORWAY_PATH
			if module == WarehouseGrid.ENTRANCE_MODULE_INDEX
			else BuildingLayout.WALL_LOW_PATH
		)
		_place(south_path, BuildingLayout.x_run_transform(run, z_max))

	_block_perimeter_cells()


func _build_corner_columns() -> void:
	var origin := _grid.warehouse_origin
	var x_min := float(origin.x)
	var x_max := float(origin.x + WarehouseGrid.WAREHOUSE_SIZE.x)
	var z_min := float(origin.y)
	var z_max := float(origin.y + WarehouseGrid.WAREHOUSE_SIZE.y)
	for corner in [
		Vector3(x_min, 0.0, z_min),
		Vector3(x_max, 0.0, z_min),
		Vector3(x_min, 0.0, z_max),
		Vector3(x_max, 0.0, z_max),
	]:
		_place(BuildingLayout.COLUMN_PATH, BuildingLayout.column_transform(corner))


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


func _place(path: String, transform: Transform3D) -> void:
	var renderable: Dictionary = _load_renderable(path)
	var mesh: Mesh = renderable.get("mesh")
	if mesh == null:
		return

	var material: Material = renderable.get("material")
	var instance := MeshInstance3D.new()
	instance.mesh = KenneyMeshLoader.mesh_with_material(mesh, material)
	instance.transform = transform
	if material:
		instance.material_override = material
	add_child(instance)

	StaticCollision.add_mesh_aabb(self, mesh, transform)


func _load_renderable(path: String) -> Dictionary:
	if not _cache.has(path):
		_cache[path] = KenneyMeshLoader.load_renderable(path)
	return _cache[path]
