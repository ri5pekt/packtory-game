class_name PlaceableSelectionOutline
extends Node3D

## Floor ring highlighting the currently selected warehouse placeable.

const RING_Y := WarehouseGrid.WAREHOUSE_FLOOR_SURFACE_Y + 0.025
const RING_HEIGHT := 0.04

var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "Ring"
	add_child(_mesh)
	visible = false


func show_footprint(grid: WarehouseGrid, cells: Array[Vector2i]) -> void:
	if grid == null or cells.is_empty():
		hide_outline()
		return
	var min_cell := cells[0]
	var max_cell := cells[0]
	for cell in cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	var width := float(max_cell.x - min_cell.x + 1)
	var depth := float(max_cell.y - min_cell.y + 1)
	var center_cell := Vector2i(
		(min_cell.x + max_cell.x) / 2,
		(min_cell.y + max_cell.y) / 2
	)
	var center_world := grid.cell_to_world(center_cell)
	global_position = Vector3(center_world.x, RING_Y, center_world.z)
	global_rotation = Vector3.ZERO

	var box := BoxMesh.new()
	box.size = Vector3(width * 0.96, RING_HEIGHT, depth * 0.96)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.98, 0.84, 0.18, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = mat
	visible = true


func hide_outline() -> void:
	visible = false
