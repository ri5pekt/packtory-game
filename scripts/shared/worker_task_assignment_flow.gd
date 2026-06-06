class_name WorkerTaskAssignmentFlow
extends RefCounted

## Walk the manager to a worker, face them, then open the task assignment UI.


static func begin_assign(
	manager,
	target,
	assignment_ui: Control,
	on_walk_started: Callable = Callable(),
	on_opened: Callable = Callable()
) -> bool:
	if manager == null or target == null or assignment_ui == null:
		return false
	if target.has_method("is_manager") and target.is_manager():
		return false
	if assignment_ui.has_method("is_open") and assignment_ui.is_open():
		return false
	if manager.has_method("is_packing") and manager.is_packing():
		return false
	if on_walk_started.is_valid():
		on_walk_started.call()
	var approach: Vector3 = target.get_approach_position() if target.has_method("get_approach_position") else target.global_position
	manager.walk_to_world(
		approach,
		func() -> void:
			if not is_instance_valid(manager) or not is_instance_valid(target):
				if on_opened.is_valid():
					on_opened.call(false)
				return
			if assignment_ui.has_method("is_open") and assignment_ui.is_open():
				if on_opened.is_valid():
					on_opened.call(false)
				return
			if manager.has_method("face_world"):
				var face_target: Vector3 = target.get_face_target() if target.has_method("get_face_target") else target.global_position
				manager.face_world(face_target)
			if assignment_ui.has_method("open_for_worker"):
				assignment_ui.open_for_worker(target)
			if on_opened.is_valid():
				on_opened.call(true)
	)
	return true
