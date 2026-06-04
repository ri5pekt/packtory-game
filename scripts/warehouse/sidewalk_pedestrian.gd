class_name SidewalkPedestrian
extends Node3D

## A character that walks in a straight line from `start` to `end` along any axis,
## then despawns. Direction is derived from the route, so the same actor serves the
## east-west road sidewalks and the north-south entrance walkway.

# Match the manager (worker model at scale 1.0) so foot traffic reads at one size.
const PEDESTRIAN_SCALE := 1.0
const ARRIVE_DISTANCE := 0.1

var _speed: float
var _heading: Vector3
var _end: Vector3
var _anim: AnimationPlayer
var _walk_anim_name: String = ""


func setup(
	character_scene: PackedScene,
	start: Vector3,
	end: Vector3,
	speed: float
) -> void:
	_speed = speed
	_end = end
	_heading = (end - start)
	_heading.y = 0.0
	_heading = _heading.normalized()

	var model: Node3D = character_scene.instantiate()
	model.scale = Vector3.ONE * PEDESTRIAN_SCALE
	add_child(model)

	_anim = _find_animation_player(model)
	_walk_anim_name = _resolve_anim_name(["walk", "Walk", "run", "Run"])
	_play_walk()

	_face_heading()
	position = start


func _process(delta: float) -> void:
	position += _heading * _speed * delta
	if position.distance_to(_end) <= ARRIVE_DISTANCE:
		queue_free()
		return
	# Despawn once we have travelled past the end along the heading.
	if _heading.dot(_end - position) < 0.0:
		queue_free()


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


func _resolve_anim_name(preferred_names: Array[String]) -> String:
	if _anim == null:
		return ""
	for anim_name in preferred_names:
		if _anim.has_animation(anim_name):
			return anim_name
	return ""


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
