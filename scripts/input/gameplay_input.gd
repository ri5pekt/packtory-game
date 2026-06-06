extends Node

## Pointer interaction: select the worker, queue actions, and execute them in order.

const WarehouseEditModeScript = preload("res://scripts/warehouse/warehouse_edit_mode.gd")
const OutboundDeliveryVehicleScript = preload(
	"res://scripts/warehouse/outbound_delivery_vehicle.gd"
)
const OutboundDispatchConfigScript = preload(
	"res://scripts/gameplay/outbound_dispatch_config.gd"
)
const InteractableRaycastScript = preload("res://scripts/shared/interactable_raycast.gd")
const WalkInteractionScript = preload("res://scripts/shared/walk_interaction.gd")
const ComputerTerminalFlowScript = preload("res://scripts/shared/computer_terminal_flow.gd")
const WorkerContextActionsScript = preload("res://scripts/gameplay/worker_context_actions.gd")
const WorkerTaskAssignmentFlowScript = preload(
	"res://scripts/shared/worker_task_assignment_flow.gd"
)
const CHARACTER_COLLISION_MASK := 1
const INVENTORY_FULL_MSG := "No more space in inventory."

var _grid: WarehouseGrid
var _camera: Camera3D
var _selected_worker: Worker
var _pending_target: Vector3 = Vector3.ZERO
var _target_shelf: ProductShelf
var _target_storage_shelf: StorageShelf
var _target_shelf_product: String = ""
var _target_customer: Customer
var _target_packing_table: PackingTable
var _target_workstation: Node3D
var _target_box: DeliveryBox
var _target_equipment_box: Node3D
var _target_outbound_vehicle: Node3D
var _target_worker: Worker
var _target_garbage: Node3D
var _cleaning_garbage := false
var _entering_computer := false
var _assigning_tasks := false
var _loading_outbound_package := false
var _dispatching_outbound_van := false
var _suppress_tap_until_frame: int = -1
var _queued_failure_reason := ""

@onready var _touch_input: Node = $"../TouchInput"
@onready var _camera_rig: Node3D = $"../IsoCameraRig"
@onready var _context_menu: VBoxContainer = $"../UI/ContextMenu"
@onready var _action_queue: ActionQueue = $ActionQueue


func _ready() -> void:
	add_to_group("gameplay_input")
	_grid = get_node("/root/GridService") as WarehouseGrid
	_touch_input.tap.connect(_on_tap)
	_context_menu.action_selected.connect(_on_action_selected)
	_context_menu.hide_menu()
	_action_queue.configure(self, _get_actor, _get_queue)
	if not _action_queue.action_failed.is_connected(_on_action_failed):
		_action_queue.action_failed.connect(_on_action_failed)
	_bind_camera()
	call_deferred("_auto_select_manager")


func _is_gameplay_active() -> bool:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return true
	return session.is_gameplay_active()


func _bind_camera() -> void:
	_camera = _camera_rig.get_camera()


func get_selected_worker() -> Worker:
	return _selected_worker


func execute_queued_action(action: QueuedAction, on_done: Callable) -> void:
	var actor := _get_actor()
	if actor == null:
		on_done.call(false)
		return
	match action.type:
		QueuedAction.Type.GO_HERE:
			actor.walk_to_world(action.floor_position, func() -> void: on_done.call(true))
		QueuedAction.Type.TAKE_ORDER:
			_execute_take_order(actor, action, on_done)
		QueuedAction.Type.COLLECT_SHELF:
			_execute_collect(actor, action, on_done)
		QueuedAction.Type.STOCK_SHELF:
			_execute_stock(actor, action, on_done)
		QueuedAction.Type.PACK_ORDER:
			_execute_pack(actor, action, on_done)
		QueuedAction.Type.DELIVER_ORDER:
			_execute_deliver(actor, action, on_done)
		QueuedAction.Type.PICKUP_BOX:
			_execute_pickup_box(actor, action, on_done)
		QueuedAction.Type.PICKUP_EQUIPMENT_BOX:
			_execute_pickup_equipment_box(actor, action, on_done)
		QueuedAction.Type.STORE_BOX_ON_STORAGE:
			_execute_store_box_on_storage(actor, action, on_done)
		QueuedAction.Type.WITHDRAW_BOX_FROM_STORAGE:
			_execute_withdraw_box_from_storage(actor, action, on_done)
		_:
			on_done.call(false)


func _on_tap(screen_position: Vector2) -> void:
	if _camera == null:
		_bind_camera()
	if _camera == null:
		return
	if not _is_gameplay_active():
		_context_menu.hide_menu()
		return
	var placement_mode: Node = get_node_or_null("../WarehousePlacementMode")
	if placement_mode != null and placement_mode.is_active():
		_context_menu.hide_menu()
		placement_mode.handle_tap(screen_position)
		return
	var edit_mode: Node = get_node_or_null("../WarehouseEditMode")
	if edit_mode != null and edit_mode.is_active():
		_context_menu.hide_menu()
		edit_mode.handle_tap(screen_position)
		return
	var computer_ui := _get_computer_ui()
	if computer_ui != null and computer_ui.is_open():
		_context_menu.hide_menu()
		if computer_ui.notify_world_tap(screen_position):
			return
	var task_ui := _get_task_assignment_ui()
	if task_ui != null and task_ui.is_open():
		_context_menu.hide_menu()
		if task_ui.notify_world_tap(screen_position):
			return
	var settings_ui := _get_settings_menu_ui()
	if settings_ui != null and settings_ui.is_open():
		_context_menu.hide_menu()
		if settings_ui.notify_world_tap(screen_position):
			return
	var debug_ui := _get_debug_panel_ui()
	if debug_ui != null and debug_ui.is_open():
		_context_menu.hide_menu()
		if debug_ui.notify_world_tap(screen_position):
			return
	var summary_ui := _get_day_end_summary_ui()
	if summary_ui != null and summary_ui.is_open():
		_context_menu.hide_menu()
		if summary_ui.notify_world_tap(screen_position):
			return
	if Engine.get_process_frames() <= _suppress_tap_until_frame:
		return
	if _context_menu.visible and _context_menu.get_global_rect().has_point(screen_position):
		return
	var hud := get_node_or_null("../UI/HUD")
	if hud != null and hud.has_method("notify_world_tap"):
		if hud.notify_world_tap(screen_position):
			return

	var floor_target := InteractableRaycastScript.pick_warehouse_floor(
		_camera, _grid, screen_position
	)
	var hit := InteractableRaycastScript.pick_interactable(
		_camera, screen_position, CHARACTER_COLLISION_MASK
	)

	if hit is Worker and _selected_worker == hit and floor_target != Vector3.INF:
		hit = null

	if hit is Worker:
		_open_worker_menu(hit, screen_position)
		return
	if hit is ProductShelf:
		_open_shelf_menu(hit, screen_position)
		return
	if hit is StorageShelf:
		_open_storage_shelf_menu(hit, screen_position)
		return
	if hit is Customer:
		_open_customer_menu(hit, screen_position)
		return
	if hit is PackingTable:
		_open_packing_menu(hit, screen_position)
		return
	if hit is Node3D and hit.is_in_group("computer_workstations"):
		_open_computer_menu(hit, screen_position)
		return
	if hit is DeliveryBox:
		_open_box_menu(hit, screen_position)
		return
	if hit is Node3D and hit.is_in_group("floor_garbage"):
		_open_garbage_menu(hit, screen_position)
		return
	if hit is Node3D and hit.is_in_group("equipment_delivery_boxes"):
		_open_equipment_box_menu(hit, screen_position)
		return
	if hit is Node3D and hit.is_in_group("outbound_delivery_vehicles"):
		_open_outbound_vehicle_menu(hit, screen_position)
		return

	if _selected_worker == null:
		_auto_select_manager()

	if _selected_worker and _selected_worker.is_packing():
		_warn("Worker is busy packing.")
		return

	if _selected_worker and floor_target != Vector3.INF:
		_pending_target = floor_target
		_target_shelf = null
		_context_menu.show_actions(screen_position, [{"id": "go_here", "label": "Go Here"}])
		return

	_deselect_worker()
	_context_menu.hide_menu()


func _open_storage_shelf_menu(shelf: StorageShelf, screen_position: Vector2) -> void:
	_target_storage_shelf = shelf
	var actor := _get_actor()
	if actor == null:
		_warn("No worker available.")
		return
	_select_worker(actor)
	var actions: Array = _storage_shelf_actions(shelf, actor)
	if actions.is_empty():
		_context_menu.hide_menu()
		_warn(_storage_shelf_no_actions_reason(shelf, actor))
		return
	_context_menu.show_actions(screen_position, actions)


func _open_shelf_menu(shelf: ProductShelf, screen_position: Vector2) -> void:
	_target_shelf = shelf
	var actor := _get_actor()
	if actor == null:
		_warn("No worker available.")
		return
	_select_worker(actor)

	var actions: Array = _shelf_actions(shelf, actor)
	if actions.is_empty():
		_context_menu.hide_menu()
		_warn(_shelf_no_actions_reason(shelf, actor))
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
	if queue.can_take_order(customer) and not _projected().has_package:
		var take := QueuedAction.make_take_order(customer, customer.order)
		if _action_queue.can_enqueue(take):
			actions.append({"id": "take_order", "label": "Take order"})
	var deliver := QueuedAction.make_deliver(customer)
	if _action_queue.can_enqueue(deliver):
		actions.append({"id": "fulfill_order", "label": "Fulfill order"})

	if actions.is_empty():
		_context_menu.hide_menu()
		_warn(_customer_no_actions_reason(customer, actor, queue))
		return

	_select_worker(actor)
	_context_menu.show_actions(screen_position, actions)


func _open_computer_menu(workstation: Node3D, screen_position: Vector2) -> void:
	_target_workstation = workstation
	var actor := _get_actor()
	if actor == null:
		_warn("No worker available.")
		return
	if _get_computer_ui() != null and _get_computer_ui().is_open():
		return
	_select_worker(actor)
	_context_menu.show_actions(
		screen_position,
		[{"id": "enter_computer", "label": "Enter computer"}]
	)


func _open_packing_menu(table: PackingTable, screen_position: Vector2) -> void:
	_target_packing_table = table
	var actor := _get_actor()
	var queue := _get_queue()
	if actor == null or queue == null:
		return
	_select_worker(actor)
	if not _can_pack_order(actor):
		_context_menu.hide_menu()
		_warn(_pack_no_actions_reason(actor, queue))
		return
	var order := queue.get_active_order()
	var pack_action := QueuedAction.make_pack(table, order)
	pack_action.order_source = queue.get_order_source()
	if not _action_queue.can_enqueue(pack_action):
		_context_menu.hide_menu()
		_warn("Can't pack right now — finish or clear queued actions first.")
		return
	_context_menu.show_actions(screen_position, [{"id": "pack_order", "label": "Pack the order"}])


func _open_outbound_vehicle_menu(vehicle: Node3D, screen_position: Vector2) -> void:
	_target_outbound_vehicle = vehicle
	var actor := _get_actor()
	if actor == null:
		_warn("No worker available.")
		return
	_select_worker(actor)
	var van := vehicle as OutboundDeliveryVehicle
	if van == null:
		_warn("Delivery van isn't available.")
		return
	if van.is_on_route():
		_context_menu.hide_menu()
		_warn(van.get_dispatch_block_reason())
		return
	var actions: Array = []
	if actor.is_online_package() and van.is_available():
		actions.append({"id": "load_online_package", "label": "Load online package"})
	if van.can_dispatch():
		var fee := OutboundDispatchConfigScript.dispatch_fee()
		actions.append({
			"id": "dispatch_van",
			"label": "Dispatch van (%d coins)" % fee,
		})
	if actions.is_empty():
		_context_menu.hide_menu()
		var hint := van.get_dispatch_block_reason()
		if hint == "":
			hint = (
				"Delivery van (%s). Carry a packed online order here to load it."
				% van.get_cargo_summary()
			)
		_warn(hint)
		return
	_context_menu.show_actions(screen_position, actions)


func _can_pack_order(actor: Worker) -> bool:
	var queue := _get_queue()
	if queue == null or actor == null:
		return false
	if actor.is_packing():
		return false
	var projected := _projected()
	if projected.has_package:
		return false
	var order := queue.get_active_order()
	return projected.can_pack_order(order, queue)


func _shelf_actions(shelf: ProductShelf, _actor: Worker) -> Array:
	var actions: Array = []
	var projected := _projected()
	if projected.has_package:
		return actions

	if shelf.can_take():
		var free_cap := projected._free_carry_capacity()
		var max_qty := mini(shelf.count, free_cap)
		var collect := QueuedAction.make_collect(shelf, 1)
		if max_qty > 0 and projected.can_collect_from_shelf(shelf, 1) \
				and _action_queue.can_enqueue(collect):
			actions.append({
				"id": "take",
				"label": "Take %s" % ProductCatalog.display_name(shelf.product_id),
				"quantity": {"min": 1, "max": max_qty, "default": 1},
			})

	for product_id in _stockable_ids_for_shelf(shelf, projected):
		var held := projected.count_product(product_id)
		var max_put := mini(held, shelf.free_space())
		if max_put > 0:
			var pid := product_id
			var stock := QueuedAction.make_stock(shelf, pid, 1)
			if _action_queue.can_enqueue(stock):
				actions.append({
					"id": "put_%s" % pid,
					"label": "Stock: %s" % ProductCatalog.display_name(pid),
					"quantity": {"min": 1, "max": max_put, "default": max_put},
				})

	for box in projected.carried_boxes:
		var box_id := int(box.get("id", -1))
		var pid := String(box.get("product_id", ""))
		var box_count := int(box.get("count", 0))
		if box_id < 0 or pid == "" or box_count <= 0:
			continue
		if not shelf.can_receive(pid):
			continue
		var max_unpack := mini(box_count, shelf.free_space())
		if max_unpack <= 0:
			continue
		var unpack := QueuedAction.make_stock_from_box(shelf, box_id, pid, 1)
		if _action_queue.can_enqueue(unpack):
			actions.append({
				"id": "unpack_box_%d" % box_id,
				"label": "Unpack box: %s" % ProductCatalog.display_name(pid),
				"quantity": {"min": 1, "max": max_unpack, "default": max_unpack},
			})
	return actions


func _storage_shelf_actions(shelf: StorageShelf, _actor: Worker) -> Array:
	var actions: Array = []
	var projected := _projected()
	if projected.has_package:
		return actions

	for box in projected.carried_boxes:
		var worker_box_id := int(box.get("id", -1))
		var pid := String(box.get("product_id", ""))
		var box_count := int(box.get("count", 0))
		if worker_box_id < 0 or pid == "" or box_count <= 0:
			continue
		var store_action := QueuedAction.make_store_box_on_storage(shelf, worker_box_id, pid)
		if _action_queue.can_enqueue(store_action):
			actions.append({
				"id": "store_box_%d" % worker_box_id,
				"label": "Store box: %s (×%d)" % [ProductCatalog.display_name(pid), box_count],
			})

	if projected._free_carry_capacity() > 0:
		for stored in shelf.get_stored_boxes():
			var storage_box_id := int(stored.get("id", -1))
			var pid := String(stored.get("product_id", ""))
			var box_count := int(stored.get("count", 0))
			if storage_box_id < 0 or pid == "" or box_count <= 0:
				continue
			var take_action := QueuedAction.make_withdraw_box_from_storage(shelf, storage_box_id)
			if _action_queue.can_enqueue(take_action):
				actions.append({
					"id": "take_storage_box_%d" % storage_box_id,
					"label": "Take box: %s (×%d)" % [ProductCatalog.display_name(pid), box_count],
				})
	return actions


func _storage_shelf_no_actions_reason(shelf: StorageShelf, actor: Worker) -> String:
	var projected := _projected()
	if projected.has_package:
		return "Put down the package before using storage shelves."
	if shelf.can_store_box() and not projected.carried_boxes.is_empty():
		return "Can't store that box right now — check your action queue."
	if shelf.can_withdraw_box() and projected._free_carry_capacity() > 0:
		return "Can't take a box right now — check your action queue."
	if not shelf.can_store_box() and shelf.get_box_count() >= shelf.MAX_BOX_SLOTS:
		return "This storage shelf is full."
	if projected.carried_boxes.is_empty() and not shelf.can_withdraw_box():
		return "No boxes to store or take."
	if actor.is_inventory_full():
		return INVENTORY_FULL_MSG
	return "No storage actions available."


func _stockable_ids_for_shelf(shelf: ProductShelf, projected: ProjectedState) -> Array[String]:
	var ids: Array[String] = []
	for product_id in projected.inventory:
		var id := String(product_id)
		if id == "" or ProductCatalog.is_package(id):
			continue
		if shelf.can_receive(id):
			ids.append(id)
	return ids


func _open_equipment_box_menu(box: Node3D, screen_position: Vector2) -> void:
	_target_equipment_box = box
	var actor := _get_actor()
	if actor == null:
		return
	_select_worker(actor)
	var projected := _projected()
	if projected.has_package or projected._free_carry_capacity() <= 0:
		_context_menu.hide_menu()
		_warn(INVENTORY_FULL_MSG if projected._free_carry_capacity() <= 0 else "Can't pick that up right now.")
		return
	var pickup := QueuedAction.make_pickup_equipment_box(box)
	if not _action_queue.can_enqueue(pickup):
		_context_menu.hide_menu()
		_warn(INVENTORY_FULL_MSG if projected._free_carry_capacity() <= 0 else "Can't pick that up right now.")
		return
	_context_menu.show_actions(
		screen_position,
		[{"id": "pickup_equipment", "label": "Pick up %s box" % String(box.get("delivery_label"))}]
	)


func _open_box_menu(box: DeliveryBox, screen_position: Vector2) -> void:
	_target_box = box
	var actor := _get_actor()
	if actor == null:
		return
	_select_worker(actor)
	var projected := _projected()
	if projected.has_package or box.count <= 0 or projected._free_carry_capacity() <= 0:
		_context_menu.hide_menu()
		_warn(_box_no_actions_reason(box, projected))
		return
	var pickup := QueuedAction.make_pickup_box(box)
	if not _action_queue.can_enqueue(pickup):
		_context_menu.hide_menu()
		if projected._free_carry_capacity() <= 0:
			_warn(INVENTORY_FULL_MSG)
		else:
			_warn("Can't pick up a box right now — check your action queue.")
		return
	_context_menu.show_actions(screen_position, [{"id": "pickup", "label": "Pick up box"}])


func _on_action_selected(id: String, quantity: int = 1) -> void:
	_suppress_tap_until_frame = Engine.get_process_frames()
	_context_menu.hide_menu()
	var queued := false
	if id.begins_with("put_"):
		_target_shelf_product = id.substr(4)
		queued = _enqueue_stock(_target_shelf, _target_shelf_product, quantity)
	elif id.begins_with("store_box_"):
		var worker_box_id := int(id.substr(10))
		queued = _enqueue_store_box_on_storage(_target_storage_shelf, worker_box_id)
	elif id.begins_with("take_storage_box_"):
		var storage_box_id := int(id.substr(17))
		queued = _enqueue_withdraw_box_from_storage(_target_storage_shelf, storage_box_id)
	elif id.begins_with("unpack_box_"):
		var box_id := int(id.substr(11))
		queued = _enqueue_stock_box(_target_shelf, box_id, quantity)
	elif id == "go_here":
		queued = _action_queue.enqueue(QueuedAction.make_go_here(_pending_target))
	elif id == "take":
		if _projected()._free_carry_capacity() < quantity:
			_warn(INVENTORY_FULL_MSG)
		else:
			queued = _enqueue_collect(_target_shelf, quantity)
	elif id == "pickup_equipment":
		if _projected()._free_carry_capacity() <= 0:
			_warn(INVENTORY_FULL_MSG)
		elif _target_equipment_box:
			queued = _action_queue.enqueue(
				QueuedAction.make_pickup_equipment_box(_target_equipment_box)
			)
	elif id == "pickup":
		if _projected()._free_carry_capacity() <= 0:
			_warn(INVENTORY_FULL_MSG)
		else:
			queued = _action_queue.enqueue(QueuedAction.make_pickup_box(_target_box))
	elif id == "take_order":
		queued = _enqueue_take_order(_target_customer)
	elif id == "pack_order":
		queued = _enqueue_pack(_target_packing_table)
	elif id == "fulfill_order":
		if _target_customer:
			queued = _action_queue.enqueue(QueuedAction.make_deliver(_target_customer))
	elif id == "clean":
		_begin_clean_garbage()
		queued = true
	elif id == "assign_tasks":
		_begin_assign_worker_tasks()
		queued = true
	elif id == "select_worker":
		if _target_worker:
			_select_worker(_target_worker)
		queued = true
	elif id == "enter_computer":
		_begin_enter_computer()
		queued = true
	elif id == "load_online_package":
		_begin_load_outbound_package()
		queued = true
	elif id == "dispatch_van":
		_begin_dispatch_outbound_van()
		queued = true
	if not queued and id != "":
		_warn("That action couldn't be queued. Try again in a moment.")


func take_action_failure_reason() -> String:
	var reason := _queued_failure_reason
	_queued_failure_reason = ""
	return reason


func _on_action_failed(reason: String) -> void:
	_warn(reason)


func _fail_queued_action(on_done: Callable, message: String) -> void:
	_queued_failure_reason = message
	on_done.call(false)


func _warn(message: String) -> void:
	if message.is_empty():
		return
	var alerts := get_node_or_null("/root/AlertMessages")
	if alerts != null and alerts.has_method("warn"):
		alerts.warn(message)


func _shelf_no_actions_reason(shelf: ProductShelf, actor: Worker) -> String:
	var projected := _projected()
	if projected.has_package or actor.has_package():
		return "Put down the package before using shelves."
	if shelf.can_take() and shelf.count > 0 and projected._free_carry_capacity() <= 0:
		return INVENTORY_FULL_MSG
	if shelf.can_take() and shelf.count > 0:
		return "Can't take from this shelf right now."
	if shelf.count <= 0:
		return "Shelf is empty and you have nothing to stock here."
	if shelf.free_space() <= 0:
		return "This shelf is full — you can't stock more here."
	return "No actions available for this shelf."


func _customer_no_actions_reason(customer: Customer, _actor: Worker, queue: CustomerQueue) -> String:
	var projected := _projected()
	var deliver := QueuedAction.make_deliver(customer)
	if _action_queue.can_enqueue(deliver):
		return "No actions available for this customer."
	if projected.has_package or _actor.has_package():
		if queue.can_fulfill_order(customer):
			return "Deliver the packed order to this customer."
		if customer.is_waiting_pickup():
			return "Serve customers in queue order."
		return "Deliver the packed order to the waiting customer first."
	if customer.is_waiting_pickup():
		return "Pack the order before delivering to this customer."
	if customer.has_pending_order() and not queue.can_take_order(customer):
		if not queue.get_active_order().is_empty():
			return "Finish the current order before taking another."
		if queue.has_pending_delivery():
			return "Deliver the packed order first."
		return "Serve customers in queue order."
	if not customer.has_pending_order() and not customer.is_waiting_pickup():
		return "This customer isn't ready yet."
	return "No actions available for this customer."


func _pack_no_actions_reason(actor: Worker, queue: CustomerQueue) -> String:
	if actor.is_packing():
		return "Already packing an order."
	var projected := _projected()
	if projected.has_package:
		if actor.is_online_package():
			return "Load the packed online order into the delivery van first."
		return "You're already carrying a package — deliver it first."
	if queue.has_pending_delivery() or projected.awaiting_delivery:
		return "Deliver the packed order before packing again."
	var order := queue.get_active_order()
	if order.is_empty():
		return "Take a customer order before packing."
	if not projected.can_pack_order(order, queue):
		var lines: PackedStringArray = []
		for product_id in order:
			var need := int(order[product_id])
			var have := projected.count_product(String(product_id))
			if have < need:
				lines.append(
					"%s (%d/%d)" % [ProductCatalog.display_name(String(product_id)), have, need]
				)
		if not lines.is_empty():
			return "Missing items: %s." % ", ".join(lines)
		return "You don't have all items for this order."
	return "Can't pack the order right now."


func _box_no_actions_reason(box: DeliveryBox, projected: ProjectedState) -> String:
	if projected.has_package:
		return "You're already carrying a package."
	if box.count <= 0:
		return "This delivery box is empty."
	if projected._free_carry_capacity() <= 0:
		return INVENTORY_FULL_MSG
	return "Can't use this box right now."


func _enqueue_take_order(customer: Customer) -> bool:
	var queue := _get_queue()
	if queue == null or customer == null:
		return false
	return _action_queue.enqueue(
		QueuedAction.make_take_order(customer, customer.order)
	)


func _enqueue_pack(table: PackingTable) -> bool:
	var actor := _get_actor()
	var queue := _get_queue()
	if actor == null or queue == null or table == null:
		return false
	if not _can_pack_order(actor):
		return false
	var order := queue.get_active_order()
	var action := QueuedAction.make_pack(table, order)
	action.order_source = queue.get_order_source()
	return _action_queue.enqueue(action)


func _enqueue_collect(shelf: ProductShelf, quantity: int) -> bool:
	if shelf == null:
		return false
	var action := QueuedAction.make_collect(shelf, quantity)
	action.label = "Collect %s" % ProductCatalog.display_name(shelf.product_id)
	return _action_queue.enqueue(action)


func _enqueue_stock(shelf: ProductShelf, product_id: String, quantity: int) -> bool:
	if shelf == null or product_id == "":
		return false
	return _action_queue.enqueue(QueuedAction.make_stock(shelf, product_id, quantity))


func _enqueue_store_box_on_storage(shelf: StorageShelf, worker_box_id: int) -> bool:
	if shelf == null:
		return false
	var actor := _get_actor()
	if actor == null:
		return false
	var box_index := actor.find_box_index_by_id(worker_box_id)
	if box_index < 0:
		return false
	var pid := String(actor.get_carried_boxes()[box_index].get("product_id", ""))
	return _action_queue.enqueue(
		QueuedAction.make_store_box_on_storage(shelf, worker_box_id, pid)
	)


func _enqueue_withdraw_box_from_storage(shelf: StorageShelf, storage_box_id: int) -> bool:
	if shelf == null:
		return false
	return _action_queue.enqueue(
		QueuedAction.make_withdraw_box_from_storage(shelf, storage_box_id)
	)


func _enqueue_stock_box(shelf: ProductShelf, box_id: int, quantity: int) -> bool:
	if shelf == null or box_id < 0:
		return false
	var projected := _projected()
	var box_index := projected._find_box_index(box_id)
	if box_index < 0:
		return false
	var product_id := String(projected.carried_boxes[box_index].get("product_id", ""))
	if product_id == "":
		return false
	return _action_queue.enqueue(
		QueuedAction.make_stock_from_box(shelf, box_id, product_id, quantity)
	)


func _execute_take_order(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
	var customer := action.target as Customer
	var queue := _get_queue()
	if customer == null or queue == null:
		on_done.call(false)
		return
	WalkInteractionScript.walk_face_then(
		actor,
		customer.get_approach_position(),
		customer.get_face_target(),
		func(ok: bool) -> void:
			if not ok or not is_instance_valid(customer):
				on_done.call(false)
				return
			if not queue.can_take_order(customer):
				on_done.call(false)
				return
			on_done.call(queue.take_order(customer))
	)


func _execute_collect(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
	var shelf := action.target as ProductShelf
	if shelf == null:
		on_done.call(false)
		return
	actor.walk_to_world(
		shelf.get_approach_position(),
		func() -> void:
			if not is_instance_valid(actor) or not is_instance_valid(shelf):
				on_done.call(false)
				return
			var moved := _perform_shelf_take(actor, shelf, action.quantity)
			if moved <= 0 and actor.is_inventory_full():
				_fail_queued_action(on_done, INVENTORY_FULL_MSG)
				return
			on_done.call(moved > 0)
	)


func _execute_stock(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
	var shelf := action.target as ProductShelf
	if shelf == null:
		on_done.call(false)
		return
	actor.walk_to_world(
		shelf.get_approach_position(),
		func() -> void:
			if not is_instance_valid(actor) or not is_instance_valid(shelf):
				on_done.call(false)
				return
			var moved := 0
			if action.stock_from_box_id >= 0:
				moved = _perform_shelf_stock_box(
					actor, shelf, action.stock_from_box_id, action.quantity
				)
			else:
				moved = _perform_shelf_stock(actor, shelf, action.product_id, action.quantity)
			on_done.call(moved > 0)
	)


func _execute_pack(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
	var table := action.target as PackingTable
	var queue := _get_queue()
	if table == null or queue == null:
		_fail_queued_action(on_done, "Packing table isn't available.")
		return
	var order := action.order_snapshot
	if order.is_empty():
		_fail_queued_action(on_done, "Take a customer order before packing.")
		return
	actor.walk_to_world(
		table.get_approach_position(),
		func() -> void:
			if not is_instance_valid(actor) or not is_instance_valid(table):
				_fail_queued_action(on_done, "Packing was interrupted.")
				return
			if actor.has_package():
				_fail_queued_action(on_done, "You already have a package to deliver.")
				return
			if not ProductCatalog.inventory_fulfills_order(actor.get_inventory(), order):
				_fail_queued_action(on_done, "You're missing items for this order.")
				return
			actor.face_world(table.get_face_target())
			if not actor.start_packing(
				func() -> void:
					on_done.call(_complete_packing(actor, order)),
				table
			):
				_fail_queued_action(on_done, "Couldn't start packing.")
	)


func _execute_deliver(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
	var customer := action.target as Customer
	var queue := _get_queue()
	if customer == null or queue == null:
		_fail_queued_action(on_done, "Customer isn't available.")
		return
	if not actor.has_package():
		_fail_queued_action(on_done, "Carry the packed order before delivering.")
		return
	WalkInteractionScript.walk_face_then(
		actor,
		customer.get_approach_position(),
		customer.get_face_target(),
		func(ok: bool) -> void:
			if not ok or not is_instance_valid(actor):
				_fail_queued_action(on_done, "Couldn't reach the customer.")
				return
			if not is_instance_valid(customer):
				_fail_queued_action(on_done, "Customer isn't available.")
				return
			if customer.is_departing():
				_fail_queued_action(on_done, "That customer is already leaving.")
				return
			if queue.deliver_to_customer(customer, actor):
				on_done.call(true)
				return
			var reason := queue.get_fulfill_block_reason(customer, actor)
			if reason.is_empty():
				reason = "Action could not be completed."
			_fail_queued_action(on_done, reason)
	)


func _execute_pickup_equipment_box(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
	var box := action.target as Node3D
	if box == null or not box.has_method("pickup_into"):
		on_done.call(false)
		return
	WalkInteractionScript.walk_face_then(
		actor,
		box.get_approach_position(),
		box.get_face_target(),
		func(ok: bool) -> void:
			if not ok or not is_instance_valid(box):
				on_done.call(false)
				return
			if actor.is_packing() or actor.has_package() or actor.is_inventory_full():
				_fail_queued_action(on_done, INVENTORY_FULL_MSG)
				return
			if not box.pickup_into(actor):
				_fail_queued_action(on_done, INVENTORY_FULL_MSG)
				return
			on_done.call(true)
	)


func _execute_store_box_on_storage(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
	var shelf := action.target as StorageShelf
	if shelf == null:
		on_done.call(false)
		return
	WalkInteractionScript.walk_face_then(
		actor,
		shelf.get_approach_position(),
		shelf.get_face_target(),
		func(ok: bool) -> void:
			if not ok or not is_instance_valid(shelf):
				on_done.call(false)
				return
			if actor.is_packing() or actor.has_package():
				on_done.call(false)
				return
			var stored := actor.deposit_box_to_storage(action.stock_from_box_id, shelf)
			on_done.call(stored)
	)


func _execute_withdraw_box_from_storage(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
	var shelf := action.target as StorageShelf
	if shelf == null:
		on_done.call(false)
		return
	WalkInteractionScript.walk_face_then(
		actor,
		shelf.get_approach_position(),
		shelf.get_face_target(),
		func(ok: bool) -> void:
			if not ok or not is_instance_valid(shelf):
				on_done.call(false)
				return
			if actor.is_packing() or actor.has_package():
				on_done.call(false)
				return
			if not actor.withdraw_box_to_inventory(shelf, action.storage_box_id):
				_fail_queued_action(on_done, INVENTORY_FULL_MSG)
				return
			on_done.call(true)
	)


func _execute_pickup_box(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
	var box := action.target as DeliveryBox
	if box == null:
		on_done.call(false)
		return
	WalkInteractionScript.walk_face_then(
		actor,
		box.get_approach_position(),
		box.get_face_target(),
		func(ok: bool) -> void:
			if not ok or not is_instance_valid(box):
				on_done.call(false)
				return
			if actor.is_packing() or actor.has_package():
				on_done.call(false)
				return
			if actor.is_inventory_full():
				_fail_queued_action(on_done, INVENTORY_FULL_MSG)
				return
			if not box.pickup_into(actor):
				_fail_queued_action(on_done, INVENTORY_FULL_MSG)
				return
			on_done.call(true)
	)


func _complete_packing(actor: Worker, order: Dictionary) -> bool:
	if not is_instance_valid(actor):
		_queued_failure_reason = "Packing was interrupted."
		return false
	var queue := _get_queue()
	if queue == null:
		_queued_failure_reason = "Customer queue isn't available."
		return false
	if order.is_empty():
		_queued_failure_reason = "No active order to pack."
		return false
	var active := queue.get_active_order()
	if not active.is_empty() and not ProductCatalog.orders_match(active, order):
		_queued_failure_reason = "The order changed while you were packing."
		return false
	if not actor.consume_order_and_pack(order):
		if actor.has_package():
			_queued_failure_reason = "You already have a package to deliver."
		else:
			_queued_failure_reason = "You're missing items for this order."
		return false
	var order_source := queue.get_order_source()
	var online_number := queue.get_online_order_number()
	if not queue.mark_order_packed():
		# Customer may have left while packing — keep the package so the work
		# isn't lost. The player can still deliver it or discard it themselves.
		if order_source == "online":
			_queued_failure_reason = "Online order changed while packing — package kept."
		else:
			_queued_failure_reason = ""  # silent; package stays in inventory
		# Don't restore — actor already has the package and did the work
		return true
	if order_source == CustomerQueue.SOURCE_ONLINE:
		actor.tag_carried_package({
			"source": CustomerQueue.SOURCE_ONLINE,
			"online_order_number": online_number,
		})
	return true


func _perform_shelf_take(actor: Worker, shelf: ProductShelf, quantity: int) -> int:
	if actor.is_packing() or actor.has_package():
		return 0
	actor.face_world(shelf.get_face_target())
	var moved := 0
	var remaining := maxi(1, quantity)
	while remaining > 0:
		if not shelf.can_take() or actor.is_inventory_full():
			break
		var taken_id := shelf.product_id
		if shelf.take_one() and actor.add_product(taken_id):
			moved += 1
			remaining -= 1
		else:
			break
	return moved


func _perform_shelf_stock_box(
	actor: Worker,
	shelf: ProductShelf,
	box_id: int,
	quantity: int
) -> int:
	if actor.is_packing() or actor.has_package():
		return 0
	actor.face_world(shelf.get_face_target())
	return actor.stock_from_box_id(box_id, shelf, maxi(1, quantity))


func _perform_shelf_stock(
	actor: Worker,
	shelf: ProductShelf,
	product_id: String,
	quantity: int
) -> int:
	if actor.is_packing() or actor.has_package():
		return 0
	if product_id == "" or ProductCatalog.is_package(product_id):
		return 0
	actor.face_world(shelf.get_face_target())
	var to_move := mini(
		maxi(1, quantity),
		mini(actor.count_product(product_id), shelf.free_space())
	)
	if to_move <= 0 or not shelf.can_receive(product_id):
		return 0
	var removed := actor.remove_products(product_id, to_move)
	return shelf.stock_product(product_id, removed)


func _projected() -> ProjectedState:
	return _action_queue.projected_state()


func _begin_load_outbound_package() -> void:
	if _loading_outbound_package:
		return
	var vehicle := _target_outbound_vehicle as OutboundDeliveryVehicle
	var actor := _get_actor()
	if vehicle == null or actor == null:
		_warn("Delivery van isn't available right now.")
		return
	var block_reason := vehicle.get_load_block_reason(actor)
	if block_reason != "":
		_warn(block_reason)
		return
	_loading_outbound_package = true
	WalkInteractionScript.walk_face_then(
		actor,
		vehicle.get_approach_position(),
		vehicle.get_face_target(),
		func(_ok: bool) -> void:
			_loading_outbound_package = false
			if not is_instance_valid(actor) or not is_instance_valid(vehicle):
				return
			if actor.is_packing():
				_warn("Worker is busy packing.")
				return
			if not vehicle.try_load_from_worker(actor):
				var reason: String = vehicle.get_load_block_reason(actor)
				if reason == "":
					reason = "Couldn't load the package into the van."
				_warn(reason)
	)


func _begin_dispatch_outbound_van() -> void:
	if _dispatching_outbound_van:
		return
	var vehicle := _target_outbound_vehicle as OutboundDeliveryVehicle
	var actor := _get_actor()
	if vehicle == null or actor == null:
		_warn("Delivery van isn't available right now.")
		return
	var block_reason := vehicle.get_dispatch_block_reason()
	if block_reason != "":
		_warn(block_reason)
		return
	_dispatching_outbound_van = true
	WalkInteractionScript.walk_face_then(
		actor,
		vehicle.get_approach_position(),
		vehicle.get_face_target(),
		func(_ok: bool) -> void:
			_dispatching_outbound_van = false
			if not is_instance_valid(vehicle):
				return
			var result: Dictionary = vehicle.try_dispatch(false)
			if bool(result.get("ok", false)):
				return
			var reason := String(result.get("reason", ""))
			match reason:
				"insufficient_coins":
					_warn(
						"Not enough coins to dispatch (%d required)."
						% OutboundDispatchConfigScript.dispatch_fee()
					)
				_:
					var custom := vehicle.get_dispatch_block_reason()
					_warn(custom if custom != "" else "Couldn't dispatch the delivery van.")
	)


func _open_garbage_menu(garbage: Node3D, screen_position: Vector2) -> void:
	_target_garbage = garbage
	_context_menu.show_actions(
		screen_position,
		[{"id": "clean", "label": "Clean"}]
	)


func _begin_clean_garbage() -> void:
	if _cleaning_garbage:
		return
	var garbage := _target_garbage
	var actor := _get_actor()
	if garbage == null or actor == null:
		_warn("Can't clean that right now.")
		return
	if actor.is_packing():
		_warn("Worker is busy packing.")
		return
	_cleaning_garbage = true
	WalkInteractionScript.walk_face_then(
		actor,
		garbage.get_approach_position(),
		garbage.get_face_target(),
		func(ok: bool) -> void:
			_cleaning_garbage = false
			if not ok or not is_instance_valid(garbage):
				return
			if garbage.has_method("clean"):
				garbage.clean()
	)


func _open_worker_menu(worker: Worker, screen_position: Vector2) -> void:
	_target_worker = worker
	_context_menu.show_actions(
		screen_position,
		WorkerContextActionsScript.actions_for_worker(worker)
	)


func _begin_assign_worker_tasks() -> void:
	if _assigning_tasks:
		return
	var target := _target_worker
	var manager := _get_manager()
	var task_ui := _get_task_assignment_ui()
	if target == null or manager == null or task_ui == null:
		_warn("Task assignment isn't available right now.")
		return
	if target.is_manager():
		_warn("Select a hired worker to assign tasks.")
		return
	if task_ui.is_open():
		return
	if manager.is_packing():
		_warn("Manager is busy packing.")
		return
	_assigning_tasks = true
	var started := WorkerTaskAssignmentFlowScript.begin_assign(
		manager,
		target,
		task_ui,
		Callable(),
		func(opened: bool) -> void:
			_assigning_tasks = false
			if not opened:
				return
	)
	if not started:
		_assigning_tasks = false


func _begin_enter_computer() -> void:
	if _entering_computer:
		return
	var workstation := _target_workstation
	var actor := _get_actor()
	var computer_ui := _get_computer_ui()
	if workstation == null or actor == null or computer_ui == null:
		_warn("Computer isn't available right now.")
		return
	if computer_ui.is_open():
		return
	if actor.is_packing():
		_warn("Worker is busy packing.")
		return
	_entering_computer = true
	var started := ComputerTerminalFlowScript.begin_enter(
		actor,
		workstation,
		computer_ui,
		Callable(),
		func(opened: bool) -> void:
			_entering_computer = false
			if not opened:
				return
	)
	if not started:
		_entering_computer = false


func _get_computer_ui() -> Control:
	return get_node_or_null("../UI/ComputerInterfaceUI") as Control


func _get_task_assignment_ui() -> Control:
	return get_node_or_null("../UI/WorkerTaskAssignmentUI") as Control


func _get_settings_menu_ui() -> Control:
	return get_node_or_null("../UI/SettingsMenuUI") as Control


func _get_debug_panel_ui() -> Control:
	return get_node_or_null("../UI/DebugPanelUI") as Control


func _get_day_end_summary_ui() -> Control:
	return get_node_or_null("../UI/DayEndSummaryUI") as Control


func _get_manager() -> Worker:
	for node in get_tree().get_nodes_in_group("workers"):
		if node is Worker and node.is_manager():
			return node
	return null


func _get_queue() -> CustomerQueue:
	return get_tree().get_first_node_in_group("customer_queue") as CustomerQueue


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


