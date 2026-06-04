class_name RoadCar
extends Node3D

# Sized to sit in a 1 m lane and stay proportional to the (0.72 m) pedestrians.
const CAR_SCALE := 0.5

var _speed: float
var _direction: float
var _end_x: float


func setup(
	car_scene: PackedScene,
	start_x: float,
	lane_position: Vector3,
	direction: float,
	speed: float,
	end_x: float
) -> void:
	_speed = speed
	_direction = direction
	_end_x = end_x

	var model: Node3D = car_scene.instantiate()
	model.scale = Vector3.ONE * CAR_SCALE
	add_child(model)

	rotation.y = PI * 0.5 if direction > 0.0 else -PI * 0.5
	position = Vector3(start_x, lane_position.y, lane_position.z)


func _process(delta: float) -> void:
	position.x += _direction * _speed * delta
	if _direction > 0.0 and position.x >= _end_x:
		queue_free()
	elif _direction < 0.0 and position.x <= _end_x:
		queue_free()
