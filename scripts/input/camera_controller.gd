extends Node3D

signal focus_changed(world_position: Vector3)

@export var pan_speed: float = 0.015
@export var zoom_min: float = 4.0
@export var zoom_max: float = 50.0
@export var zoom_sensitivity: float = 0.08

# Default framing: tighter than the full warehouse so the work zone fills the screen.
const VIEW_SPAN_FACTOR := 1.0

@onready var camera: Camera3D = $Camera3D

const ISO_ROTATION := Vector3(-30.0, 45.0, 0.0)
const ISO_DISTANCE := 30.0

var _grid: WarehouseGrid
var _focus: Vector3 = Vector3.ZERO
var _default_zoom: float = 18.0


func _ready() -> void:
	add_to_group("camera_rig")
	_grid = get_node("/root/GridService") as WarehouseGrid
	_focus = _grid.get_warehouse_center_world()
	_configure_camera()
	_update_transform()
	call_deferred("_apply_initial_zoom")


func _configure_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = ISO_ROTATION
	# Offset along local +Z (behind the lens) so the camera isn't inside the floor plane.
	camera.position = camera.transform.basis.z * ISO_DISTANCE
	camera.near = 0.5
	camera.far = 200.0
	camera.current = true


func _apply_initial_zoom() -> void:
	_default_zoom = _compute_grid_fit_zoom()
	camera.size = _default_zoom


func _compute_grid_fit_zoom() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var view_span := (
		float(maxi(WarehouseGrid.WAREHOUSE_SIZE.x, WarehouseGrid.WAREHOUSE_SIZE.y))
		* WarehouseGrid.CELL_SIZE
		* VIEW_SPAN_FACTOR
	)
	# camera.size is the visible world height; make sure the span fits width too.
	var width_fit := view_span / maxf(aspect, 0.001)
	return clampf(maxf(view_span, width_fit), zoom_min, zoom_max)


func get_camera() -> Camera3D:
	return camera


func get_reference_ortho_size() -> float:
	return _default_zoom


func get_focus() -> Vector3:
	return _focus


func pan_screen_delta(screen_delta: Vector2) -> void:
	var scale := camera.size * pan_speed
	var basis := camera.global_transform.basis
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	_focus += (-right * screen_delta.x + forward * screen_delta.y) * scale
	_update_transform()


func zoom_by(factor: float) -> void:
	if factor <= 0.0:
		return
	camera.size = clampf(camera.size / factor, zoom_min, zoom_max)


func reset_view() -> void:
	_focus = _grid.get_warehouse_center_world()
	camera.size = _default_zoom
	_update_transform()


func apply_wheel_zoom(direction: float) -> void:
	if is_zero_approx(direction):
		return
	var factor := 1.0 + zoom_sensitivity * direction
	zoom_by(factor)


func _update_transform() -> void:
	global_position = _focus
	focus_changed.emit(_focus)
