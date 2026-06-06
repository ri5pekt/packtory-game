extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/customer_status_bubble_test.gd

const CustomerScript = preload("res://scripts/gameplay/customer.gd")
const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const CustomerStatusScript = preload("res://scripts/gameplay/customer_status.gd")
const CustomerPatienceConfigScript = preload("res://scripts/gameplay/customer_patience_config.gd")
const CustomerStatusIndicatorScript = preload("res://scripts/ui/customer_status_indicator.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const IconRegistry = preload("res://scripts/ui/icon_registry.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_game_time()
	var failed := 0
	failed += _assert("status kinds expose icons", _test_all_status_icons())
	failed += _assert("indicator shows and hides by status", _test_indicator_visibility())
	failed += _assert("multiple queued customers show bubbles", await _test_multiple_customer_bubbles())
	failed += _assert("bubble follows customer movement", await _test_bubble_follows_customer())
	failed += _assert("bubble clears when customer departs", _test_bubble_clears_on_depart())
	failed += _assert("queue resolves ready to leave status", _test_ready_to_leave_status())
	failed += _assert("front customer shows order icon", _test_front_customer_order_icon())
	failed += _assert("taken order shows product icons in bubble", _test_taken_order_bubble())
	failed += _assert("queue shows waiting icons not angry faces", _test_queue_waiting_not_angry())

	if failed == 0:
		print("customer_status_bubble_test: ALL PASSED")
		quit(0)
	else:
		push_error("customer_status_bubble_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _test_all_status_icons() -> bool:
	for kind in [
		CustomerStatusScript.Kind.WAITING,
		CustomerStatusScript.Kind.ORDER,
		CustomerStatusScript.Kind.HAPPY,
		CustomerStatusScript.Kind.ANGRY,
		CustomerStatusScript.Kind.IMPATIENT,
		CustomerStatusScript.Kind.READY_TO_LEAVE,
	]:
		if CustomerStatusScript.icon_for(kind) == null:
			return false
		if CustomerStatusScript.display_name(kind).is_empty():
			return false
	return not CustomerStatusScript.is_visible(CustomerStatusScript.Kind.NONE)


func _test_indicator_visibility() -> bool:
	var host := Node3D.new()
	host.name = "Host"
	root.add_child(host)
	var indicator = CustomerStatusIndicatorScript.new()
	host.add_child(indicator)
	indicator.set_status(CustomerStatusScript.Kind.WAITING)
	var shown := indicator.is_shown()
	indicator.clear()
	var hidden := not indicator.is_shown()
	host.queue_free()
	return shown and hidden


func _make_customer(at: Vector3) -> Customer:
	var customer: Customer = CustomerScript.new()
	customer.name = "TestCustomer"
	root.add_child(customer)
	customer.position = at
	customer.ensure_status_indicator()
	customer.mark_entered_warehouse()
	customer.state = Customer.State.PENDING
	return customer


func _test_multiple_customer_bubbles() -> bool:
	var queue: Node = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	await process_frame

	var customers: Array[Customer] = []
	for i in range(3):
		var customer := _make_customer(Vector3(16.0, 0.0, 15.0 + float(i)))
		queue._customers.append(customer)
		customers.append(customer)

	queue._update_status_indicators()
	var visible_count := 0
	for customer in customers:
		if customer.is_queue_status_visible():
			visible_count += 1

	queue.queue_free()
	for customer in customers:
		customer.queue_free()
	return visible_count == 3


func _test_bubble_follows_customer() -> bool:
	var customer := _make_customer(Vector3(10.0, 0.0, 12.0))
	customer.set_queue_status(CustomerStatusScript.Kind.WAITING)
	await process_frame
	var indicator := customer.get_node("StatusIndicator") as Node3D
	if indicator == null:
		customer.queue_free()
		return false
	var before := indicator.global_position
	customer.global_position = Vector3(18.0, 0.0, 20.0)
	await process_frame
	var after := indicator.global_position
	customer.queue_free()
	return before.distance_to(after) > 0.5


func _test_bubble_clears_on_depart() -> bool:
	var customer := _make_customer(Vector3(12.0, 0.0, 14.0))
	customer.set_queue_status(CustomerStatusScript.Kind.WAITING)
	if not customer.is_queue_status_visible():
		customer.queue_free()
		return false
	customer.begin_depart([Vector3(20.0, 0.0, 24.0)])
	var cleared := not customer.is_queue_status_visible()
	customer.queue_free()
	return cleared


func _test_ready_to_leave_status() -> bool:
	var queue: Node = CustomerQueueScript.new()
	root.add_child(queue)
	var customer := _make_customer(Vector3(16.0, 0.0, 15.0))
	queue._customers.append(customer)
	queue._delivery_customer = customer
	customer.set_waiting_pickup()
	var status: int = queue.resolve_customer_status_for_test(customer, 0)
	customer.queue_free()
	queue.queue_free()
	return status == CustomerStatusScript.Kind.READY_TO_LEAVE


func _ensure_game_time() -> void:
	if root.get_node_or_null("GameTimeManager") == null:
		var game_time: Node = GameTimeManagerScript.new()
		game_time.name = "GameTimeManager"
		root.add_child(game_time)


func _start_queue_wait(customer: Customer, start_minute: int = 500) -> void:
	var game_time := root.get_node("GameTimeManager")
	game_time.set_time(1, start_minute)
	customer.begin_queue_wait_tracking()


func _test_taken_order_bubble() -> bool:
	var queue: Node = CustomerQueueScript.new()
	root.add_child(queue)
	var front := _make_customer(Vector3(16.0, 0.0, 15.0))
	front.order = {"mouse": 1, "headphones": 2}
	queue._customers.append(front)
	queue.take_order(front)
	queue._update_status_indicators()
	var visible := front.is_queue_order_visible()
	var displayed: Dictionary = front.get_queue_displayed_order()
	front.queue_free()
	queue.queue_free()
	return (
		visible
		and int(displayed.get("mouse", 0)) == 1
		and int(displayed.get("headphones", 0)) == 2
	)


func _test_front_customer_order_icon() -> bool:
	var queue: Node = CustomerQueueScript.new()
	root.add_child(queue)
	var front := _make_customer(Vector3(16.0, 0.0, 15.0))
	queue._customers.append(front)
	queue._update_status_indicators()
	var status: int = queue.resolve_customer_status_for_test(front, 0)
	var icon := CustomerStatusScript.icon_for(status)
	front.queue_free()
	queue.queue_free()
	return (
		status == CustomerStatusScript.Kind.ORDER
		and icon != null
		and icon == IconRegistry.get_icon("package")
	)


func _test_queue_waiting_not_angry() -> bool:
	var queue: Node = CustomerQueueScript.new()
	root.add_child(queue)
	var front := _make_customer(Vector3(16.0, 0.0, 15.0))
	var back := _make_customer(Vector3(16.0, 0.0, 14.0))
	queue._customers.append(front)
	queue._customers.append(back)
	_start_queue_wait(back, 500)
	var game_time := root.get_node("GameTimeManager")
	game_time.set_time(
		1,
		500 + int(CustomerPatienceConfigScript.ANGRY_AFTER_GAME_MINUTES) + 1
	)
	queue._update_status_indicators()
	var front_status: int = queue.resolve_customer_status_for_test(front, 0)
	var back_status: int = queue.resolve_customer_status_for_test(back, 1)
	var back_patience: int = back.get_patience_queue_status()
	front.queue_free()
	back.queue_free()
	queue.queue_free()
	return (
		front_status == CustomerStatusScript.Kind.ORDER
		and back_status == CustomerStatusScript.Kind.WAITING
		and back_patience == CustomerStatusScript.Kind.ANGRY
	)
