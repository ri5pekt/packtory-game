extends SceneTree

const BuildingLayout = preload("res://scripts/warehouse/kenney_building_layout.gd")
const KenneyMeshLoaderScript = preload("res://scripts/warehouse/kenney_mesh_loader.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")


func _init() -> void:
	var grid: WarehouseGrid = GridScript.new()
	var mesh: Mesh = KenneyMeshLoaderScript.load_mesh(BuildingLayout.FLOOR_PATH)
	var aabb: AABB = mesh.get_aabb()
	for cell in [Vector2i(9, 23), Vector2i(10, 23), Vector2i(11, 23)]:
		var xf: Transform3D = BuildingLayout.floor_tile_transform(cell)
		var world_aabb := aabb * xf
		print(
			"cell %s type=%s\n  expect x=[%d,%d] z=[%d,%d]\n  actual x=[%.2f,%.2f] z=[%.2f,%.2f]" % [
				cell,
				_cell_type(grid, cell),
				cell.x,
				cell.x + 1,
				cell.y,
				cell.y + 1,
				world_aabb.position.x,
				world_aabb.end.x,
				world_aabb.position.z,
				world_aabb.end.z,
			]
		)
	quit(0)


func _cell_type(grid: WarehouseGrid, cell: Vector2i) -> String:
	if grid.is_warehouse_border_padding_cell(cell):
		return "padding"
	if grid.is_warehouse_border_cell(cell):
		return "border"
	if grid.is_south_threshold_cell(cell):
		return "south_threshold"
	if grid.is_warehouse_cell(cell):
		return "interior"
	return "other"
