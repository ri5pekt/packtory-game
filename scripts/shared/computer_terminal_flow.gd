class_name ComputerTerminalFlow
extends RefCounted

## Walk the manager to a workstation, face the monitor, then open the computer UI.


static func begin_enter(
	actor: Node3D,
	workstation: Node3D,
	computer_ui: Control,
	on_walk_started: Callable = Callable(),
	on_opened: Callable = Callable()
) -> bool:
	if actor == null or workstation == null or computer_ui == null:
		return false
	if not computer_ui.has_method("is_open") or computer_ui.is_open():
		return false
	if actor.has_method("is_packing") and actor.is_packing():
		return false
	if on_walk_started.is_valid():
		on_walk_started.call()
	actor.walk_to_world(
		workstation.get_approach_position(),
		func() -> void:
			if not is_instance_valid(actor) or not is_instance_valid(workstation):
				if on_opened.is_valid():
					on_opened.call(false)
				return
			if computer_ui.has_method("is_open") and computer_ui.is_open():
				if on_opened.is_valid():
					on_opened.call(false)
				return
			if actor.has_method("face_world"):
				actor.face_world(workstation.get_face_target())
			if computer_ui.has_method("open"):
				computer_ui.open()
			if on_opened.is_valid():
				on_opened.call(true)
	)
	return true
