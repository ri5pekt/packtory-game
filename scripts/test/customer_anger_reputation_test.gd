extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/customer_anger_reputation_test.gd

const CustomerScript = preload("res://scripts/gameplay/customer.gd")
const CustomerAngerReputationConfigScript = preload(
	"res://scripts/gameplay/customer_anger_reputation_config.gd"
)
const CustomerPatienceConfigScript = preload("res://scripts/gameplay/customer_patience_config.gd")
const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const CustomerStatusScript = preload("res://scripts/gameplay/customer_status.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const ReputationConfigScript = preload("res://scripts/gameplay/reputation_config.gd")
const ReputationManagerScript = preload("res://scripts/gameplay/reputation_manager.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("waiting customer does not reduce reputation", await _test_waiting_no_penalty())
	failed += _assert("angry customer reduces reputation", await _test_angry_reduces_reputation())
	failed += _assert("angry customer keeps waiting bubble", await _test_angry_indicator_visible())
	failed += _assert("serving angry customer stops penalty", await _test_serving_stops_penalty())
	failed += _assert("removing angry customer stops penalty", await _test_removing_stops_penalty())

	if failed == 0:
		print("customer_anger_reputation_test: ALL PASSED")
		quit(0)
	else:
		push_error("customer_anger_reputation_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_autoloads() -> void:
	if root.get_node_or_null("GameTimeManager") == null:
		var game_time: Node = GameTimeManagerScript.new()
		game_time.name = "GameTimeManager"
		root.add_child(game_time)
	if root.get_node_or_null("ReputationManager") == null:
		var reputation: Node = ReputationManagerScript.new()
		reputation.name = "ReputationManager"
		root.add_child(reputation)


func _game_time() -> Node:
	return root.get_node("GameTimeManager")


func _reputation() -> Node:
	return root.get_node("ReputationManager")


func _make_queue() -> Node:
	var queue: Node = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	queue.call("_reset_anger_reputation_penalty_state")
	return queue


func _make_customer(at: Vector3) -> Customer:
	var customer: Customer = CustomerScript.new()
	customer.name = "AngryCustomer"
	root.add_child(customer)
	customer.position = at
	customer.ensure_status_indicator()
	customer.mark_entered_warehouse()
	customer.state = Customer.State.PENDING
	return customer


func _reset_scene() -> void:
	_reputation().reset_for_new_game()
	_game_time().reset_for_new_game()
	_game_time().set_time(1, 500)


func _start_waiting(customer: Customer, start_minute: int = 500) -> void:
	_game_time().set_time(1, start_minute)
	customer.begin_queue_wait_tracking()


func _make_angry_customer(queue: Node) -> Customer:
	var customer := _make_customer(Vector3(16.0, 0.0, 15.0))
	queue._customers.append(customer)
	_start_waiting(customer, 500)
	_game_time().set_time(
		1,
		500 + int(CustomerPatienceConfigScript.ANGRY_AFTER_GAME_MINUTES) + 1
	)
	queue._update_status_indicators()
	return customer


func _test_waiting_no_penalty() -> bool:
	await _reset_scene()
	var queue := _make_queue()
	var customer := _make_customer(Vector3(16.0, 0.0, 15.0))
	queue._customers.append(customer)
	_start_waiting(customer, 500)
	_game_time().set_time(1, 502)
	var loss: int = queue.advance_anger_reputation_penalty(
		CustomerAngerReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES
	)
	customer.queue_free()
	queue.queue_free()
	return (
		loss == 0
		and int(_reputation().call("get_reputation")) == ReputationConfigScript.STARTING_REPUTATION
		and queue.count_angry_customers() == 0
	)


func _test_angry_reduces_reputation() -> bool:
	await _reset_scene()
	var queue := _make_queue()
	var customer := _make_angry_customer(queue)
	var before: int = int(_reputation().call("get_reputation"))
	var loss: int = queue.advance_anger_reputation_penalty(
		CustomerAngerReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES
	)
	var after: int = int(_reputation().call("get_reputation"))
	customer.queue_free()
	queue.queue_free()
	return (
		queue.count_angry_customers() == 1
		and customer.get_queue_status() == CustomerStatusScript.Kind.ANGRY
		and loss >= CustomerAngerReputationConfigScript.REPUTATION_LOSS_PER_ANGRY_CUSTOMER_PER_TICK
		and after < before
	)


func _test_angry_indicator_visible() -> bool:
	await _reset_scene()
	var queue := _make_queue()
	var customer := _make_angry_customer(queue)
	var visible: bool = customer.is_queue_status_visible()
	var bubble_status: int = customer.get_queue_status()
	var patience_status: int = customer.get_patience_queue_status()
	customer.queue_free()
	queue.queue_free()
	return (
		visible
		and bubble_status == CustomerStatusScript.Kind.ORDER
		and patience_status == CustomerStatusScript.Kind.ANGRY
	)


func _test_serving_stops_penalty() -> bool:
	await _reset_scene()
	var queue := _make_queue()
	var customer := _make_angry_customer(queue)
	queue.advance_anger_reputation_penalty(
		CustomerAngerReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES
	)
	var after_first: int = int(_reputation().call("get_reputation"))
	queue.take_order(customer)
	var loss: int = queue.advance_anger_reputation_penalty(
		CustomerAngerReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES * 2.0
	)
	customer.queue_free()
	queue.queue_free()
	return (
		queue.count_angry_customers() == 0
		and loss == 0
		and int(_reputation().call("get_reputation")) == after_first
	)


func _test_removing_stops_penalty() -> bool:
	await _reset_scene()
	var queue := _make_queue()
	var customer := _make_angry_customer(queue)
	queue.advance_anger_reputation_penalty(
		CustomerAngerReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES
	)
	var after_first: int = int(_reputation().call("get_reputation"))
	queue._customers.erase(customer)
	customer.begin_depart([Vector3(20.0, 0.0, 24.0)])
	await process_frame
	var loss: int = queue.advance_anger_reputation_penalty(
		CustomerAngerReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES * 2.0
	)
	customer.queue_free()
	queue.queue_free()
	return (
		queue.count_angry_customers() == 0
		and loss == 0
		and int(_reputation().call("get_reputation")) == after_first
	)
