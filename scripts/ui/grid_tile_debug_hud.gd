extends CanvasLayer

## Shows the grid cell under the cursor while debug tile coords are enabled.

const InteractableRaycastScript = preload("res://scripts/shared/interactable_raycast.gd")
const GridTileDebugOverlayScript = preload("res://scripts/warehouse/grid_tile_debug_overlay.gd")

const LABEL_OFFSET := Vector2(18.0, 18.0)

var _active := false
var _panel: PanelContainer
var _label: Label
var _grid: WarehouseGrid


func _ready() -> void:
	add_to_group("grid_tile_debug_hud")
	layer = 55
	_grid = get_node_or_null("/root/GridService") as WarehouseGrid
	_build_ui()
	visible = false
	set_process(false)


func is_active() -> bool:
	return _active


func set_active(enabled: bool) -> void:
	_active = enabled
	visible = enabled
	set_process(enabled and is_inside_tree())
	if not enabled:
		_hide()
		_clear_hover_overlay()


func _clear_hover_overlay() -> void:
	if not is_inside_tree():
		return
	var overlay := _get_overlay()
	if overlay != null:
		overlay.set_hovered_cell(GridTileDebugOverlayScript.INVALID_CELL)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "TileCoordPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	style.border_color = Color(1.0, 0.95, 0.35, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = Label.new()
	_label.name = "TileCoordLabel"
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.88))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func _process(_delta: float) -> void:
	if not _active or _grid == null:
		return
	var camera := get_viewport().get_camera_3d()
	var cell := InteractableRaycastScript.pick_lot_cell(
		camera,
		_grid,
		get_viewport().get_mouse_position()
	)
	var overlay := _get_overlay()
	if cell.x < 0:
		_hide()
		if overlay != null:
			overlay.set_hovered_cell(GridTileDebugOverlayScript.INVALID_CELL)
		return

	var warehouse := _warehouse_relative(cell)
	_label.text = "Tile (%d, %d)\nWarehouse (%d, %d)" % [
		cell.x,
		cell.y,
		warehouse.x,
		warehouse.y,
	]
	_panel.visible = true
	_panel.position = get_viewport().get_mouse_position() + LABEL_OFFSET
	if overlay != null:
		overlay.set_hovered_cell(cell)


func _warehouse_relative(cell: Vector2i) -> Vector2i:
	return cell - _grid.warehouse_origin


func _hide() -> void:
	if _panel:
		_panel.visible = false


func _get_overlay() -> GridTileDebugOverlay:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("grid_tile_debug_overlay")
	if nodes.is_empty():
		return null
	return nodes[0] as GridTileDebugOverlay
