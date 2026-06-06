class_name GridTileDebugOverlay
extends Node3D

## Draws 1 m cell outlines over the whole lot for layout debugging.

const COLOR_WALKABLE := Color(0.42, 0.95, 0.45, 0.92)
const COLOR_BLOCKED := Color(0.95, 0.30, 0.28, 0.92)
const COLOR_HOVER := Color(1.0, 0.95, 0.35, 0.98)
const LINE_Y_OFFSET := 0.045
const LABEL_Y_OFFSET := 0.14
const LABEL_FONT_SIZE := 16
const INVALID_CELL := Vector2i(-9999, -9999)

var _grid: WarehouseGrid
var _walkable_mesh: MeshInstance3D
var _blocked_mesh: MeshInstance3D
var _hover_mesh: MeshInstance3D
var _labels_root: Node3D
var _display_enabled := false
var _coords_on_hover_enabled := false
var _tile_labels_enabled := false
var _hover_cell := INVALID_CELL
var _built := false
var _labels_built := false


func _ready() -> void:
	add_to_group("grid_tile_debug_overlay")
	_grid = get_node("/root/GridService") as WarehouseGrid
	visible = false
	if _grid != null and not _grid.navigation_changed.is_connected(_on_navigation_changed):
		_grid.navigation_changed.connect(_on_navigation_changed)


func is_display_enabled() -> bool:
	return _display_enabled


func set_display_enabled(enabled: bool) -> void:
	_display_enabled = enabled
	_update_visible()
	if not enabled:
		_clear_hover()
	if not enabled:
		return
	_ensure_built()


func is_tile_labels_enabled() -> bool:
	return _tile_labels_enabled


func set_tile_labels_enabled(enabled: bool) -> void:
	_tile_labels_enabled = enabled
	_update_visible()
	if enabled:
		_ensure_labels()
	else:
		_clear_labels()


func set_coords_on_hover_enabled(enabled: bool) -> void:
	_coords_on_hover_enabled = enabled
	_update_visible()
	set_process(enabled)
	if not enabled:
		_clear_hover()


func _update_visible() -> void:
	visible = _display_enabled or _coords_on_hover_enabled or _tile_labels_enabled


func is_coords_on_hover_enabled() -> bool:
	return _coords_on_hover_enabled


func set_hovered_cell(cell: Vector2i) -> void:
	if cell == _hover_cell:
		return
	_hover_cell = cell
	_rebuild_hover_mesh()


func toggle_display() -> bool:
	set_display_enabled(not _display_enabled)
	return _display_enabled


func _on_navigation_changed() -> void:
	if _display_enabled:
		_built = false
		_ensure_built()
	if _tile_labels_enabled:
		_labels_built = false
		_ensure_labels()


func _ensure_built() -> void:
	if _built or _grid == null:
		return
	_built = true
	_rebuild_meshes()


func _rebuild_meshes() -> void:
	_clear_meshes()
	var walkable := _build_line_mesh(COLOR_WALKABLE, false)
	var blocked := _build_line_mesh(COLOR_BLOCKED, true)
	if walkable != null:
		_walkable_mesh = walkable
		add_child(_walkable_mesh)
	if blocked != null:
		_blocked_mesh = blocked
		add_child(_blocked_mesh)


func _clear_meshes() -> void:
	if _walkable_mesh:
		_walkable_mesh.queue_free()
		_walkable_mesh = null
	if _blocked_mesh:
		_blocked_mesh.queue_free()
		_blocked_mesh = null
	_clear_hover()


func _clear_hover() -> void:
	_hover_cell = INVALID_CELL
	if _hover_mesh:
		_hover_mesh.queue_free()
		_hover_mesh = null


func _rebuild_hover_mesh() -> void:
	if _hover_mesh:
		_hover_mesh.queue_free()
		_hover_mesh = null
	if _hover_cell == INVALID_CELL or _grid == null:
		return
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	_append_cell_outline(_hover_cell, COLOR_HOVER, vertices, colors, 0.06)
	if vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	_hover_mesh = MeshInstance3D.new()
	_hover_mesh.name = "HoveredTile"
	_hover_mesh.mesh = mesh
	_hover_mesh.material_override = _line_material()
	_hover_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hover_mesh)


func _build_line_mesh(color: Color, blocked: bool) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for x in range(_grid.total_size.x):
		for y in range(_grid.total_size.y):
			var cell := Vector2i(x, y)
			if _is_blocked_cell(cell) != blocked:
				continue
			_append_cell_outline(cell, color, vertices, colors)
	if vertices.is_empty():
		return null

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var instance := MeshInstance3D.new()
	instance.name = "BlockedTiles" if blocked else "WalkableTiles"
	instance.mesh = mesh
	instance.material_override = _line_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _append_cell_outline(
	cell: Vector2i,
	color: Color,
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	y_extra: float = 0.0
) -> void:
	var surface_y := _grid.walk_surface_y(cell) + LINE_Y_OFFSET + y_extra
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
		vertices.append(corners[i])
		colors.append(color)
		vertices.append(corners[(i + 1) % 4])
		colors.append(color)


func _is_blocked_cell(cell: Vector2i) -> bool:
	if not _grid.is_in_bounds(cell):
		return true
	if _grid.is_cell_blocked(cell):
		return true
	if _grid.is_navigable_cell(cell) and _grid.pathfinding != null:
		return not _grid.pathfinding.is_walkable(cell)
	return false


func _ensure_labels() -> void:
	if _labels_built or _grid == null:
		return
	_labels_built = true
	_rebuild_labels()


func _rebuild_labels() -> void:
	if _labels_root:
		_labels_root.queue_free()
	_labels_root = Node3D.new()
	_labels_root.name = "TileLabels"
	add_child(_labels_root)
	for x in range(_grid.total_size.x):
		for y in range(_grid.total_size.y):
			_labels_root.add_child(_make_cell_label(Vector2i(x, y)))


func _make_cell_label(cell: Vector2i) -> Label3D:
	var label := Label3D.new()
	label.name = "Tile_%d_%d" % [cell.x, cell.y]
	label.text = "%d,%d" % [cell.x, cell.y]
	label.font_size = LABEL_FONT_SIZE
	label.modulate = Color(1.0, 0.98, 0.88)
	label.outline_size = 4
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.no_depth_test = true
	var pos := _grid.cell_to_world(cell)
	pos.y = _grid.walk_surface_y(cell) + LABEL_Y_OFFSET
	label.position = pos
	return label


func _clear_labels() -> void:
	_labels_built = false
	if _labels_root:
		_labels_root.queue_free()
		_labels_root = null


func _line_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return material
