class_name WorkerActionExecutor
extends RefCounted

## Runs queued worker actions for autonomous workers.

const WalkInteractionScript = preload("res://scripts/shared/walk_interaction.gd")

const INVENTORY_FULL_MSG := "No more space in inventory."


static func execute(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
	if actor == null or action == null:
		on_done.call(false)
		return
	match action.type:
		QueuedAction.Type.PICKUP_BOX:
			_execute_pickup_box(actor, action, on_done)
		QueuedAction.Type.STORE_BOX_ON_STORAGE:
			_execute_store_box_on_storage(actor, action, on_done)
		QueuedAction.Type.WITHDRAW_BOX_FROM_STORAGE:
			_execute_withdraw_box_from_storage(actor, action, on_done)
		QueuedAction.Type.STOCK_SHELF:
			_execute_stock(actor, action, on_done)
		QueuedAction.Type.CLEAN_GARBAGE:
			_execute_clean_garbage(actor, action, on_done)
		_:
			on_done.call(false)


static func _execute_pickup_box(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
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
			if actor.is_packing() or actor.has_package() or actor.is_inventory_full():
				on_done.call(false)
				return
			on_done.call(box.pickup_into(actor))
	)


static func _execute_store_box_on_storage(
	actor: Worker,
	action: QueuedAction,
	on_done: Callable
) -> void:
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
			on_done.call(actor.deposit_box_to_storage(action.stock_from_box_id, shelf))
	)


static func _execute_withdraw_box_from_storage(
	actor: Worker,
	action: QueuedAction,
	on_done: Callable
) -> void:
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
			on_done.call(actor.withdraw_box_to_inventory(shelf, action.storage_box_id))
	)


static func _execute_stock(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
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


static func _execute_clean_garbage(actor: Worker, action: QueuedAction, on_done: Callable) -> void:
	var garbage := action.target as Node3D
	if garbage == null or not garbage.is_in_group("floor_garbage"):
		on_done.call(false)
		return
	var approach: Vector3 = (
		garbage.get_approach_position()
		if garbage.has_method("get_approach_position")
		else garbage.global_position
	)
	var face_target: Vector3 = (
		garbage.get_face_target()
		if garbage.has_method("get_face_target")
		else garbage.global_position
	)
	WalkInteractionScript.walk_face_then(
		actor,
		approach,
		face_target,
		func(ok: bool) -> void:
			if not ok or not is_instance_valid(garbage):
				on_done.call(false)
				return
			if actor.is_packing():
				on_done.call(false)
				return
			if garbage.has_method("clean"):
				garbage.clean()
			on_done.call(true)
	)


static func _perform_shelf_stock_box(
	actor: Worker,
	shelf: ProductShelf,
	box_id: int,
	quantity: int
) -> int:
	if actor.is_packing() or actor.has_package():
		return 0
	actor.face_world(shelf.get_face_target())
	return actor.stock_from_box_id(box_id, shelf, maxi(1, quantity))


static func _perform_shelf_stock(
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
