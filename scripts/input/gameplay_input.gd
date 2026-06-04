extends Node

## Pointer interaction: select the worker, send it to a floor cell, or interact
## with a shelf (take a product / put one back). Shelf actions walk the worker to
## the shelf and run on arrival.

const CHARACTER_COLLISION_MASK := 1

var _grid: WarehouseGrid
var _camera: Camera3D
var _selected_worker: Worker
var _pending_target: Vector3 = Vector3.ZERO
var _target_shelf: ProductShelf
var _target_shelf_product: String = ""   # product id chosen for stocking
var _target_customer: Customer
var _target_packing_table: PackingTable
var _target_box: DeliveryBox
var _suppress_tap_until_frame: int = -1

@onready var _touch_input: Node = $"../TouchInput"
@onready var _camera_rig: Node3D = $"../IsoCameraRig"
@onready var _context_menu: PanelContainer = $"../UI/ContextMenu"


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_touch_input.tap.connect(_on_tap)
	_context_menu.action_selected.connect(_on_action_selected)
	_context_menu.hide_menu()
	_bind_camera()
	call_deferred("_auto_select_manager")


func _bind_camera() -> void:
	_camera = _camera_rig.get_camera()


func get_selected_worker() -> Worker:
	return _selected_worker


func _on_tap(screen_position: Vector2) -> void:
	if _camera == null:
		_bind_camera()
	if _camera == null:
		return
	if Engine.get_process_frames() <= _suppress_tap_until_frame:
		return
	if _context_menu.visible and _context_menu.get_global_rect().has_point(screen_position):
		return

	var floor_target := _pick_warehouse_floor(screen_position)
	var hit := _raycast_interactable(screen_position)

	# Already-selected worker: prefer floor navigation over re-selecting the same worker.
	if hit is Worker and _selected_worker == hit and floor_target != Vector3.INF:
		hit = null

	if hit is Worker:
		_select_worker(hit)
		_context_menu.hide_menu()
		return
	if hit is ProductShelf:
		_open_shelf_menu(hit, screen_position)
		return
	if hit is Customer:
		_open_customer_menu(hit, screen_position)
		return
	if hit is PackingTable:
		_open_packing_menu(hit, screen_position)
		return
	if hit is DeliveryBox:
		_open_box_menu(hit, screen_position)
		return

	if _selected_worker == null:
		_auto_select_manager()

	if _selected_worker and _selected_worker.is_packing():
		return

	if _selected_worker and floor_target != Vector3.INF:
		_pending_target = floor_target
		_target_shelf = null
		_context_menu.show_actions(screen_position, [{"id": "go_here", "label": "Go Here"}])
		return

	_deselect_worker()
	_context_menu.hide_menu()


func _open_shelf_menu(shelf: ProductShelf, screen_position: Vector2) -> void:
	_target_shelf = shelf
	var actor := _get_actor()
	if actor == null:
		return
	_select_worker(actor)

	var actions: Array = _shelf_actions(shelf, actor)
	if actions.is_empty():
		_context_menu.hide_menu()
		return
	_context_menu.show_actions(screen_position, actions)


func _open_customer_menu(customer: Customer, screen_position: Vector2) -> void:
	_target_customer = customer
	var queue := _get_queue()
	var actor := _get_actor()
	if queue == null or actor == null:
		_context_menu.hide_menu()
		return

	var actions: Array = []
	if queue.can_take_order(customer) and not actor.has_package():
		actions.append({"id": "take_order", "label": "Take order"})
	if _can_fulfill_order(actor, customer, queue):
		actions.append({"id": "fulfill_order", "label": "Fulfill order"})

	if actions.is_empty():
		_context_menu.hide_menu()
		return

	_select_worker(actor)
	_context_menu.show_actions(screen_position, actions)


func _can_fulfill_order(actor: Worker, customer: Customer, queue: CustomerQueue) -> bool:
	if actor.is_packing() or actor.is_moving():
		return false
	return queue.can_fulfill_order(customer) and actor.has_package()


func _open_packing_menu(table: PackingTable, screen_position: Vector2) -> void:
	_target_packing_table = table
	var actor := _get_actor()
	if actor == null:
		return
	_select_worker(actor)
	if not _can_pack_order(actor):
		_context_menu.hide_menu()
		return
	_context_menu.show_actions(screen_position, [{"id": "pack_order", "label": "Pack the order"}])


func _can_pack_order(actor: Worker) -> bool:
	var queue := _get_queue()
	if queue == null:
		return false
	if queue.has_pending_delivery():
		return false
	if actor.has_package():
		return false
	var order := queue.get_active_order()
	if order.is_empty():
		return false
	if actor.is_packing() or actor.is_moving():
		return false
	return ProductCatalog.inventory_fulfills_order(actor.get_inventory(), order)


func _shelf_actions(shelf: ProductShelf, actor: Worker) -> Array:
	var actions: Array = []
	if actor.is_packing() or actor.has_package():
		return actions

	# Take: only when shelf has a product assigned.
	if shelf.can_take() and not actor.is_inventory_full():
		var free_units := Worker.MAX_INVENTORY - actor.get_total_units()
		var max_qty := mini(shelf.count, free_units)
		if max_qty > 0:
			actions.append({
				"id": "take",
				"label": "Take %s" % ProductCatalog.display_name(shelf.product_id),
				"quantity": {"min": 1, "max": max_qty, "default": 1},
			})

	# Stock: shelf accepts any product the worker carries if unassigned,
	# or only its own product if already assigned.
	for product_id in _stockable_ids_for_shelf(shelf, actor):
		var held := actor.count_product(product_id)
		var max_put := mini(held, shelf.free_space())
		if max_put > 0:
			var pid := product_id  # capture for stable reference
			actions.append({
				"id": "put_%s" % pid,
				"label": "Stock: %s" % ProductCatalog.display_name(pid),
				"quantity": {"min": 1, "max": max_put, "default": max_put},
			})
	return actions


## Returns which product ids from the actor's inventory can go on this shelf.
func _stockable_ids_for_shelf(shelf: ProductShelf, actor: Worker) -> Array[String]:
	var ids: Array[String] = []
	var stacks := actor.get_inventory_stacks()
	for stack in stacks:
		var id := String(stack.get("id", ""))
		if id == "" or ProductCatalog.is_package(id):
			continue
		if shelf.can_receive(id):
			ids.append(id)
	return ids


func _open_box_menu(box: DeliveryBox, screen_position: Vector2) -> void:
	_target_box = box
	var actor := _get_actor()
	if actor == null:
		return
	_select_worker(actor)
	if actor.is_packing() or actor.has_package() or actor.free_capacity() <= 0 or box.count <= 0:
		_context_menu.hide_menu()
		return
	_context_menu.show_actions(screen_position, [{"id": "pickup", "label": "Pick up box"}])


func _on_action_selected(id: String, quantity: int = 1) -> void:
	_suppress_tap_until_frame = Engine.get_process_frames()
	_context_menu.hide_menu()
	if id.begins_with("put_"):
		_target_shelf_product = id.substr(4)
		_start_shelf_action(false, quantity)
		return
	match id:
		"go_here":
			if _selected_worker:
				_selected_worker.walk_to_world(_pending_target)
		"take":
			_start_shelf_action(true, quantity)
		"pickup":
			_start_pickup()
		"take_order":
			_start_take_order()
		"pack_order":
			_start_pack_order()
		"fulfill_order":
			_start_fulfill_order()


func _start_take_order() -> void:
	var customer := _target_customer
	var queue := _get_queue()
	if customer == null or queue == null:
		return
	var actor := _get_actor()
	if actor == null:
		return
	_select_worker(actor)
	var approach := customer.get_approach_position()
	actor.walk_to_world(
		approach,
		func() -> void:
			if not is_instance_valid(actor) or not is_instance_valid(customer):
				return
			if not queue.can_take_order(customer):
				return
			actor.face_world(customer.get_face_target())
			queue.take_order(customer)
	)


func _start_pack_order() -> void:
	var table := _target_packing_table
	var queue := _get_queue()
	if table == null or queue == null:
		return
	var actor := _get_actor()
	if actor == null or not _can_pack_order(actor):
		return
	var order := queue.get_active_order()
	_select_worker(actor)
	actor.walk_to_world(
		table.get_approach_position(),
		func() -> void:
			if not is_instance_valid(actor) or not is_instance_valid(table):
				return
			if not _can_pack_order(actor):
				return
			actor.face_world(table.get_face_target())
			actor.start_packing(func() -> void: _complete_packing(actor, order))
	)


func _complete_packing(actor: Worker, order: Dictionary) -> void:
	if not is_instance_valid(actor):
		return
	var queue := _get_queue()
	if queue == null:
		return
	if not ProductCatalog.orders_match(queue.get_active_order(), order):
		return
	if not actor.consume_order_and_pack(order):
		return
	if not queue.mark_order_packed():
		actor.restore_packed_order(order)


func _start_fulfill_order() -> void:
	var customer := _target_customer
	var queue := _get_queue()
	if customer == null or queue == null:
		return
	var actor := _get_actor()
	if actor == null or not _can_fulfill_order(actor, customer, queue):
		return
	_select_worker(actor)
	var approach := customer.get_approach_position()
	actor.walk_to_world(
		approach,
		func() -> void:
			if not is_instance_valid(actor) or not is_instance_valid(customer):
				return
			if customer.is_departing():
				return
			if not customer.is_waiting_pickup():
				return
			if not queue.can_fulfill_order(customer):
				return
			actor.face_world(customer.get_face_target())
			queue.deliver_to_customer(customer, actor)
	)


func _get_queue() -> CustomerQueue:
	return get_tree().get_first_node_in_group("customer_queue") as CustomerQueue


func _start_shelf_action(take: bool, quantity: int = 1) -> void:
	var shelf := _target_shelf
	if shelf == null:
		return
	var actor := _get_actor()
	if actor == null:
		return
	_select_worker(actor)
	var amount := maxi(1, quantity)
	actor.walk_to_world(
		shelf.get_approach_position(),
		func() -> void: _perform_shelf_action(actor, shelf, take, amount)
	)


func _perform_shelf_action(
	actor: Worker,
	shelf: ProductShelf,
	take: bool,
	quantity: int = 1
) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(shelf):
		return
	if actor.is_packing() or actor.has_package():
		return
	actor.face_world(shelf.get_face_target())
	if take:
		# Take from shelf → worker inventory.
		var remaining := maxi(1, quantity)
		while remaining > 0:
			if not shelf.can_take() or actor.is_inventory_full():
				break
			var taken_id := shelf.product_id
			if shelf.take_one() and actor.add_product(taken_id):
				remaining -= 1
			else:
				break
	else:
		# Stock from worker inventory → shelf. Product was resolved by _target_shelf_product.
		var stock_id := _target_shelf_product
		if stock_id == "" and shelf.product_id != "":
			stock_id = shelf.product_id
		if stock_id == "" or ProductCatalog.is_package(stock_id):
			return
		var to_move := mini(
			maxi(1, quantity),
			mini(actor.count_product(stock_id), shelf.free_space())
		)
		if to_move > 0 and shelf.can_receive(stock_id):
			var removed := actor.remove_products(stock_id, to_move)
			shelf.stock_product(stock_id, removed)


func _start_pickup() -> void:
	var box := _target_box
	if box == null:
		return
	var actor := _get_actor()
	if actor == null:
		return
	_select_worker(actor)
	actor.walk_to_world(
		box.get_approach_position(),
		func() -> void:
			if not is_instance_valid(actor) or not is_instance_valid(box):
				return
			if actor.is_packing() or actor.has_package():
				return
			actor.face_world(box.get_face_target())
			box.unload_into(actor)
	)


func _get_actor() -> Worker:
	if _selected_worker:
		return _selected_worker
	var workers := get_tree().get_nodes_in_group("workers")
	return workers[0] as Worker if not workers.is_empty() else null


func _auto_select_manager() -> void:
	var workers := get_tree().get_nodes_in_group("workers")
	if workers.is_empty():
		return
	_select_worker(workers[0] as Worker)


func _select_worker(worker: Worker) -> void:
	if _selected_worker == worker:
		worker.set_selected(true)
		return
	_deselect_worker()
	_selected_worker = worker
	_selected_worker.set_selected(true)


func _deselect_worker() -> void:
	if _selected_worker:
		_selected_worker.set_selected(false)
	_selected_worker = null


func _raycast_interactable(screen_position: Vector2) -> Node:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	var space := get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
	query.collision_mask = CHARACTER_COLLISION_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	return _interactable_from_node(hit.collider as Node)


func _interactable_from_node(node: Node) -> Node:
	var current := node
	while current:
		if (
			current is Worker
			or current is ProductShelf
			or current is Customer
			or current is PackingTable
			or current is DeliveryBox
		):
			return current
		current = current.get_parent()
	return null


func _pick_warehouse_floor(screen_position: Vector2) -> Vector3:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return Vector3.INF

	var t := -origin.y / direction.y
	if t <= 0.0:
		return Vector3.INF

	var hit := origin + direction * t
	if not _grid.is_warehouse_cell(_grid.world_to_cell(hit)):
		return Vector3.INF

	return Vector3(hit.x, 0.0, hit.z)
