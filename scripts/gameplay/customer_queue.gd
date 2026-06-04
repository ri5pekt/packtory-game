class_name CustomerQueue
extends Node3D

## Spawns shoppers, lines them up, and tracks the order currently being picked,
## packed, and delivered.

signal active_order_changed(order: Dictionary)

const CustomerScript = preload("res://scripts/gameplay/customer.gd")
const CHARACTER_BASE := (
	"res://blender/assets/kenney_mini-characters/Models/GLB format/"
)
const CHARACTER_MODELS := [
	"character-female-a.glb", "character-female-b.glb", "character-female-c.glb",
	"character-female-d.glb", "character-female-e.glb", "character-female-f.glb",
	"character-male-a.glb", "character-male-b.glb", "character-male-c.glb",
	"character-male-d.glb", "character-male-e.glb", "character-male-f.glb",
]

const MAX_QUEUE := QueueAreaLayout.MAX_QUEUE
const MIN_SPAWN_SEC := 6.0
const MAX_SPAWN_SEC := 14.0
const FIRST_SPAWN_SEC := 3.0

var _grid: WarehouseGrid
var _rng := RandomNumberGenerator.new()
var _customers: Array[Customer] = []
var _active_order: Dictionary = {}
var _active_customer: Customer
var _delivery_customer: Customer
var _spawn_timer: Timer
var _slots: Array[Vector3] = []
var _entry: Array[Vector3] = []
var _service_started := false


func _ready() -> void:
	add_to_group("customer_queue")
	_grid = get_node("/root/GridService") as WarehouseGrid
	_rng.randomize()
	_build_positions()

	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(_spawn_timer)
	# Always start spawning after FIRST_SPAWN_SEC regardless of delivery state.
	# The delivery phase runs in parallel; customers arrive even if shelves are empty.
	_service_started = true
	_spawn_timer.start(FIRST_SPAWN_SEC)


func begin_service() -> void:
	# No-op: spawning starts unconditionally in _ready now.
	pass


func get_active_order() -> Dictionary:
	return _active_order.duplicate()


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
	return (
		_delivery_customer == customer
		and customer.is_waiting_pickup()
		and not _customers.is_empty()
		and _customers[0] == customer
	)


func take_order(customer: Customer) -> bool:
	if not can_take_order(customer):
		return false
	_active_order = customer.order.duplicate()
	_active_customer = customer
	customer.set_order_taken()
	_update_bubbles()
	active_order_changed.emit(get_active_order())
	return true


func cancel_order() -> void:
	if _active_customer == null:
		return
	_active_customer.set_pending()
	_active_customer = null
	_active_order = {}
	_update_bubbles()
	active_order_changed.emit({})


## Called when packing finishes — package is ready but customer still waits.
func mark_order_packed() -> bool:
	if _active_order.is_empty() or _active_customer == null:
		return false
	_delivery_customer = _active_customer
	_delivery_customer.set_waiting_pickup()
	_active_customer = null
	_active_order = {}
	active_order_changed.emit({})
	_update_bubbles()
	return true


## Hand off the package, walk the customer out, and step the queue forward.
func deliver_to_customer(customer: Customer, actor: Worker) -> bool:
	if actor == null or not actor.has_package():
		return false
	if not can_fulfill_order(customer):
		return false
	if not actor.remove_product("package"):
		return false

	_delivery_customer = null
	var idx := _customers.find(customer)
	if idx >= 0:
		_customers.remove_at(idx)
	customer.departed.connect(_on_customer_departed, CONNECT_ONE_SHOT)
	customer.begin_depart(_exit_waypoints(customer.position))
	_advance_queue()
	_update_bubbles()
	return true


func _on_customer_departed(_customer: Customer) -> void:
	pass


func _advance_queue() -> void:
	for i in range(_customers.size()):
		var customer := _customers[i]
		var slot := _slots[i]
		if customer.state == Customer.State.ARRIVING:
			customer.redirect_to_slot(slot)
		else:
			customer.walk_to_slot(slot)


func _exit_waypoints(from_position: Vector3) -> Array[Vector3]:
	var wx := _grid.get_walkway_x()
	# Step sideways into the east lane, walk south past the queue, then out the door.
	return [
		Vector3(QueueAreaLayout.EXIT_LANE_X, 0.0, from_position.z),
		Vector3(QueueAreaLayout.EXIT_LANE_X, 0.0, QueueAreaLayout.ENTRY_Z + 0.5),
		Vector3(wx, 0.0, 23.2),
		Vector3(wx, 0.0, 27.0),
	]


func _build_positions() -> void:
	for i in range(MAX_QUEUE):
		_slots.append(QueueAreaLayout.get_slot(i))

	var wx := _grid.get_walkway_x()
	_entry = [
		Vector3(wx, 0.0, 27.0),
		Vector3(wx, 0.0, 23.2),
		QueueAreaLayout.get_entry_point(),
	]


func _on_spawn_timer() -> void:
	if _customers.size() < MAX_QUEUE:
		_spawn_customer()
	_spawn_timer.start(_rng.randf_range(MIN_SPAWN_SEC, MAX_SPAWN_SEC))


func _spawn_customer() -> void:
	var slot_index := _customers.size()
	var slot := _slots[slot_index]
	var waypoints: Array[Vector3] = _entry.duplicate()
	waypoints.append(slot)

	var model_path: String = CHARACTER_BASE + CHARACTER_MODELS[_rng.randi_range(0, CHARACTER_MODELS.size() - 1)]
	var order := ProductCatalog.random_order(_rng)

	var customer: Customer = CustomerScript.new()
	customer.name = "Customer_%d" % slot_index
	add_child(customer)
	customer.arrived_at_slot.connect(_on_customer_arrived)
	customer.setup(model_path, waypoints, order, slot)
	_customers.append(customer)


func _on_customer_arrived(_customer: Customer) -> void:
	_update_bubbles()


func _update_bubbles() -> void:
	for i in range(_customers.size()):
		var customer := _customers[i]
		var should_show := (
			i == 0
			and _active_order.is_empty()
			and _delivery_customer == null
			and customer.has_pending_order()
		)
		if should_show:
			customer.show_bubble()
		else:
			customer.hide_bubble()
