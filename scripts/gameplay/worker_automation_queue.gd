extends Node

## Per-worker action queue for autonomous tasks (separate from the player queue).

const WorkerActionExecutorScript = preload("res://scripts/gameplay/worker_action_executor.gd")

signal action_finished(success: bool)

var _worker: Worker
var _pending: Array[QueuedAction] = []
var _running := false


func bind_worker(worker: Worker) -> void:
	_worker = worker


func get_worker() -> Worker:
	return _worker


func get_actions() -> Array:
	return _pending.duplicate()


func has_pending() -> bool:
	return not _pending.is_empty()


func is_busy() -> bool:
	if _worker == null:
		return _running
	return _running or _worker.is_moving() or _worker.is_packing()


func clear_queue() -> void:
	_pending.clear()
	_running = false


func enqueue(action: QueuedAction) -> bool:
	if action == null or _worker == null:
		return false
	if not can_enqueue(action):
		return false
	_pending.append(action)
	_try_advance()
	return true


func can_enqueue(action: QueuedAction) -> bool:
	if _worker == null:
		return false
	var state := projected_state()
	return state.can_apply(action, null)


func projected_state() -> ProjectedState:
	return ProjectedState.after_actions(_worker, null, _pending)


func tick() -> void:
	_try_advance()


func _try_advance() -> void:
	if _running or _worker == null:
		return
	if _pending.is_empty():
		return
	if _worker.is_moving() or _worker.is_packing():
		return
	_running = true
	var action := _pending[0]
	WorkerActionExecutorScript.execute(_worker, action, _on_action_finished)


func _on_action_finished(success: bool) -> void:
	_running = false
	action_finished.emit(success)
	if _pending.is_empty():
		return
	_pending.pop_front()
	call_deferred("_try_advance")
