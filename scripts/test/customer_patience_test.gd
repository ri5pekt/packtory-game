extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/customer_patience_test.gd

const CustomerScript = preload("res://scripts/gameplay/customer.gd")
const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const CustomerPatienceConfigScript = preload("res://scripts/gameplay/customer_patience_config.gd")
const CustomerStatusScript = preload("res://scripts/gameplay/customer_status.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_game_time()
	var failed := 0
	failed += _assert("customer starts as waiting", await _test_starts_waiting())
	failed += _assert("status becomes impatient after threshold", await _test_becomes_impatient())
	failed += _assert("status becomes angry after longer wait", await _test_becomes_angry())
	failed += _assert("bubble icon updates with status", await _test_bubble_updates())
	failed += _assert("served customer stops patience tracking", await _test_served_stops_tracking())
	failed += _assert("queue refresh updates bubbles over time", await _test_queue_refresh_over_time())

	if failed == 0:
		print("customer_patience_test: ALL PASSED")
		quit(0)
	else:
		push_error("customer_patience_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_game_time() -> void:
	if root.get_node_or_null("GameTimeManager") == null:
		var game_time: Node = GameTimeManagerScript.new()
		game_time.name = "GameTimeManager"
		root.add_child(game_time)


func _game_time() -> Node:
	return root.get_node("GameTimeManager")


func _make_queue() -> Node:
	var queue: Node = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	return queue


func _make_customer(at: Vector3) -> Customer:
	var customer: Customer = CustomerScript.new()
	customer.name = "PatienceCustomer"
	root.add_child(customer)
	customer.position = at
	customer.ensure_status_indicator()
	customer.mark_entered_warehouse()
	customer.state = Customer.State.PENDING
	return customer


func _start_waiting(customer: Customer, start_minute: int = 500) -> void:
	_game_time().set_time(1, start_minute)
	customer.begin_queue_wait_tracking()


func _test_starts_waiting() -> bool:
	_game_time().reset_for_new_game()
	var customer := _make_customer(Vector3(16.0, 0.0, 15.0))
	_start_waiting(customer, 500)
	_game_time().set_time(1, 501)
	var status: int = customer.get_patience_queue_status()
	customer.queue_free()
	return status == CustomerStatusScript.Kind.WAITING


func _test_becomes_impatient() -> bool:
	_game_time().reset_for_new_game()
	var customer := _make_customer(Vector3(16.0, 0.0, 15.0))
	_start_waiting(customer, 500)
	_game_time().set_time(
		1,
		500 + int(CustomerPatienceConfigScript.IMPATIENT_AFTER_GAME_MINUTES) + 1
	)
	var status: int = customer.get_patience_queue_status()
	customer.queue_free()
	return status == CustomerStatusScript.Kind.IMPATIENT


func _test_becomes_angry() -> bool:
	_game_time().reset_for_new_game()
	var customer := _make_customer(Vector3(16.0, 0.0, 15.0))
	_start_waiting(customer, 500)
	_game_time().set_time(
		1,
		500 + int(CustomerPatienceConfigScript.ANGRY_AFTER_GAME_MINUTES) + 1
	)
	var status: int = customer.get_patience_queue_status()
	customer.queue_free()
	return status == CustomerStatusScript.Kind.ANGRY


func _test_bubble_updates() -> bool:
	_game_time().reset_for_new_game()
	var queue := _make_queue()
	var customer := _make_customer(Vector3(16.0, 0.0, 15.0))
	queue._customers.append(customer)
	_start_waiting(customer, 500)
	_game_time().set_time(1, 501)
	queue._update_status_indicators()
	var waiting_icon := CustomerStatusScript.icon_for(customer.get_queue_status())
	_game_time().set_time(
		1,
		500 + int(CustomerPatienceConfigScript.ANGRY_AFTER_GAME_MINUTES) + 1
	)
	queue._update_status_indicators()
	var bubble_icon := CustomerStatusScript.icon_for(customer.get_queue_status())
	var patience_status: int = customer.get_patience_queue_status()
	customer.queue_free()
	queue.queue_free()
	return (
		waiting_icon != null
		and bubble_icon != null
		and customer.get_queue_status() == CustomerStatusScript.Kind.ORDER
		and patience_status == CustomerStatusScript.Kind.ANGRY
		and waiting_icon != bubble_icon
	)


func _test_served_stops_tracking() -> bool:
	_game_time().reset_for_new_game()
	var queue := _make_queue()
	var customer := _make_customer(Vector3(16.0, 0.0, 15.0))
	queue._customers.append(customer)
	_start_waiting(customer, 500)
	_game_time().set_time(
		1,
		500 + int(CustomerPatienceConfigScript.ANGRY_AFTER_GAME_MINUTES) + 1
	)
	queue.take_order(customer)
	queue._update_status_indicators()
	var still_tracking: bool = customer.is_tracking_queue_wait()
	var shows_order: bool = customer.is_queue_order_visible()
	customer.queue_free()
	queue.queue_free()
	return not still_tracking and shows_order


func _test_queue_refresh_over_time() -> bool:
	_game_time().reset_for_new_game()
	var queue := _make_queue()
	queue.call("_bind_patience_refresh")
	var front := _make_customer(Vector3(16.0, 0.0, 15.0))
	var back := _make_customer(Vector3(16.0, 0.0, 14.0))
	queue._customers.append(front)
	queue._customers.append(back)
	_start_waiting(back, 500)
	_game_time().set_running(true)
	_game_time().set_time(1, 501)
	queue._update_status_indicators()
	var before_bubble: int = back.get_queue_status()
	var before_patience: int = back.get_patience_queue_status()
	_game_time().advance_by_game_minutes(
		CustomerPatienceConfigScript.IMPATIENT_AFTER_GAME_MINUTES + 1.0
	)
	await process_frame
	var after_bubble: int = back.get_queue_status()
	var after_patience: int = back.get_patience_queue_status()
	front.queue_free()
	back.queue_free()
	queue.queue_free()
	return (
		before_bubble == CustomerStatusScript.Kind.WAITING
		and after_bubble == CustomerStatusScript.Kind.WAITING
		and before_patience == CustomerStatusScript.Kind.WAITING
		and after_patience == CustomerStatusScript.Kind.IMPATIENT
	)
