class_name WorkerStoragePlanner
extends RefCounted

## Picks the next storage-task action for a worker (simple greedy rules, no optimization).

const WorkerStorageConfigScript = preload("res://scripts/gameplay/worker_storage_config.gd")


static func plan_next(worker: Worker, tree: SceneTree, pending: Array) -> QueuedAction:
	if worker == null or tree == null:
		return null
	if worker.is_packing() or worker.has_package():
		return null
	var state := ProjectedState.after_actions(worker, null, pending)

	var stock_from_box := _plan_stock_carried_boxes(worker, tree, state)
	if stock_from_box != null:
		return stock_from_box

	var store_box := _plan_store_carried_boxes(worker, tree, state)
	if store_box != null:
		return store_box

	var pickup := _plan_pickup_delivery_box(worker, tree, state)
	if pickup != null:
		return pickup

	return _plan_withdraw_for_shelves(worker, tree, state)


static func _plan_stock_carried_boxes(
	worker: Worker,
	tree: SceneTree,
	state: ProjectedState
) -> QueuedAction:
	for box in state.carried_boxes:
		var box_id := int(box.get("id", -1))
		var product_id := String(box.get("product_id", ""))
		var box_count := int(box.get("count", 0))
		if box_id < 0 or product_id == "" or box_count <= 0:
			continue
		for shelf in tree.get_nodes_in_group("shelves"):
			if not shelf is ProductShelf:
				continue
			if not _shelf_needs_product(shelf as ProductShelf, product_id):
				continue
			var qty := mini(box_count, (shelf as ProductShelf).free_space())
			if qty <= 0:
				continue
			var action := QueuedAction.make_stock_from_box(shelf, box_id, product_id, qty)
			if state.can_apply(action, null):
				return action
	return null


static func _plan_store_carried_boxes(
	worker: Worker,
	tree: SceneTree,
	state: ProjectedState
) -> QueuedAction:
	if state.carried_boxes.is_empty():
		return null
	for storage in tree.get_nodes_in_group("storage_shelves"):
		if not storage.has_method("can_store_box") or not storage.can_store_box():
			continue
		var box: Dictionary = state.carried_boxes[0]
		var box_id := int(box.get("id", -1))
		var product_id := String(box.get("product_id", ""))
		if box_id < 0 or product_id == "":
			continue
		var action := QueuedAction.make_store_box_on_storage(storage, box_id, product_id)
		if state.can_apply(action, null):
			return action
	return null


static func _plan_pickup_delivery_box(
	_worker: Worker,
	tree: SceneTree,
	state: ProjectedState
) -> QueuedAction:
	if not state.carried_boxes.is_empty() or state.has_package:
		return null
	for box in tree.get_nodes_in_group("delivery_boxes"):
		if not box is DeliveryBox:
			continue
		var delivery := box as DeliveryBox
		if delivery.count <= 0:
			continue
		var action := QueuedAction.make_pickup_box(delivery)
		if state.can_apply(action, null):
			return action
	return null


static func _plan_withdraw_for_shelves(
	_worker: Worker,
	tree: SceneTree,
	state: ProjectedState
) -> QueuedAction:
	if not state.carried_boxes.is_empty() or state.has_package:
		return null
	for shelf in _shelves_needing_restock(tree):
		var product_id := _product_id_for_restock(shelf)
		if product_id == "":
			continue
		var match := _find_storage_box(tree, product_id)
		if match.is_empty():
			continue
		var action := QueuedAction.make_withdraw_box_from_storage(
			match.get("storage"),
			int(match.get("box_id", -1))
		)
		if state.can_apply(action, null):
			return action
	return null


static func _shelves_needing_restock(tree: SceneTree) -> Array:
	var needy: Array = []
	for shelf in tree.get_nodes_in_group("shelves"):
		if not shelf is ProductShelf:
			continue
		if _shelf_needs_restock(shelf as ProductShelf):
			needy.append(shelf)
	needy.sort_custom(func(a: ProductShelf, b: ProductShelf) -> bool:
		return a.count < b.count
	)
	return needy


static func _shelf_needs_restock(shelf: ProductShelf) -> bool:
	return shelf.count <= WorkerStorageConfigScript.LOW_STOCK_THRESHOLD


static func _shelf_needs_product(shelf: ProductShelf, product_id: String) -> bool:
	if product_id == "" or not shelf.can_receive(product_id):
		return false
	if shelf.count == 0:
		return true
	return shelf.product_id == product_id and shelf.count <= WorkerStorageConfigScript.LOW_STOCK_THRESHOLD


static func _product_id_for_restock(shelf: ProductShelf) -> String:
	if shelf.count > 0:
		return shelf.product_id
	for storage in shelf.get_tree().get_nodes_in_group("storage_shelves"):
		if not storage.has_method("get_stored_boxes"):
			continue
		for box in storage.get_stored_boxes():
			var product_id := String(box.get("product_id", ""))
			if product_id != "" and shelf.can_receive(product_id):
				return product_id
	return ""


static func _find_storage_box(tree: SceneTree, product_id: String) -> Dictionary:
	for storage in tree.get_nodes_in_group("storage_shelves"):
		if not storage.has_method("get_stored_boxes"):
			continue
		for box in storage.get_stored_boxes():
			if String(box.get("product_id", "")) != product_id:
				continue
			return {
				"storage": storage,
				"box_id": int(box.get("id", -1)),
			}
	return {}


static func shelf_needs_restock(shelf: ProductShelf) -> bool:
	return _shelf_needs_restock(shelf)
