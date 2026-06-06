class_name WarehouseEditMode
extends Node

## Tile-snapped warehouse layout editor for mobile and desktop.

const WarehousePlaceableScript = preload("res://scripts/warehouse/warehouse_placeable.gd")
const PlacementPreviewScript = preload("res://scripts/warehouse/placement_preview.gd")
const PlaceableSelectionOutlineScript = preload(
	"res://scripts/warehouse/placeable_selection_outline.gd"
)

signal mode_changed(active: bool)
signal selection_changed(placeable: Node)

const PLACEABLE_MASK := 1

var _grid: WarehouseGrid
var _camera: Camera3D
var _preview: Node3D
var _outline: Node3D
var _ui: Control

var _active := false
var _selected: Node3D
var _original_anchor := Vector2i.ZERO
var _original_yaw := 0.0
var _preview_anchor := Vector2i.ZERO
var _preview_yaw := 0.0


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_preview = PlacementPreviewScript.new()
	_preview.name = "PlacementPreview"
	add_child(_preview)
	_outline = PlaceableSelectionOutlineScript.new()
	_outline.name = "SelectionOutline"
	add_child(_outline)
	call_deferred("_bind_ui")
	call_deferred("_bind_camera")


func _bind_ui() -> void:
	_ui = get_node_or_null("../UI/EditModeUI") as Control
	if _ui and _ui.has_method("bind_edit_mode"):
		_ui.bind_edit_mode(self)


func _bind_camera() -> void:
	var rig := get_node_or_null("../IsoCameraRig") as Node3D
	if rig and rig.has_method("get_camera"):
		_camera = rig.get_camera()


func is_active() -> bool:
	return _active


func get_selected() -> Node3D:
	return _selected


func enter_mode() -> void:
	if _active:
		return
	_active = true
	_bind_camera()
	mode_changed.emit(true)
	if _ui and _ui.has_method("on_mode_entered"):
		_ui.on_mode_entered()


func exit_mode() -> void:
	if not _active:
		return
	if _selected:
		_revert_selection()
	_active = false
	_preview.hide_preview()
	_outline.hide_outline()
	_selected = null
	mode_changed.emit(false)
	if _ui and _ui.has_method("on_mode_exited"):
		_ui.on_mode_exited()


func handle_tap(screen_position: Vector2) -> bool:
	if not _active:
		return false
	if _ui and _ui.has_method("consumes_tap") and _ui.consumes_tap(screen_position):
		return true

	var hit := _raycast_placeable(screen_position)
	if hit != null:
		_select_placeable(hit)
		return true

	var floor := _pick_floor(screen_position)
	if floor != Vector3.INF and _selected:
		_move_preview_to_cell(_grid.world_to_cell(floor))
		return true

	return true


func rotate_selected() -> void:
	if _selected == null:
		return
	_preview_yaw = fmod(_preview_yaw + 90.0, 360.0)
	_update_preview()


func apply_selected() -> void:
	if _selected == null:
		return
	if not _is_preview_valid():
		AlertMessages.warn("Can't place here — blocked or outside the warehouse.")
		return
	_commit_preview()
	_clear_selection(true)


func cancel_selected() -> void:
	if _selected == null:
		return
	_revert_selection()
	_clear_selection(true)


func _select_placeable(node: Node3D) -> void:
	if not WarehousePlaceableScript.is_placeable(node):
		return
	if _selected == node:
		return
	if _selected:
		_revert_selection()
	_selected = node
	_original_anchor = node.get_anchor_cell()
	_original_yaw = node.get_placement_yaw()
	_preview_anchor = _original_anchor
	_preview_yaw = _original_yaw
	node.release_placement_cells()
	_update_preview()
	selection_changed.emit(node)
	if _ui and _ui.has_method("on_selection_changed"):
		_ui.on_selection_changed(node)


func _move_preview_to_cell(cell: Vector2i) -> void:
	if _selected == null or _grid == null:
		return
	if not _grid.is_warehouse_cell(cell):
		return
	_preview_anchor = cell
	_update_preview()


func _update_preview() -> void:
	if _selected == null:
		return
	_selected.preview_placement(_preview_anchor, _preview_yaw)
	var cells: Array[Vector2i] = _selected.get_footprint_cells_at(_preview_anchor, _preview_yaw)
	var valid := _is_preview_valid()
	_preview.show_footprint(_grid, cells, valid)
	_outline.show_footprint(_grid, cells)


func _is_preview_valid() -> bool:
	if _selected == null or _grid == null:
		return false
	var cells: Array[Vector2i] = _selected.get_footprint_cells_at(_preview_anchor, _preview_yaw)
	return _grid.can_occupy_cells(cells, _selected.get_ignore_cells())


func _commit_preview() -> void:
	_selected.apply_placement(_preview_anchor, _preview_yaw)
	_after_placeable_moved(_selected)


func _revert_selection() -> void:
	if _selected == null:
		return
	_selected.apply_placement(_original_anchor, _original_yaw)
	_after_placeable_moved(_selected)


func _after_placeable_moved(placeable: Node3D) -> void:
	if placeable.is_in_group("reception_tables"):
		var queue := get_tree().get_first_node_in_group("customer_queue")
		if queue and queue.has_method("refresh_queue_layout"):
			queue.refresh_queue_layout()


func _clear_selection(keep_placement: bool) -> void:
	if not keep_placement and _selected:
		_revert_selection()
	_selected = null
	_preview.hide_preview()
	_outline.hide_outline()
	selection_changed.emit(null)
	if _ui and _ui.has_method("on_selection_changed"):
		_ui.on_selection_changed(null)


func _raycast_placeable(screen_position: Vector2) -> Node3D:
	if _camera == null:
		_bind_camera()
	if _camera == null:
		return null
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	var space := get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
	query.collision_mask = PLACEABLE_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	return _placeable_from_node(hit.collider as Node)


func _placeable_from_node(node: Node) -> Node3D:
	var current := node
	while current:
		if WarehousePlaceableScript.is_placeable(current):
			return current as Node3D
		current = current.get_parent()
	return null


func _pick_floor(screen_position: Vector2) -> Vector3:
	if _camera == null or _grid == null:
		return Vector3.INF
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return Vector3.INF
	var plane_y := WarehouseGrid.WAREHOUSE_FLOOR_SURFACE_Y
	var t := (plane_y - origin.y) / direction.y
	if t <= 0.0:
		return Vector3.INF
	var hit := origin + direction * t
	var cell := _grid.world_to_cell(hit)
	if not _grid.is_warehouse_cell(cell):
		return Vector3.INF
	return Vector3(hit.x, _grid.walk_surface_y(cell), hit.z)
