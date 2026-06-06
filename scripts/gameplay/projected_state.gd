class_name ProjectedState
extends RefCounted

## Simulated worker + order state after queued actions (and optional current game state).

var inventory: Dictionary = {}
var carried_boxes: Array = []
var carried_placeables: Array = []
var next_box_id: int = 1
var next_placeable_box_id: int = 1
var consumed_pickup_targets: Array = []
var consumed_clean_targets: Array = []
## Per-storage-shelf simulation: instance_id -> {stored: int, withdrawn: Array[int]}.
var storage_projection: Dictionary = {}
var has_package: bool = false
var active_order: Dictionary = {}
var order_accepted: bool = false
var awaiting_delivery: bool = false
var delivery_customer: Customer = null


static func from_game(worker: Worker, customer_queue: CustomerQueue) -> ProjectedState:
	var state := ProjectedState.new()
	if worker:
		for stack in worker.get_inventory_stacks():
			if bool(stack.get("is_box", false)):
				continue
			var id := String(stack.get("id", ""))
			if id != "":
				state.inventory[id] = int(stack.get("count", 0))
		state.carried_boxes = worker.get_carried_boxes().duplicate(true)
		for box in state.carried_boxes:
			state.next_box_id = maxi(state.next_box_id, int(box.get("id", 0)) + 1)
		state.carried_placeables = worker.get_carried_placeables().duplicate(true)
		for placeable in state.carried_placeables:
			state.next_placeable_box_id = maxi(
				state.next_placeable_box_id, int(placeable.get("id", 0)) + 1
			)
		state.has_package = worker.has_package()
		# If the worker is currently packing (progress bar filling), project the
		# result as if it already completed so the player can queue DELIVER_ORDER
		# before the animation finishes — that's the whole point of queued actions.
		if not state.has_package and worker.is_packing():
			state.has_package = true
			state.awaiting_delivery = true
	if customer_queue:
		var order := customer_queue.get_active_order()
		if not order.is_empty():
			state.active_order = order.duplicate()
			state.order_accepted = true
			state.delivery_customer = customer_queue.get_active_customer()
		elif customer_queue.has_pending_delivery():
			state.awaiting_delivery = true
			state.delivery_customer = customer_queue.get_delivery_customer()
		elif state.has_package:
			var delivery: Customer = customer_queue.get_delivery_customer()
			if delivery == null:
				delivery = customer_queue.get_active_customer()
			if delivery != null:
				state.awaiting_delivery = true
				state.delivery_customer = delivery
	return state


func duplicate_state() -> ProjectedState:
	var copy := ProjectedState.new()
	copy.inventory = inventory.duplicate()
	copy.carried_boxes = carried_boxes.duplicate(true)
	copy.carried_placeables = carried_placeables.duplicate(true)
	copy.next_box_id = next_box_id
	copy.next_placeable_box_id = next_placeable_box_id
	copy.consumed_pickup_targets = consumed_pickup_targets.duplicate()
	copy.consumed_clean_targets = consumed_clean_targets.duplicate()
	copy.storage_projection = storage_projection.duplicate(true)
	copy.has_package = has_package
	copy.active_order = active_order.duplicate()
	copy.order_accepted = order_accepted
	copy.awaiting_delivery = awaiting_delivery
	copy.delivery_customer = delivery_customer
	return copy


func apply(action: QueuedAction) -> bool:
	match action.type:
		QueuedAction.Type.GO_HERE:
			return true
		QueuedAction.Type.PICKUP_BOX:
			if has_package:
				return false
			if _free_carry_capacity() <= 0:
				return false
			var pickup_box := action.target as DeliveryBox
			if pickup_box == null or pickup_box.count <= 0:
				return false
			var pickup_key := pickup_box.get_instance_id()
			if consumed_pickup_targets.has(pickup_key):
				return false
			consumed_pickup_targets.append(pickup_key)
			carried_boxes.append({
				"id": next_box_id,
				"product_id": pickup_box.product_id,
				"count": pickup_box.count,
			})
			next_box_id += 1
			return true
		QueuedAction.Type.STORE_BOX_ON_STORAGE:
			if has_package:
				return false
			var store_box_index := _find_box_index(action.stock_from_box_id)
			if store_box_index < 0:
				return false
			var storage_store := action.target
			if storage_store == null or not storage_store.has_method("free_slots"):
				return false
			if _projected_free_storage_slots(storage_store) <= 0:
				return false
			carried_boxes.remove_at(store_box_index)
			_record_projected_storage_store(storage_store)
			return true
		QueuedAction.Type.WITHDRAW_BOX_FROM_STORAGE:
			if has_package or _free_carry_capacity() <= 0:
				return false
			var storage_withdraw := action.target
			if storage_withdraw == null or not storage_withdraw.has_method("get_stored_boxes"):
				return false
			var withdrawn: Dictionary = _peek_storage_box(storage_withdraw, action.storage_box_id)
			if withdrawn.is_empty():
				return false
			_record_projected_storage_withdraw(storage_withdraw, action.storage_box_id)
			carried_boxes.append({
				"id": next_box_id,
				"product_id": String(withdrawn.get("product_id", "")),
				"count": int(withdrawn.get("count", 0)),
			})
			next_box_id += 1
			return true
		QueuedAction.Type.PICKUP_EQUIPMENT_BOX:
			if has_package:
				return false
			if _free_carry_capacity() <= 0:
				return false
			var equipment_box := action.target as Node3D
			if equipment_box == null or not equipment_box.has_method("pickup_into"):
				return false
			var equipment_key := equipment_box.get_instance_id()
			if consumed_pickup_targets.has(equipment_key):
				return false
			consumed_pickup_targets.append(equipment_key)
			carried_placeables.append({
				"id": next_placeable_box_id,
				"order_id": int(equipment_box.get("order_id")),
				"placeable_type": String(equipment_box.get("placeable_type")),
				"item_id": String(equipment_box.get("item_id")),
				"label": String(equipment_box.get("delivery_label")),
			})
			next_placeable_box_id += 1
			return true
		QueuedAction.Type.TAKE_ORDER:
			if has_package or order_accepted:
				return false
			if action.order_snapshot.is_empty():
				return false
			active_order = action.order_snapshot.duplicate()
			order_accepted = true
			if action.target is Customer:
				delivery_customer = action.target as Customer
			return true
		QueuedAction.Type.COLLECT_SHELF:
			if has_package:
				return false
			var pid := action.product_id
			if pid == "" or ProductCatalog.is_package(pid):
				return false
			if action.quantity > _free_carry_capacity():
				return false
			inventory[pid] = int(inventory.get(pid, 0)) + action.quantity
			return true
		QueuedAction.Type.STOCK_SHELF:
			if has_package:
				return false
			var stock_id := action.product_id
			if action.stock_from_box_id >= 0:
				var box_index := _find_box_index(action.stock_from_box_id)
				if box_index < 0:
					return false
				var box: Dictionary = carried_boxes[box_index]
				if String(box.get("product_id", "")) != stock_id:
					return false
				var box_count := int(box.get("count", 0))
				if box_count < action.quantity:
					return false
				box_count -= action.quantity
				if box_count <= 0:
					carried_boxes.remove_at(box_index)
				else:
					box["count"] = box_count
					carried_boxes[box_index] = box
				return true
			var held := int(inventory.get(stock_id, 0))
			if held < action.quantity:
				return false
			inventory[stock_id] = held - action.quantity
			if inventory[stock_id] <= 0:
				inventory.erase(stock_id)
			return true
		QueuedAction.Type.PACK_ORDER:
			if has_package:
				if action.order_source != "online" and not awaiting_delivery:
					awaiting_delivery = true
				return true
			if awaiting_delivery:
				return false
			var order := action.order_snapshot
			if order.is_empty():
				order = active_order
			if order.is_empty():
				return false
			if not _inventory_fulfills_order(order):
				return false
			_consume_order(order)
			has_package = true
			active_order = {}
			if action.order_source == "online":
				awaiting_delivery = false
			else:
				awaiting_delivery = true
			return true
		QueuedAction.Type.DELIVER_ORDER:
			if not has_package or not awaiting_delivery:
				return false
			has_package = false
			awaiting_delivery = false
			order_accepted = false
			delivery_customer = null
			return true
		QueuedAction.Type.CLEAN_GARBAGE:
			if has_package:
				return false
			var garbage := action.target
			if garbage == null or not garbage.has_method("clean"):
				return false
			var clean_key := garbage.get_instance_id()
			if consumed_clean_targets.has(clean_key):
				return false
			consumed_clean_targets.append(clean_key)
			return true
	return false


func can_apply(action: QueuedAction, customer_queue: CustomerQueue) -> bool:
	var before := duplicate_state()
	if not apply(action):
		return false
	return _validate_real_world(action, before, customer_queue)


func _validate_real_world(
	action: QueuedAction,
	before: ProjectedState,
	customer_queue: CustomerQueue
) -> bool:
	if action.target != null and not is_instance_valid(action.target):
		return false
	match action.type:
		QueuedAction.Type.TAKE_ORDER:
			var customer := action.target as Customer
			return customer_queue != null and customer_queue.can_take_order(customer)
		QueuedAction.Type.COLLECT_SHELF:
			var shelf := action.target as ProductShelf
			if shelf == null or not shelf.can_take():
				return false
			if shelf.product_id != action.product_id and action.product_id != "":
				return false
			return shelf.count >= 1
		QueuedAction.Type.STOCK_SHELF:
			var shelf := action.target as ProductShelf
			return shelf != null and shelf.can_receive(action.product_id)
		QueuedAction.Type.PACK_ORDER:
			if customer_queue == null:
				return false
			if customer_queue.has_pending_delivery():
				return false
			# apply() already simulated consumption; check the post-pack state.
			if action.order_source == "online":
				return has_package and not awaiting_delivery
			return has_package and awaiting_delivery
		QueuedAction.Type.DELIVER_ORDER:
			var customer := action.target as Customer
			if customer_queue == null or customer == null:
				return false
			if customer_queue.can_fulfill_order(customer):
				return true
			return (
				before.has_package
				and before.awaiting_delivery
				and before.delivery_customer == customer
			)
		QueuedAction.Type.PICKUP_BOX:
			var box := action.target as DeliveryBox
			return box != null and box.count > 0
		QueuedAction.Type.CLEAN_GARBAGE:
			var garbage := action.target
			return (
				garbage != null
				and is_instance_valid(garbage)
				and garbage.is_in_group("floor_garbage")
			)
	return true


func can_collect_from_shelf(shelf: ProductShelf, amount: int) -> bool:
	if has_package:
		return false
	if shelf == null or not shelf.can_take():
		return false
	if amount < 1:
		return false
	return shelf.count >= amount and amount <= _free_carry_capacity()


func can_pack_order(order: Dictionary, customer_queue: CustomerQueue) -> bool:
	if has_package or awaiting_delivery:
		return false
	if order.is_empty():
		order = active_order
	if order.is_empty():
		return false
	if customer_queue != null and customer_queue.has_pending_delivery():
		return false
	return _inventory_fulfills_order(order)


func can_deliver_to(customer: Customer, customer_queue: CustomerQueue) -> bool:
	if not has_package:
		return false
	if customer_queue != null and customer_queue.can_fulfill_order(customer):
		return true
	return awaiting_delivery and delivery_customer == customer

func inventory_array() -> Array:
	var items: Array = []
	for product_id in inventory:
		for _i in inventory[product_id]:
			items.append(product_id)
	return items


func count_product(product_id: String) -> int:
	return int(inventory.get(product_id, 0))


func count_box_product(product_id: String) -> int:
	var total := 0
	for box in carried_boxes:
		if String(box.get("product_id", "")) == product_id:
			total += int(box.get("count", 0))
	return total


func _used_slots() -> int:
	var units := 0
	for product_id in inventory:
		units += int(inventory[product_id])
	return units + carried_boxes.size() + carried_placeables.size()


func _free_carry_capacity() -> int:
	return maxi(0, Worker.MAX_CARRIED_ENTRIES - _used_slots())


func _storage_projection_entry(storage: Node) -> Dictionary:
	var key := storage.get_instance_id()
	if storage_projection.has(key):
		return storage_projection[key]
	return {"stored": 0, "withdrawn": []}


func _projected_free_storage_slots(storage: Node) -> int:
	if storage == null or not storage.has_method("free_slots"):
		return 0
	var entry: Dictionary = _storage_projection_entry(storage)
	return maxi(0, int(storage.free_slots()) - int(entry.get("stored", 0)))


func _peek_storage_box(storage: Node, box_id: int) -> Dictionary:
	if storage == null or not storage.has_method("get_stored_boxes"):
		return {}
	var entry: Dictionary = _storage_projection_entry(storage)
	var withdrawn: Array = entry.get("withdrawn", [])
	if withdrawn.has(box_id):
		return {}
	for box in storage.get_stored_boxes():
		if int(box.get("id", -1)) == box_id:
			return box.duplicate()
	return {}


func _record_projected_storage_store(storage: Node) -> void:
	var key := storage.get_instance_id()
	var entry: Dictionary = _storage_projection_entry(storage).duplicate()
	entry["stored"] = int(entry.get("stored", 0)) + 1
	storage_projection[key] = entry


func _record_projected_storage_withdraw(storage: Node, box_id: int) -> void:
	var key := storage.get_instance_id()
	var entry: Dictionary = _storage_projection_entry(storage).duplicate()
	var withdrawn: Array = entry.get("withdrawn", []).duplicate()
	if not withdrawn.has(box_id):
		withdrawn.append(box_id)
	entry["withdrawn"] = withdrawn
	entry["stored"] = maxi(0, int(entry.get("stored", 0)) - 1)
	storage_projection[key] = entry


func _find_box_index(box_id: int) -> int:
	for i in range(carried_boxes.size()):
		if int(carried_boxes[i].get("id", -1)) == box_id:
			return i
	return -1


func _inventory_fulfills_order(order: Dictionary) -> bool:
	return ProductCatalog.inventory_fulfills_order(inventory_array(), order)


func _consume_order(order: Dictionary) -> void:
	for product_id in order:
		var need := int(order[product_id])
		var held := count_product(String(product_id))
		inventory[String(product_id)] = maxi(0, held - need)
		if inventory[String(product_id)] <= 0:
			inventory.erase(String(product_id))


static func after_actions(
	worker: Worker,
	customer_queue: CustomerQueue,
	actions: Array
) -> ProjectedState:
	var state := from_game(worker, customer_queue)
	for action in actions:
		if action is QueuedAction:
			state.apply(action)
	return state
