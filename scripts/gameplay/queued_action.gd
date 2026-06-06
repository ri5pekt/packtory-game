class_name QueuedAction
extends RefCounted

## One planned worker step. Walk-to is bundled into interact actions for v1.

enum Type {
	GO_HERE,
	TAKE_ORDER,
	COLLECT_SHELF,
	STOCK_SHELF,
	PACK_ORDER,
	DELIVER_ORDER,
	PICKUP_BOX,
	PICKUP_EQUIPMENT_BOX,
	STORE_BOX_ON_STORAGE,
	WITHDRAW_BOX_FROM_STORAGE,
	CLEAN_GARBAGE,
}

var type: Type = Type.GO_HERE
var label: String = ""
var icon_id: String = "go_here"
var target: Node = null
var quantity: int = 1
var product_id: String = ""
var floor_position: Vector3 = Vector3.ZERO
var order_snapshot: Dictionary = {}
var order_source: String = ""
var stock_from_box_id: int = -1
var storage_box_id: int = -1


static func make_go_here(position: Vector3) -> QueuedAction:
	var a := QueuedAction.new()
	a.type = Type.GO_HERE
	a.label = "Go Here"
	a.icon_id = "go_here"
	a.floor_position = position
	return a


static func make_take_order(customer: Customer, order: Dictionary) -> QueuedAction:
	var a := QueuedAction.new()
	a.type = Type.TAKE_ORDER
	a.label = "Take Order"
	a.icon_id = "take_order"
	a.target = customer
	a.order_snapshot = order.duplicate()
	return a


static func make_collect(shelf: ProductShelf, amount: int) -> QueuedAction:
	var a := QueuedAction.new()
	a.type = Type.COLLECT_SHELF
	a.label = "Collect Item"
	a.icon_id = "take"
	a.target = shelf
	a.quantity = maxi(1, amount)
	a.product_id = shelf.product_id
	return a


static func make_stock(shelf: ProductShelf, pid: String, amount: int) -> QueuedAction:
	var a := QueuedAction.new()
	a.type = Type.STOCK_SHELF
	a.label = "Stock Shelf"
	a.icon_id = "put"
	a.target = shelf
	a.product_id = pid
	a.quantity = maxi(1, amount)
	return a


static func make_stock_from_box(
	shelf: ProductShelf,
	box_id: int,
	pid: String,
	amount: int
) -> QueuedAction:
	var a := make_stock(shelf, pid, amount)
	a.stock_from_box_id = box_id
	a.label = "Unpack Box"
	a.icon_id = "pickup"
	return a


static func make_pack(table: PackingTable, order: Dictionary) -> QueuedAction:
	var a := QueuedAction.new()
	a.type = Type.PACK_ORDER
	a.label = "Pack Order"
	a.icon_id = "pack_order"
	a.target = table
	a.order_snapshot = order.duplicate()
	return a


static func make_deliver(customer: Customer) -> QueuedAction:
	var a := QueuedAction.new()
	a.type = Type.DELIVER_ORDER
	a.label = "Deliver Parcel"
	a.icon_id = "fulfill_order"
	a.target = customer
	return a


static func make_pickup_box(box: DeliveryBox) -> QueuedAction:
	var a := QueuedAction.new()
	a.type = Type.PICKUP_BOX
	a.label = "Pick Up Box"
	a.icon_id = "pickup"
	a.target = box
	return a


static func make_store_box_on_storage(
	storage: Node3D,
	worker_box_id: int,
	product_id: String
) -> QueuedAction:
	var a := QueuedAction.new()
	a.type = Type.STORE_BOX_ON_STORAGE
	a.label = "Store Box"
	a.icon_id = "put"
	a.target = storage
	a.stock_from_box_id = worker_box_id
	a.product_id = product_id
	return a


static func make_withdraw_box_from_storage(storage: Node3D, storage_box_id: int) -> QueuedAction:
	var a := QueuedAction.new()
	a.type = Type.WITHDRAW_BOX_FROM_STORAGE
	a.label = "Take Box"
	a.icon_id = "take"
	a.target = storage
	a.storage_box_id = storage_box_id
	return a


static func make_clean_garbage(garbage: Node3D) -> QueuedAction:
	var a := QueuedAction.new()
	a.type = Type.CLEAN_GARBAGE
	a.label = "Clean"
	a.icon_id = "clean"
	a.target = garbage
	return a


static func make_pickup_equipment_box(box: Node3D) -> QueuedAction:
	var a := QueuedAction.new()
	a.type = Type.PICKUP_EQUIPMENT_BOX
	a.label = "Pick Up Equipment"
	a.icon_id = "pickup"
	a.target = box
	return a
