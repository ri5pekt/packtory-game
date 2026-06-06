extends Node

## Autonomous worker behaviors gated by task assignments.

const WorkerCleaningPlannerScript = preload("res://scripts/gameplay/worker_cleaning_planner.gd")
const WorkerStoragePlannerScript = preload("res://scripts/gameplay/worker_storage_planner.gd")
const WorkerTaskConfigScript = preload("res://scripts/gameplay/worker_task_config.gd")
const WorkerAutomationQueueScript = preload("res://scripts/gameplay/worker_automation_queue.gd")

const TICK_SECONDS := 0.6

var _queues: Dictionary = {}
var _tick_accum := 0.0


func _ready() -> void:
	add_to_group("worker_task_manager")
	set_process(true)


func _process(delta: float) -> void:
	_tick_accum += delta
	if _tick_accum < TICK_SECONDS:
		return
	_tick_accum = 0.0
	_tick_workers()


func reset_for_new_game() -> void:
	for queue in _queues.values():
		if is_instance_valid(queue):
			queue.queue_free()
	_queues.clear()


func get_queue_for_worker(worker: Worker):
	if worker == null:
		return null
	var key := worker.get_instance_id()
	if _queues.has(key) and is_instance_valid(_queues[key]):
		return _queues[key]
	var queue = WorkerAutomationQueueScript.new()
	queue.name = "AutomationQueue"
	worker.add_child(queue)
	queue.bind_worker(worker)
	_queues[key] = queue
	return queue


func _tick_workers() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("workers"):
		if not node is Worker:
			continue
		var worker := node as Worker
		if not _should_automate(worker):
			continue
		var queue = get_queue_for_worker(worker)
		if queue == null:
			continue
		if queue.is_busy():
			queue.tick()
			continue
		if queue.has_pending():
			queue.tick()
			continue
		if not _has_automation_tasks(worker):
			continue
		var action := _plan_next_action(worker, tree, queue.get_actions())
		if action != null:
			queue.enqueue(action)


func _has_automation_tasks(worker: Worker) -> bool:
	return (
		worker.is_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE)
		or worker.is_task_enabled(WorkerTaskConfigScript.CATEGORY_CLEANING)
	)


func _plan_next_action(worker: Worker, tree: SceneTree, pending: Array) -> QueuedAction:
	if worker.is_task_enabled(WorkerTaskConfigScript.CATEGORY_CLEANING):
		var clean_action := WorkerCleaningPlannerScript.plan_next(worker, tree, pending)
		if clean_action != null:
			return clean_action
	if worker.is_task_enabled(WorkerTaskConfigScript.CATEGORY_STORAGE):
		return WorkerStoragePlannerScript.plan_next(worker, tree, pending)
	return null


func _should_automate(worker: Worker) -> bool:
	if worker.is_manager():
		return false
	var gameplay := get_tree().get_first_node_in_group("gameplay_input")
	if gameplay != null and gameplay.has_method("get_selected_worker"):
		if gameplay.get_selected_worker() == worker:
			return false
	return true
