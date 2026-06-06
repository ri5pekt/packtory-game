class_name PlacementPreview
extends Node3D

## Green/red floor tiles showing whether a placement footprint is valid.

const TILE_Y := WarehouseGrid.WAREHOUSE_FLOOR_SURFACE_Y + 0.02
const TILE_HEIGHT := 0.03

var _tiles: Array[MeshInstance3D] = []


func show_footprint(grid: WarehouseGrid, cells: Array[Vector2i], valid: bool) -> void:
	_clear_tiles()
	if grid == null:
		return
	var color := Color(0.22, 0.88, 0.42, 0.72) if valid else Color(0.92, 0.28, 0.24, 0.72)
	for cell in cells:
		var tile := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.92, TILE_HEIGHT, 0.92)
		tile.mesh = mesh
		tile.position = grid.cell_to_world(cell) + Vector3(0.0, TILE_Y, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tile.material_override = mat
		add_child(tile)
		_tiles.append(tile)


func hide_preview() -> void:
	_clear_tiles()


func _clear_tiles() -> void:
	for tile in _tiles:
		if is_instance_valid(tile):
			tile.queue_free()
	_tiles.clear()
