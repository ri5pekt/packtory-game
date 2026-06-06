extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/customer_traffic_test.gd

const CustomerTrafficConfigScript = preload("res://scripts/gameplay/customer_traffic_config.gd")
const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const CustomerScript = preload("res://scripts/gameplay/customer.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")
const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("morning traffic is moderate", _test_morning_traffic())
	failed += _assert("afternoon traffic is busiest", _test_afternoon_busiest())
	failed += _assert("evening traffic declines", _test_evening_declines())
	failed += _assert("night blocks new customer spawns", _test_night_no_spawns())
	failed += _assert("no new customers after 8:00 PM close", _test_no_spawn_after_close())
	failed += _assert("queue blocks spawn when store is closed", await _test_queue_respects_close())
	failed += _assert("existing queued customers remain valid after close", _test_existing_customers_valid())
	failed += _assert("queue refresh keeps waiting pickup customers deliverable", _test_queue_refresh_preserves_waiting_pickup())
	failed += _assert("delivery sync restores waiting pickup state", _test_sync_restores_waiting_pickup())

	if failed == 0:
		print("customer_traffic_test: ALL PASSED")
		quit(0)
	else:
		push_error("customer_traffic_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_autoloads() -> void:
	if root.get_node_or_null("GridService") == null:
		var grid_script: Script = load("res://scripts/autoload/grid_service.gd") as Script
		var grid: Node = grid_script.new()
		grid.name = "GridService"
		root.add_child(grid)
	if root.get_node_or_null("GameTimeManager") == null:
		var game_time: Node = GameTimeManagerScript.new()
		game_time.name = "GameTimeManager"
		root.add_child(game_time)


func _test_morning_traffic() -> bool:
	var period := CustomerTrafficConfigScript.traffic_period_at(540.0)
	var range := CustomerTrafficConfigScript.spawn_delay_range(540.0)
	return (
		period == CustomerTrafficConfigScript.PERIOD_MORNING
		and range.x >= 14.0
		and range.y <= 22.0
		and CustomerTrafficConfigScript.can_spawn_customers(540.0)
	)


func _test_afternoon_busiest() -> bool:
	var morning := CustomerTrafficConfigScript.spawn_delay_range(600.0)
	var afternoon := CustomerTrafficConfigScript.spawn_delay_range(840.0)
	return (
		CustomerTrafficConfigScript.traffic_period_at(840.0) == CustomerTrafficConfigScript.PERIOD_AFTERNOON
		and afternoon.x < morning.x
		and afternoon.y < morning.y
	)


func _test_evening_declines() -> bool:
	var afternoon := CustomerTrafficConfigScript.spawn_delay_range(900.0)
	var evening := CustomerTrafficConfigScript.spawn_delay_range(1110.0)
	return (
		CustomerTrafficConfigScript.traffic_period_at(1110.0) == CustomerTrafficConfigScript.PERIOD_EVENING
		and evening.x > afternoon.x
		and evening.y > afternoon.y
	)


func _test_night_no_spawns() -> bool:
	return (
		not CustomerTrafficConfigScript.can_spawn_customers(60.0)
		and CustomerTrafficConfigScript.traffic_period_at(60.0) == CustomerTrafficConfigScript.PERIOD_NIGHT
	)


func _test_no_spawn_after_close() -> bool:
	return (
		not CustomerTrafficConfigScript.can_spawn_customers(float(GameTimeConfigScript.STORE_CLOSE_MINUTES))
		and not CustomerTrafficConfigScript.can_spawn_customers(1230.0)
		and CustomerTrafficConfigScript.is_store_open(1199.0)
	)


func _test_queue_respects_close() -> bool:
	var game_time: Node = root.get_node("GameTimeManager")
	game_time.set_time(1, 1215)

	var queue = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	await process_frame

	queue._service_started = true
	queue._use_game_time_spawn = true
	queue._schedule_next_spawn_from_time(game_time.get_precise_minutes())
	queue._try_spawn_on_game_clock()
	var count_after_close: int = queue.get_customer_count() + queue._approaching_pedestrians.size()

	queue.queue_free()
	return queue._next_spawn_at_minutes < 0.0 and count_after_close == 0


func _test_existing_customers_valid() -> bool:
	var existing_order := {"mouse": 1, "headphones": 1}
	var customer: Customer = CustomerScript.new()
	customer.order = existing_order.duplicate()
	customer.state = Customer.State.WAITING_PICKUP

	var game_time: Node = root.get_node("GameTimeManager")
	game_time.set_time(1, 1230)

	var queue = CustomerQueueScript.new()
	root.add_child(queue)
	queue._customers.append(customer)
	queue._active_customer = customer
	queue._active_order = existing_order.duplicate()
	queue._service_started = true
	queue._use_game_time_spawn = true

	var still_valid: bool = (
		queue.get_customer_count() == 1
		and ProductCatalogScript.orders_match(customer.order, existing_order)
		and ProductCatalogScript.orders_match(queue.get_active_order(), existing_order)
		and not CustomerTrafficConfigScript.can_spawn_customers(1230.0)
		and not queue.can_spawn_new_in_person_customer()
	)

	customer.queue_free()
	queue.queue_free()
	return still_valid


func _test_queue_refresh_preserves_waiting_pickup() -> bool:
	var customer: Customer = CustomerScript.new()
	customer.state = Customer.State.WAITING_PICKUP

	var queue = CustomerQueueScript.new()
	root.add_child(queue)
	queue._customers.append(customer)
	queue._delivery_customer = customer

	queue._advance_queue()

	var ok := (
		customer.state == Customer.State.WAITING_PICKUP
		and queue.can_fulfill_order(customer)
	)

	customer.queue_free()
	queue.queue_free()
	return ok


func _test_sync_restores_waiting_pickup() -> bool:
	var customer: Customer = CustomerScript.new()
	customer.state = Customer.State.PENDING

	var queue = CustomerQueueScript.new()
	queue._delivery_customer = customer
	queue.sync_delivery_before_fulfill(customer)

	var ok := (
		customer.state == Customer.State.WAITING_PICKUP
		and queue.can_fulfill_order(customer)
	)

	customer.queue_free()
	return ok
