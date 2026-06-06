class_name CustomerPedestrian
extends Node3D

## Exterior walker that looks like decorative foot traffic but carries order data.
## Converts into a warehouse Customer only after reaching the entrance.

signal ready_for_warehouse_entry(pedestrian: CustomerPedestrian)

const PedestrianRolesScript = preload("res://scripts/gameplay/pedestrian_roles.gd")
const CharacterAnimationUtilsScript = preload(
	"res://scripts/shared/character_animation_utils.gd"
)

const PEDESTRIAN_SCALE := 1.0
const ARRIVE_DISTANCE := 0.12

var order: Dictionary = {}
var model_path: String = ""

var _speed: float = 1.6
var _waypoints: Array[Vector3] = []
var _waypoint_index := 0
var _heading: Vector3 = Vector3.ZERO
var _anim: AnimationPlayer
var _walk_anim_name: String = ""
var _committed := false


func setup(
	character_scene: PackedScene,
	order_data: Dictionary,
	waypoints: Array[Vector3],
	speed: float
) -> void:
	order = order_data.duplicate()
	_speed = speed
	_waypoints = waypoints.duplicate()
	if _waypoints.size() < 2:
		push_warning("CustomerPedestrian: need at least two waypoints.")
		return

	var model: Node3D = character_scene.instantiate()
	model.scale = Vector3.ONE * PEDESTRIAN_SCALE
	CharacterModelCleanup.strip_accessories(model)
	add_child(model)

	_anim = CharacterAnimationUtilsScript.find_animation_player(model)
	_walk_anim_name = CharacterAnimationUtilsScript.resolve_anim_name(
		_anim, ["walk", "Walk", "run", "Run"]
	)
	_play_walk()
	position = _waypoints[0]
	_waypoint_index = 1
	_set_heading_toward(_waypoints[_waypoint_index])
	add_to_group(PedestrianRolesScript.GROUP_CUSTOMER_APPROACH)


func has_order() -> bool:
	return not order.is_empty()


func get_order() -> Dictionary:
	return order.duplicate()


func is_decorative() -> bool:
	return false


func _process(delta: float) -> void:
	if _committed or _waypoints.is_empty() or _waypoint_index >= _waypoints.size():
		return
	position += _heading * _speed * delta
	var target := _waypoints[_waypoint_index]
	if position.distance_to(target) <= ARRIVE_DISTANCE:
		position = target
		_waypoint_index += 1
		if _waypoint_index >= _waypoints.size():
			_commit_entry()
			return
		_set_heading_toward(_waypoints[_waypoint_index])
	elif _heading.dot(target - position) < 0.0:
		_commit_entry()


func _commit_entry() -> void:
	if _committed:
		return
	_committed = true
	ready_for_warehouse_entry.emit(self)


func _set_heading_toward(target: Vector3) -> void:
	_heading = target - position
	_heading.y = 0.0
	if _heading.length_squared() > 0.0001:
		_heading = _heading.normalized()
	_face_heading()


func _face_heading() -> void:
	if _heading.length_squared() < 0.001:
		return
	rotation.y = atan2(_heading.x, _heading.z)


func _play_walk() -> void:
	if _anim == null or _walk_anim_name.is_empty():
		return
	var animation: Animation = _anim.get_animation(_walk_anim_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_LINEAR
	_anim.play(_walk_anim_name)
