class_name WalkInteraction
extends RefCounted

## Walk worker to an approach point, face a target, then run a callback.


static func walk_face_then(
	actor: Worker,
	approach: Vector3,
	face_target: Vector3,
	on_arrive: Callable
) -> void:
	if actor == null:
		on_arrive.call(false)
		return
	actor.walk_to_world(
		approach,
		func() -> void:
			if not is_instance_valid(actor):
				on_arrive.call(false)
				return
			actor.face_world(face_target)
			on_arrive.call(true)
	)
