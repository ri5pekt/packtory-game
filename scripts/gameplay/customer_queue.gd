class_name CustomerQueue
extends Node3D

## Spawns shoppers, lines them up, and tracks the order currently being picked,
## packed, and delivered.

signal active_order_changed(order: Dictionary)
signal order_fulfilled(meta: Dictionary)

const CustomerScript = preload("res://scripts/gameplay/customer.gd")
const CustomerPedestrianScript = preload("res://scripts/warehouse/customer_pedestrian.gd")
const CustomerAngerReputationConfigScript = preload(
	"res://scripts/gameplay/customer_anger_reputation_config.gd"
)
const CustomerStatusScript = preload("res://scripts/gameplay/customer_status.gd")
const OnlineOrderCatalogScript = preload("res://scripts/gameplay/online_order_catalog.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")
const CustomerTrafficConfigScript = preload("res://scripts/gameplay/customer_traffic_config.gd")
const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")
const CharacterCatalogScript = preload("res://scripts/dev/character_catalog.gd")

const SOURCE_NONE := ""
const SOURCE_IN_PERSON := "in_person"
const SOURCE_ONLINE := "online"

const MAX_QUEUE := QueueAreaLayout.MAX_QUEUE
const MIN_SPAWN_SEC := 10.0
const MAX_SPAWN_SEC := 22.0
const FIRST_SPAWN_SEC := 8.0

var _next_spawn_at_minutes := -1.0
var _use_game_time_spawn := false

var _grid: WarehouseGrid
var _rng := RandomNumberGenerator.new()
var _customers: Array[Customer] = []
var _approaching_pedestrians: Array = []
var _active_order: Dictionary = {}
var _order_source := SOURCE_NONE
var _online_order_number := 0
var _fulfilled_online_orders: Array[int] = []
var _active_customer: Customer
var _delivery_customer: Customer
var _spawn_timer: Timer
var _entry: Array[Vector3] = []
var _service_started := false
var _anger_penalty_accumulator := 0.0
var _last_anger_penalty_total_minutes := -1.0


func _ready() -> void:
	add_to_group("customer_queue")
	_grid = get_node("/root/GridService") as WarehouseGrid
	_rng.randomize()
	call_deferred("_build_positions")

	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(_spawn_timer)
	call_deferred("_connect_day_start")
	call_deferred("_bind_patience_refresh")
	call_deferred("_register_fulfillment_listeners")


func _register_fulfillment_listeners() -> void:
	for autoload_name in ["EconomyManager", "ProgressionManager", "DayStatsTracker"]:
		var listener := get_node_or_null("/root/%s" % autoload_name)
		if listener != null and listener.has_method("register_customer_queue"):
			listener.register_customer_queue(self)


func begin_service() -> void:
	_begin_spawning()


func is_spawning_enabled() -> bool:
	return _service_started


func can_spawn_new_in_person_customer() -> bool:
	return _can_spawn_new_customer()


func get_traffic_period() -> String:
	var game_time := _get_game_time()
	var minutes: float = float(game_time.get_precise_minutes()) if game_time else float(GameTimeConfigScript.DAY_START_MINUTES)
	return CustomerTrafficConfigScript.traffic_period_at(minutes)


func get_spawn_delay_range_for_minutes(minutes: float) -> Vector2:
	return CustomerTrafficConfigScript.spawn_delay_range(minutes)


func get_customer_count() -> int:
	return _customers.size()


func _connect_day_start() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		push_warning("CustomerQueue: GameSession missing; starting customers immediately.")
		_begin_spawning()
		return
	if session.is_gameplay_active():
		_begin_spawning()
		return
	session.day_started.connect(_begin_spawning, CONNECT_ONE_SHOT)


func _begin_spawning() -> void:
	if _service_started:
		return
	_service_started = true
	var game_time := _get_game_time()
	if game_time:
		_use_game_time_spawn = true
		if not game_time.minute_advanced.is_connected(_on_game_minute_advanced):
			game_time.minute_advanced.connect(_on_game_minute_advanced)
		if not game_time.time_changed.is_connected(_on_game_time_changed):
			game_time.time_changed.connect(_on_game_time_changed)
		_schedule_next_game_spawn(
			game_time.get_precise_minutes() + CustomerTrafficConfigScript.FIRST_SPAWN_DELAY_MINUTES
		)
	else:
		_spawn_timer.start(FIRST_SPAWN_SEC)


func refresh_queue_layout() -> void:
	_ensure_reception_bound()
	_build_positions()
	_advance_queue()


func get_active_order() -> Dictionary:
	return _active_order.duplicate()


func get_order_source() -> String:
	return _order_source


func get_online_order_number() -> int:
	return _online_order_number


func get_fulfilled_online_orders() -> Array[int]:
	return _fulfilled_online_orders.duplicate()


func is_online_order_fulfilled(order_number: int) -> bool:
	return _fulfilled_online_orders.has(order_number)


func get_active_order_meta() -> Dictionary:
	return {
		"source": _order_source,
		"online_order_number": _online_order_number,
		"label": _active_order_label(),
	}


func _active_order_label() -> String:
	if _order_source == SOURCE_ONLINE and _online_order_number > 0:
		return "Online Order #%d" % _online_order_number
	if _order_source == SOURCE_IN_PERSON:
		return "In-Person Order"
	return "Active Order"


func can_activate_online_order() -> String:
	if not _active_order.is_empty():
		return "Finish or cancel the current active order first."
	if _delivery_customer != null:
		return "Deliver the packed in-person order before taking an online order."
	return ""


func activate_online_order(online_order: Dictionary) -> bool:
	if can_activate_online_order() != "":
		return false
	var fulfillment := OnlineOrderCatalogScript.to_fulfillment_order(online_order)
	if fulfillment.is_empty():
		return false
	_active_order = fulfillment
	_order_source = SOURCE_ONLINE
	_online_order_number = int(online_order.get("order_number", 0))
	_active_customer = null
	_update_status_indicators()
	active_order_changed.emit(get_active_order())
	return true


func get_active_customer() -> Customer:
	return _active_customer


func get_delivery_customer() -> Customer:
	return _delivery_customer


func has_pending_delivery() -> bool:
	return _delivery_customer != null


func can_take_order(customer: Customer) -> bool:
	return (
		_active_order.is_empty()
		and _delivery_customer == null
		and not _customers.is_empty()
		and _customers[0] == customer
		and customer.has_pending_order()
	)


func can_fulfill_order(customer: Customer) -> bool:
	return _delivery_customer == customer and customer.is_waiting_pickup()


## Repair delivery state when queue layout refresh bumped a waiting customer back to PENDING,
## or when packing finished but mark_order_packed did not run yet.
func sync_delivery_before_fulfill(customer: Customer) -> void:
	if customer == null:
		return
	if _delivery_customer == customer and customer.state == Customer.State.PENDING:
		customer.set_waiting_pickup()
		return
	if _active_customer == customer and customer.state == Customer.State.TAKEN:
		mark_order_packed()


func get_fulfill_block_reason(customer: Customer, actor: Worker) -> String:
	sync_delivery_before_fulfill(customer)
	if actor == null or not actor.has_package():
		return "Carry the packed order before delivering."
	if customer == null or not is_instance_valid(customer):
		return "That customer isn't available."
	if customer.is_departing():
		return "That customer is already leaving."
	if _delivery_customer == null:
		if _active_customer == customer and customer.state == Customer.State.TAKEN:
			return "Finish packing the order first."
		return "Pack the order before delivering to this customer."
	if _delivery_customer != customer:
		return "Deliver the packed order to the waiting customer first."
	if not customer.is_waiting_pickup():
		return "This customer isn't ready to receive the order yet."
	return ""


func take_order(customer: Customer) -> bool:
	if not can_take_order(customer):
		return false
	_active_order = customer.order.duplicate()
	_order_source = SOURCE_IN_PERSON
	_online_order_number = 0
	_active_customer = customer
	customer.set_order_taken()
	_update_status_indicators()
	active_order_changed.emit(get_active_order())
	return true


func cancel_order() -> void:
	if _active_order.is_empty():
		return
	if _order_source == SOURCE_IN_PERSON and _active_customer != null:
		_active_customer.set_pending()
	_active_customer = null
	_active_order = {}
	_order_source = SOURCE_NONE
	_online_order_number = 0
	_update_status_indicators()
	active_order_changed.emit({})


## Called when packing finishes — package is ready but customer still waits.
func mark_order_packed() -> bool:
	if _delivery_customer != null:
		return true
	if _order_source == SOURCE_ONLINE:
		if _active_order.is_empty():
			return false
		_active_order = {}
		_order_source = SOURCE_NONE
		_online_order_number = 0
		active_order_changed.emit({})
		_update_status_indicators()
		return true
	if _active_customer == null:
		return false
	if _active_customer.state != Customer.State.TAKEN:
		return false
	_delivery_customer = _active_customer
	_delivery_customer.set_waiting_pickup()
	_active_customer = null
	_active_order = {}
	_order_source = SOURCE_NONE
	active_order_changed.emit({})
	_update_status_indicators()
	return true


## Hand off the package, walk the customer out, and step the queue forward.
func deliver_to_customer(customer: Customer, actor: Worker) -> bool:
	sync_delivery_before_fulfill(customer)
	if actor == null or not actor.has_package():
		return false
	if not can_fulfill_order(customer):
		return false
	if not actor.remove_product("package"):
		return false

	_emit_order_fulfilled({
		"source": SOURCE_IN_PERSON,
		"order": customer.order.duplicate(),
	})

	_delivery_customer = null
	var idx := _customers.find(customer)
	if idx >= 0:
		_customers.remove_at(idx)
	customer.departed.connect(_on_customer_departed, CONNECT_ONE_SHOT)
	customer.begin_depart(_exit_waypoints(customer.position))
	_advance_queue()
	_update_status_indicators()
	return true


func notify_online_package_shipped(package_meta: Dictionary) -> void:
	var order_number := int(package_meta.get("online_order_number", 0))
	if order_number > 0 and not _fulfilled_online_orders.has(order_number):
		_fulfilled_online_orders.append(order_number)
	_emit_order_fulfilled({
		"source": SOURCE_ONLINE,
		"order": {},
		"online_order_number": order_number,
	})


func _emit_order_fulfilled(meta: Dictionary) -> void:
	# Re-register before emit — autoloads can miss the queue when gameplay loads after the menu.
	_register_fulfillment_listeners()
	order_fulfilled.emit(meta.duplicate())


func _on_customer_departed(_customer: Customer) -> void:
	pass


func _advance_queue() -> void:
	for i in range(_customers.size()):
		var customer := _customers[i]
		# Mid-order shoppers must stay put — repositioning resets WAITING_PICKUP to PENDING
		# and breaks fulfillment after layout refresh or furniture moves.
		if customer.state in [Customer.State.TAKEN, Customer.State.WAITING_PICKUP]:
			continue
		var slot := _queue_slot(i)
		customer.assigned_slot = slot
		if customer.is_at_queue_slot(slot):
			continue
		if customer.state == Customer.State.ARRIVING:
			customer.redirect_to_slot(slot)
		else:
			customer.walk_to_slot(slot)


func _exit_waypoints(from_position: Vector3) -> Array[Vector3]:
	var wx := _grid.get_walkway_x()
	var exit_x := QueueAreaLayout.get_exit_lane_x()
	var entry := QueueAreaLayout.get_entry_point()
	var walkway := _grid.get_walkway_z_bounds()
	return [
		_grid.world_on_surface(exit_x, from_position.z),
		_grid.world_on_surface(exit_x, entry.z + 0.5),
		_grid.world_on_surface(wx, walkway.x),
		_grid.world_on_surface(wx, walkway.y),
	]


func _build_positions() -> void:
	_ensure_reception_bound()
	var wx := _grid.get_walkway_x()
	var walkway := _grid.get_walkway_z_bounds()
	_entry = [
		_grid.world_on_surface(wx, walkway.y),
		_grid.world_on_surface(wx, walkway.x),
		QueueAreaLayout.get_entry_point(),
	]


func _ensure_reception_bound() -> void:
	if QueueAreaLayout.get_reception() != null:
		return
	for node in get_tree().get_nodes_in_group("reception_tables"):
		if node.has_method("get_slot"):
			QueueAreaLayout.bind(node)
			return
	push_warning("CustomerQueue: no ReceptionTable found; using legacy queue layout.")


func _queue_slot(index: int) -> Vector3:
	return QueueAreaLayout.get_slot(index)


func _get_game_time() -> Node:
	return get_node_or_null("/root/GameTimeManager")


func _current_game_day() -> int:
	var game_time := _get_game_time()
	if game_time != null and game_time.has_method("get_day"):
		return maxi(1, int(game_time.get_day()))
	var save := get_node_or_null("/root/SaveManager")
	if save != null and save.has_method("get_day"):
		return maxi(1, int(save.get_day()))
	return 1


func _schedule_next_game_spawn(at_minutes: float) -> void:
	_next_spawn_at_minutes = at_minutes


func _on_game_time_changed(_minutes: int, _day: int) -> void:
	if not _use_game_time_spawn:
		return
	_try_spawn_on_game_clock()


func _on_game_minute_advanced(_minutes: int, _day: int) -> void:
	if not _use_game_time_spawn:
		return
	_try_spawn_on_game_clock()


func _try_spawn_on_game_clock() -> void:
	var game_time := _get_game_time()
	if game_time == null or _next_spawn_at_minutes < 0.0:
		return
	var minutes: float = float(game_time.get_precise_minutes())
	if minutes < _next_spawn_at_minutes:
		return
	if not CustomerTrafficConfigScript.can_spawn_customers(minutes):
		_next_spawn_at_minutes = -1.0
		return
	if _customers.size() + _approaching_pedestrians.size() < MAX_QUEUE:
		_spawn_customer()
	_schedule_next_spawn_from_time(minutes)


func _schedule_next_spawn_from_time(minutes: float) -> void:
	if not CustomerTrafficConfigScript.can_spawn_customers(minutes):
		_next_spawn_at_minutes = -1.0
		return
	var delay: float = CustomerTrafficConfigScript.random_spawn_delay_minutes(minutes, _rng)
	if delay < 0.0:
		_next_spawn_at_minutes = -1.0
		return
	_schedule_next_game_spawn(minutes + delay)


func _can_spawn_new_customer() -> bool:
	if not _use_game_time_spawn:
		return true
	var game_time := _get_game_time()
	if game_time == null:
		return true
	return CustomerTrafficConfigScript.can_spawn_customers(game_time.get_precise_minutes())


func _get_orderable_product_pool() -> Array:
	var unlocks := get_node_or_null("/root/UnlockManager")
	if unlocks and unlocks.has_method("get_orderable_product_ids"):
		return unlocks.get_orderable_product_ids()
	var save := get_node_or_null("/root/SaveManager")
	if save and save.has_method("get_unlocked_products"):
		return save.get_unlocked_products()
	return ProductCatalog.orderable_product_ids()


func _on_spawn_timer() -> void:
	if _customers.size() + _approaching_pedestrians.size() < MAX_QUEUE:
		_spawn_customer()
	_spawn_timer.start(_rng.randf_range(MIN_SPAWN_SEC, MAX_SPAWN_SEC))


func _spawn_customer() -> void:
	if not _can_spawn_new_customer():
		return
	if _customers.size() + _approaching_pedestrians.size() >= MAX_QUEUE:
		return
	_spawn_customer_pedestrian()


func _spawn_customer_pedestrian() -> void:
	_ensure_reception_bound()

	var model_name: String = CharacterCatalogScript.pick_random_npc_model(_rng, get_tree())
	var model_path: String = CharacterCatalogScript.model_path(model_name)
	var character_scene: PackedScene = load(model_path)
	if character_scene == null:
		push_warning("CustomerQueue: failed to load shopper model %s" % model_name)
		return

	var order := ProductCatalog.random_order(_rng, _get_orderable_product_pool(), _current_game_day())
	var pedestrian = CustomerPedestrianScript.new()
	pedestrian.name = "ShopperApproach_%d" % _approaching_pedestrians.size()
	pedestrian.model_path = model_path
	pedestrian.ready_for_warehouse_entry.connect(_on_customer_pedestrian_ready)
	add_child(pedestrian)
	pedestrian.setup(
		character_scene,
		order,
		_build_customer_approach_waypoints(),
		_rng.randf_range(1.2, 2.0)
	)
	_approaching_pedestrians.append(pedestrian)


func _build_customer_approach_waypoints() -> Array[Vector3]:
	var wx := _grid.get_walkway_x()
	var walkway := _grid.get_walkway_z_bounds()
	var entry := QueueAreaLayout.get_entry_point()
	# Match decorative sidewalk traffic: approach along the north road sidewalk
	# (row 24) from east or west, then turn into the entrance walkway.
	var north_sidewalk_z := _grid.get_decorative_sidewalk_z(0)
	var x_bounds := _grid.get_decorative_road_x_bounds()
	var from_east := _rng.randf() > 0.5
	var start_x := x_bounds.y if from_east else x_bounds.x
	return [
		_grid.world_on_surface(start_x, north_sidewalk_z),
		_grid.world_on_surface(wx, north_sidewalk_z),
		_grid.world_on_surface(wx, walkway.x),
		entry,
	]


func _on_customer_pedestrian_ready(pedestrian: Node) -> void:
	if pedestrian == null or not is_instance_valid(pedestrian):
		return
	_approaching_pedestrians.erase(pedestrian)
	if _customers.size() >= MAX_QUEUE:
		pedestrian.queue_free()
		return
	_admit_customer_pedestrian(pedestrian)


func _admit_customer_pedestrian(pedestrian: Node) -> void:
	var slot_index := _customers.size()
	var slot := _queue_slot(slot_index)
	var start_pos: Vector3 = pedestrian.global_position
	var interior_waypoints: Array[Vector3] = [start_pos, slot]

	var customer: Customer = CustomerScript.new()
	customer.name = "Customer_%d" % slot_index
	add_child(customer)
	customer.arrived_at_slot.connect(_on_customer_arrived)
	customer.setup(
		pedestrian.model_path,
		interior_waypoints,
		pedestrian.get_order(),
		slot,
		true
	)
	_customers.append(customer)
	pedestrian.queue_free()
	_update_status_indicators()


func get_approaching_pedestrian_count() -> int:
	return _approaching_pedestrians.size()


func _on_customer_arrived(_customer: Customer) -> void:
	_update_status_indicators()


func _update_status_indicators() -> void:
	for i in range(_customers.size()):
		var customer := _customers[i]
		if customer == _active_customer and customer.state == Customer.State.TAKEN:
			customer.set_queue_order(customer.order)
			continue
		customer.set_queue_status(_resolve_customer_status(customer, i))


func advance_anger_reputation_penalty(game_minutes_delta: float) -> int:
	if game_minutes_delta <= 0.0:
		return 0
	return _accumulate_and_apply_anger_penalty(game_minutes_delta)


func count_angry_customers() -> int:
	return _count_angry_customers()


func resolve_customer_status_for_test(customer: Customer, index: int) -> int:
	return _resolve_customer_status(customer, index)


func _resolve_customer_status(customer: Customer, index: int) -> int:
	if not customer.has_entered_warehouse():
		return CustomerStatusScript.Kind.NONE
	if customer.is_departing():
		return CustomerStatusScript.Kind.NONE
	if customer == _delivery_customer and customer.is_waiting_pickup():
		return CustomerStatusScript.Kind.READY_TO_LEAVE
	if customer == _active_customer and customer.state == Customer.State.TAKEN:
		return CustomerStatusScript.Kind.WAITING
	if customer.state in [Customer.State.ARRIVING, Customer.State.REPOSITIONING]:
		return CustomerStatusScript.Kind.WAITING
	if customer.state == Customer.State.PENDING:
		if index == 0 and can_take_order(customer):
			return CustomerStatusScript.Kind.ORDER
		return CustomerStatusScript.Kind.WAITING
	return CustomerStatusScript.Kind.NONE


func _bind_patience_refresh() -> void:
	var game_time := _get_game_time()
	if game_time == null:
		return
	if not game_time.time_changed.is_connected(_on_patience_time_changed):
		game_time.time_changed.connect(_on_patience_time_changed)
	_reset_anger_reputation_penalty_clock()


func _on_patience_time_changed(_minutes: int, day: int) -> void:
	_advance_anger_reputation_from_clock(day)
	if not _customers.is_empty():
		_update_status_indicators()


func _advance_anger_reputation_from_clock(day: int) -> void:
	var game_time := _get_game_time()
	if game_time == null or not game_time.is_running():
		return
	var total := _total_game_minutes(day, game_time.get_precise_minutes())
	if _last_anger_penalty_total_minutes < 0.0:
		_last_anger_penalty_total_minutes = total
		return
	var delta := total - _last_anger_penalty_total_minutes
	_last_anger_penalty_total_minutes = total
	advance_anger_reputation_penalty(delta)


func _accumulate_and_apply_anger_penalty(game_minutes_delta: float) -> int:
	_anger_penalty_accumulator += game_minutes_delta
	var total_loss := 0
	while (
		_anger_penalty_accumulator
		>= CustomerAngerReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES
	):
		_anger_penalty_accumulator -= (
			CustomerAngerReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES
		)
		total_loss += _apply_anger_penalty_tick()
	return total_loss


func _apply_anger_penalty_tick() -> int:
	var angry_count := _count_angry_customers()
	if angry_count <= 0:
		return 0
	var amount := (
		angry_count
		* CustomerAngerReputationConfigScript.REPUTATION_LOSS_PER_ANGRY_CUSTOMER_PER_TICK
	)
	var reputation := _get_reputation()
	if reputation == null:
		return 0
	var changed: int = reputation.reduce_reputation(amount)
	return maxi(0, -changed)


func _count_angry_customers() -> int:
	var count := 0
	for customer in _customers:
		if customer == null or not is_instance_valid(customer):
			continue
		if customer.is_departing():
			continue
		if customer == _active_customer and customer.state == Customer.State.TAKEN:
			continue
		if customer == _delivery_customer and customer.is_waiting_pickup():
			continue
		if not customer.is_tracking_queue_wait():
			continue
		if customer.get_patience_queue_status() == CustomerStatusScript.Kind.ANGRY:
			count += 1
	return count


func _reset_anger_reputation_penalty_state() -> void:
	_anger_penalty_accumulator = 0.0
	_reset_anger_reputation_penalty_clock()


func _reset_anger_reputation_penalty_clock() -> void:
	var game_time := _get_game_time()
	if game_time == null:
		_last_anger_penalty_total_minutes = -1.0
		return
	_last_anger_penalty_total_minutes = _total_game_minutes(
		game_time.get_day(),
		game_time.get_precise_minutes()
	)


func _total_game_minutes(day: int, minutes: float) -> float:
	return float((maxi(1, day) - 1) * GameTimeConfigScript.MINUTES_PER_DAY) + minutes


func _get_reputation() -> Node:
	return get_node_or_null("/root/ReputationManager")


func export_save_state() -> Dictionary:
	var customers: Array = []
	for i in range(_customers.size()):
		var customer := _customers[i]
		var entry: Dictionary = customer.export_save_state() if customer.has_method("export_save_state") else {}
		entry["slot_index"] = i
		customers.append(entry)
	return {
		"service_started": _service_started,
		"active_order": _active_order.duplicate(),
		"order_source": _order_source,
		"online_order_number": _online_order_number,
		"active_customer_slot": _customer_slot_index(_active_customer),
		"delivery_customer_slot": _customer_slot_index(_delivery_customer),
		"next_spawn_at_minutes": _next_spawn_at_minutes,
		"use_game_time_spawn": _use_game_time_spawn,
		"fulfilled_online_orders": _fulfilled_online_orders.duplicate(),
		"customers": customers,
	}


func apply_save_state(data: Dictionary) -> void:
	for customer in _customers.duplicate():
		if is_instance_valid(customer):
			customer.queue_free()
	_customers.clear()
	for pedestrian in _approaching_pedestrians.duplicate():
		if is_instance_valid(pedestrian):
			pedestrian.queue_free()
	_approaching_pedestrians.clear()
	_active_order = data.get("active_order", {}).duplicate()
	_order_source = String(data.get("order_source", SOURCE_NONE))
	_online_order_number = int(data.get("online_order_number", 0))
	_fulfilled_online_orders.clear()
	for num in data.get("fulfilled_online_orders", []):
		var order_number := int(num)
		if order_number > 0 and not _fulfilled_online_orders.has(order_number):
			_fulfilled_online_orders.append(order_number)
	_active_customer = null
	_delivery_customer = null
	_service_started = bool(data.get("service_started", false))
	_use_game_time_spawn = bool(data.get("use_game_time_spawn", false))
	_next_spawn_at_minutes = float(data.get("next_spawn_at_minutes", -1.0))
	_ensure_reception_bound()
	for entry in data.get("customers", []):
		if not entry is Dictionary:
			continue
		var customer := _restore_customer_from_save(entry)
		if customer != null:
			_customers.append(customer)
	var active_slot := int(data.get("active_customer_slot", -1))
	var delivery_slot := int(data.get("delivery_customer_slot", -1))
	if active_slot >= 0 and active_slot < _customers.size():
		_active_customer = _customers[active_slot]
	if delivery_slot >= 0 and delivery_slot < _customers.size():
		_delivery_customer = _customers[delivery_slot]
	if _service_started:
		_resume_spawning_after_load()
	active_order_changed.emit(get_active_order())
	_update_status_indicators()


func _customer_slot_index(customer: Customer) -> int:
	if customer == null:
		return -1
	return _customers.find(customer)


func _restore_customer_from_save(entry: Dictionary) -> Customer:
	var slot_index := int(entry.get("slot_index", _customers.size()))
	var slot := _queue_slot(slot_index)
	var customer: Customer = CustomerScript.new()
	customer.name = "Customer_%d" % slot_index
	add_child(customer)
	customer.arrived_at_slot.connect(_on_customer_arrived)
	if customer.has_method("apply_save_state"):
		customer.apply_save_state(entry, slot)
	return customer


func _resume_spawning_after_load() -> void:
	if _spawn_timer == null:
		return
	_spawn_timer.stop()
	var game_time := _get_game_time()
	if _use_game_time_spawn and game_time:
		if not game_time.minute_advanced.is_connected(_on_game_minute_advanced):
			game_time.minute_advanced.connect(_on_game_minute_advanced)
		if not game_time.time_changed.is_connected(_on_game_time_changed):
			game_time.time_changed.connect(_on_game_time_changed)
		if _next_spawn_at_minutes < 0.0:
			_schedule_next_game_spawn(
				game_time.get_precise_minutes() + CustomerTrafficConfigScript.FIRST_SPAWN_DELAY_MINUTES
			)
		return
	_spawn_timer.start(FIRST_SPAWN_SEC)
