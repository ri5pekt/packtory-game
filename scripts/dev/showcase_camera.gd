extends Node3D

## Simple orthographic orbit camera for the character showcase.

@export var pan_speed: float = 0.012
@export var zoom_min: float = 8.0
@export var zoom_max: float = 42.0
@export var zoom_sensitivity: float = 0.08

const ISO_ROTATION := Vector3(-30.0, 45.0, 0.0)
const ISO_DISTANCE := 24.0
const DEFAULT_ZOOM := 20.0

@onready var camera: Camera3D = $Camera3D

var _focus := Vector3.ZERO


func _ready() -> void:
	_configure_camera()
	_update_transform()


func set_focus(world_position: Vector3) -> void:
	_focus = world_position
	_update_transform()


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
	camera.size = DEFAULT_ZOOM
	_update_transform()


func _configure_camera() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = ISO_ROTATION
	camera.position = camera.transform.basis.z * ISO_DISTANCE
	camera.size = DEFAULT_ZOOM
	camera.near = 0.25
	camera.far = 120.0
	camera.current = true


func _update_transform() -> void:
	global_position = _focus
