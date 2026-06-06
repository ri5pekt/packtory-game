class_name WorkerContextActions
extends RefCounted

## Context menu actions shown when the player taps a worker.


static func actions_for_worker(worker) -> Array:
	var actions: Array = []
	if worker == null:
		return actions
	if worker.has_method("is_manager") and not worker.is_manager():
		actions.append({"id": "assign_tasks", "label": "Assign Worker Tasks"})
	actions.append({"id": "select_worker", "label": "Select Worker"})
	return actions
