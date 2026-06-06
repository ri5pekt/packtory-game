class_name ActionQueue
extends Node

## Plans and runs worker actions one at a time with projected-state validation.

signal queue_changed(actions: Array)
signal action_failed(reason: String)

var _pending: Array[QueuedAction] = []
var _running := false
var _executor: Node = null
var _get_worker: Callable
var _get_queue: Callable


func configure(executor: Node, worker_getter: Callable, queue_getter: Callable) -> void:
	_executor = executor
	_get_worker = worker_getter
	_get_queue = queue_getter


func get_actions() -> Array:
	return _pending.duplicate()


func is_busy() -> bool:
	var worker: Worker = _resolve_worker()
	if worker == null:
		return _running
	return _running or worker.is_moving() or worker.is_packing()


func clear_queue() -> void:
	_pending.clear()
	_running = false
	_emit_changed()


func enqueue(action: QueuedAction) -> bool:
	if action == null:
		return false
	if not can_enqueue(action):
		return false
	_pending.append(action)
	_emit_changed()
	_try_advance()
	return true


func can_enqueue(action: QueuedAction) -> bool:
	var worker := _resolve_worker()
	if worker == null:
		return false
	var customer_queue: CustomerQueue = _resolve_queue()
	var state := ProjectedState.after_actions(worker, customer_queue, _pending)
	return state.can_apply(action, customer_queue)


func projected_state() -> ProjectedState:
	var worker := _resolve_worker()
	var customer_queue := _resolve_queue()
	return ProjectedState.after_actions(worker, customer_queue, _pending)


func _try_advance() -> void:
	if _running:
		return
	if _pending.is_empty():
		return
	var worker := _resolve_worker()
	if worker == null:
		return
	if worker.is_moving() or worker.is_packing():
		return
	_running = true
	var action := _pending[0]
	if _executor and _executor.has_method("execute_queued_action"):
		_executor.execute_queued_action(action, _on_action_finished)
	else:
		_on_action_finished(false)


func _on_action_finished(success: bool) -> void:
	_running = false
	if _pending.is_empty():
		_emit_changed()
		return
	if not success:
		var reason := "Action could not be completed."
		if _executor != null and _executor.has_method("take_action_failure_reason"):
			var custom: String = _executor.call("take_action_failure_reason")
			if not custom.is_empty():
				reason = custom
		action_failed.emit(reason)
		_pending.clear()
		_emit_changed()
		return
	_pending.pop_front()
	_emit_changed()
	call_deferred("_try_advance")


func _emit_changed() -> void:
	queue_changed.emit(get_actions())


func _resolve_worker() -> Worker:
	if _get_worker.is_valid():
		return _get_worker.call() as Worker
	return null


func _resolve_queue() -> CustomerQueue:
	if _get_queue.is_valid():
		return _get_queue.call() as CustomerQueue
	return null
