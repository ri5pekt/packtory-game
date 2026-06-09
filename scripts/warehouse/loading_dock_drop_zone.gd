class_name LoadingDockDropZone
extends Node3D

## White dashed outlines marking where delivery trucks unload boxes.

const OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const LINE_Y_OFFSET := 0.055
const DASH_LENGTH := 0.14
const GAP_LENGTH := 0.1

var _grid: WarehouseGrid
var _cells: Array[Vector2i] = []


func setup(grid: WarehouseGrid, cells: Array) -> void:
	_grid = grid
	_cells.clear()
	for cell_variant in cells:
		if cell_variant is Vector2i:
			_cells.append(cell_variant)
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	if _grid == null or _cells.is_empty():
		return

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var edges: Dictionary = {}
	for cell in _cells:
		_collect_cell_edges(cell, edges)
	for edge_points in edges.values():
		var pts: Array = edge_points
		_append_dashed_segment(pts[0], pts[1], OUTLINE_COLOR, vertices, colors)
	if vertices.is_empty():
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var instance := MeshInstance3D.new()
	instance.name = "DropZoneOutline"
	instance.mesh = mesh
	instance.material_override = _line_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _collect_cell_edges(cell: Vector2i, edges: Dictionary) -> void:
	var surface_y := _grid.walk_surface_y(cell) + LINE_Y_OFFSET
	var x0 := float(cell.x)
	var z0 := float(cell.y)
	var x1 := x0 + WarehouseGrid.CELL_SIZE
	var z1 := z0 + WarehouseGrid.CELL_SIZE
	var corners: Array[Vector3] = [
		Vector3(x0, surface_y, z0),
		Vector3(x1, surface_y, z0),
		Vector3(x1, surface_y, z1),
		Vector3(x0, surface_y, z1),
	]
	for i in range(4):
		_register_edge(edges, corners[i], corners[(i + 1) % 4])


func _register_edge(edges: Dictionary, a: Vector3, b: Vector3) -> void:
	edges[_edge_key(a, b)] = [a, b]


func _edge_key(a: Vector3, b: Vector3) -> String:
	if a.x < b.x or (is_equal_approx(a.x, b.x) and a.z < b.z):
		return "%.3f,%.3f-%.3f,%.3f" % [a.x, a.z, b.x, b.z]
	return "%.3f,%.3f-%.3f,%.3f" % [b.x, b.z, a.x, a.z]


func _append_dashed_segment(
	from: Vector3,
	to: Vector3,
	color: Color,
	vertices: PackedVector3Array,
	colors: PackedColorArray
) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return
	var unit := delta / length
	var cursor := 0.0
	var drawing := true
	while cursor < length:
		var span := DASH_LENGTH if drawing else GAP_LENGTH
		var next_cursor := minf(cursor + span, length)
		if drawing:
			vertices.append(from + unit * cursor)
			vertices.append(from + unit * next_cursor)
			colors.append(color)
			colors.append(color)
		cursor = next_cursor
		drawing = not drawing


func _line_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return material
