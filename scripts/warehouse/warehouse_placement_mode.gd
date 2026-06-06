class_name WarehousePlacementMode
extends Node

## Place new warehouse equipment from boxed inventory items.

signal mode_changed(active: bool)

const ProductShelfScript = preload("res://scripts/warehouse/product_shelf.gd")
const StorageShelfScript = preload("res://scripts/warehouse/storage_shelf.gd")
const WarehousePlaceableScript = preload("res://scripts/warehouse/warehouse_placeable.gd")
const PlacementPreviewScript = preload("res://scripts/warehouse/placement_preview.gd")
const PlaceableSelectionOutlineScript = preload(
	"res://scripts/warehouse/placeable_selection_outline.gd"
)

var _grid: WarehouseGrid
var _camera: Camera3D
var _preview: Node3D
var _outline: Node3D
var _ui: Control

const PLACEABLE_TYPES := {
	"shelf": ProductShelfScript,
	"storage_shelf": StorageShelfScript,
}

var _active := false
var _ghost: Node3D
var _placeable_type := ""
var _box_data: Dictionary = {}
var _preview_anchor := Vector2i.ZERO
var _preview_yaw := 0.0


func _ready() -> void:
	add_to_group("warehouse_placement_mode")
	_grid = get_node("/root/GridService") as WarehouseGrid
	_preview = PlacementPreviewScript.new()
	_preview.name = "PlacementPreview"
	add_child(_preview)
	_outline = PlaceableSelectionOutlineScript.new()
	_outline.name = "PlacementOutline"
	add_child(_outline)
	call_deferred("_bind_ui")
	call_deferred("_bind_camera")


func _bind_ui() -> void:
	_ui = get_node_or_null("../UI/PlacementModeUI") as Control
	if _ui and _ui.has_method("bind_placement_mode"):
		_ui.bind_placement_mode(self)


func _bind_camera() -> void:
	var rig := get_node_or_null("../IsoCameraRig") as Node3D
	if rig and rig.has_method("get_camera"):
		_camera = rig.get_camera()


func is_active() -> bool:
	return _active


func get_box_data() -> Dictionary:
	return _box_data.duplicate(true)


func begin_placement(box_data: Dictionary) -> bool:
	if _active or box_data.is_empty():
		return false
	_placeable_type = String(box_data.get("placeable_type", ""))
	var placeable_script: Script = PLACEABLE_TYPES.get(_placeable_type, null)
	if placeable_script == null:
		_warn("That boxed item cannot be placed yet.")
		return false
	_box_data = box_data.duplicate(true)
	_ghost = placeable_script.new()
	_ghost.name = "PlacementGhost%s" % _placement_name_prefix(_placeable_type)
	add_child(_ghost)
	_preview_anchor = _default_anchor_cell()
	_preview_yaw = 0.0
	_ghost.setup(_grid.cell_to_world(_preview_anchor), _preview_yaw)
	_ghost.release_placement_cells()
	_active = true
	mode_changed.emit(true)
	_update_preview()
	if _ui and _ui.has_method("on_mode_entered"):
		_ui.on_mode_entered(_box_data)
	return true


func handle_tap(screen_position: Vector2) -> bool:
	if not _active:
		return false
	if _ui and _ui.has_method("consumes_tap") and _ui.consumes_tap(screen_position):
		return true
	var floor := _pick_floor(screen_position)
	if floor != Vector3.INF:
		_move_preview_to_cell(_grid.world_to_cell(floor))
	return true


func rotate_preview() -> void:
	if not _active:
		return
	_preview_yaw = fmod(_preview_yaw + 180.0, 360.0)
	_update_preview()


func apply_placement() -> bool:
	if not _active or _ghost == null:
		return false
	if not is_preview_valid():
		_warn("Can't place here — blocked or outside the warehouse.")
		return false
	var parent := get_tree().get_first_node_in_group("warehouse_shelves")
	if parent == null:
		parent = self
	if _ghost.get_parent() == self:
		remove_child(_ghost)
	parent.add_child(_ghost)
	_ghost.name = "%s_%d" % [
		_placement_name_prefix(_placeable_type),
		int(_box_data.get("order_id", 0)),
	]
	if _placeable_type == "shelf":
		_ghost.add_to_group("shelves")
	_ghost.apply_placement(_preview_anchor, _preview_yaw)
	_consume_inventory_box()
	_ghost = null  # transferred to parent — must be nil before _clear_mode() to prevent queue_free
	_clear_mode()
	return true


func cancel_placement() -> void:
	if not _active:
		return
	_clear_mode()


func is_preview_valid() -> bool:
	if _ghost == null or _grid == null:
		return false
	var cells: Array[Vector2i] = _ghost.get_footprint_cells_at(_preview_anchor, _preview_yaw)
	return _grid.can_occupy_cells(cells, _ghost.get_ignore_cells())


func get_preview_anchor() -> Vector2i:
	return _preview_anchor


func set_preview_anchor(cell: Vector2i) -> void:
	_move_preview_to_cell(cell)


func _default_anchor_cell() -> Vector2i:
	for z in range(12, 15):
		for x in range(14, 21):
			var cell := Vector2i(x, z)
			if _grid.can_occupy_cells([cell], []):
				return cell
	return Vector2i(14, 14)


func _move_preview_to_cell(cell: Vector2i) -> void:
	if _ghost == null or _grid == null:
		return
	if not _grid.is_warehouse_cell(cell):
		return
	_preview_anchor = cell
	_update_preview()


func _update_preview() -> void:
	if _ghost == null:
		return
	_ghost.preview_placement(_preview_anchor, _preview_yaw)
	var cells: Array[Vector2i] = _ghost.get_footprint_cells_at(_preview_anchor, _preview_yaw)
	var valid := is_preview_valid()
	_preview.show_footprint(_grid, cells, valid)
	_outline.show_footprint(_grid, cells)


func _consume_inventory_box() -> void:
	var box_id := int(_box_data.get("placeable_box_id", -1))
	if box_id < 0:
		return
	var removed: Dictionary = {}
	for node in get_tree().get_nodes_in_group("workers"):
		var worker := node as Worker
		if worker == null or not worker.has_method("find_placeable_box_index"):
			continue
		if worker.find_placeable_box_index(box_id) < 0:
			continue
		removed = worker.remove_placeable_box(box_id)
		break
	var order_id := int(removed.get("order_id", _box_data.get("order_id", 0)))
	var manager := get_node_or_null("/root/IncomingDeliveryManager")
	if manager and manager.has_method("complete_order") and order_id > 0:
		manager.complete_order(order_id)


func _placement_name_prefix(placeable_type: String) -> String:
	match placeable_type:
		"storage_shelf":
			return "StorageShelf"
		_:
			return "Shelf"


func _clear_mode() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_placeable_type = ""
	_box_data = {}
	_active = false
	_preview.hide_preview()
	_outline.hide_outline()
	mode_changed.emit(false)
	if _ui and _ui.has_method("on_mode_exited"):
		_ui.on_mode_exited()


func _warn(message: String) -> void:
	var alerts := get_node_or_null("/root/AlertMessages")
	if alerts and alerts.has_method("warn"):
		alerts.warn(message)


func _pick_floor(screen_position: Vector2) -> Vector3:
	if _camera == null:
		_bind_camera()
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
