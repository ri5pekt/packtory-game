class_name WorkerCleaningPlanner
extends RefCounted

## Picks the nearest floor garbage for a worker with Cleaning enabled.


static func plan_next(worker: Worker, tree: SceneTree, pending: Array) -> QueuedAction:
	if worker == null or tree == null:
		return null
	if worker.is_packing() or worker.has_package():
		return null
	var state := ProjectedState.after_actions(worker, null, pending)
	var garbage: Node3D = _find_nearest_garbage(worker, tree, state)
	if garbage == null:
		return null
	var action := QueuedAction.make_clean_garbage(garbage)
	if state.can_apply(action, null):
		return action
	return null


static func _find_nearest_garbage(worker: Worker, tree: SceneTree, state: ProjectedState) -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := INF
	for node in tree.get_nodes_in_group("floor_garbage"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("clean"):
			continue
		var key := node.get_instance_id()
		if state.consumed_clean_targets.has(key):
			continue
		var offset: Vector3 = node.global_position - worker.global_position
		offset.y = 0.0
		var dist: float = offset.length_squared()
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = node
	return nearest
