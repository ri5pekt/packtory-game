extends Node

## Incoming delivery pipeline for equipment orders and product restock reorders.

signal pending_deliveries_changed(pending: Array)
signal order_placed(delivery: Dictionary)
signal delivery_arrived(delivery: Dictionary)

const EquipmentCatalogScript = preload("res://scripts/gameplay/equipment_catalog.gd")
const EquipmentOrderConfigScript = preload("res://scripts/gameplay/equipment_order_config.gd")
const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")
const ProductReorderConfigScript = preload("res://scripts/gameplay/product_reorder_config.gd")

const STATUS_ORDERED := "ordered"
const STATUS_AT_DOCK := "at_dock"
const DELIVERY_KIND_EQUIPMENT := "equipment"
const DELIVERY_KIND_PRODUCT := "product"

var _pending_deliveries: Array[Dictionary] = []
var _next_order_id := 1


func _ready() -> void:
	add_to_group("incoming_delivery_manager")
	call_deferred("_bind_game_time")


func reset_for_new_game() -> void:
	_pending_deliveries.clear()
	_next_order_id = 1
	pending_deliveries_changed.emit(get_pending_deliveries())


func get_pending_deliveries() -> Array:
	return _pending_deliveries.duplicate(true)


func get_pending_deliveries_of_kind(delivery_kind: String) -> Array:
	var filtered: Array = []
	for delivery in _pending_deliveries:
		if _delivery_kind(delivery) == delivery_kind:
			filtered.append(delivery.duplicate(true))
	return filtered


func has_pending_deliveries() -> bool:
	return not _pending_deliveries.is_empty()


func get_pending_count() -> int:
	return _pending_deliveries.size()


func can_afford(item_id: String) -> bool:
	var item := EquipmentCatalogScript.get_item(item_id)
	if item.is_empty():
		return false
	return _get_economy().get_coins() >= int(item.get("cost", 0))


func can_afford_product_order(product_id: String, quantity: int) -> bool:
	if not _is_reorderable_product(product_id):
		return false
	var economy := _get_economy()
	if economy == null:
		return false
	return economy.get_coins() >= ProductReorderConfigScript.order_total(product_id, quantity)


func place_order(item_id: String) -> Dictionary:
	return place_equipment_orders([item_id])


func place_equipment_orders(item_ids: Array) -> Dictionary:
	if item_ids.is_empty():
		return {"ok": false, "reason": "nothing_selected"}

	var normalized: Array[String] = []
	for raw in item_ids:
		var item_id := String(raw)
		var item := EquipmentCatalogScript.get_item(item_id)
		if item.is_empty():
			return {"ok": false, "reason": "unknown_item"}
		normalized.append(item_id)

	var total := EquipmentCatalogScript.batch_order_total(normalized)
	var economy := _get_economy()
	if economy == null:
		return {"ok": false, "reason": "no_economy"}
	if not economy.try_spend(total, "equipment_order_batch:x%d" % normalized.size()):
		return {"ok": false, "reason": "insufficient_coins"}

	var created: Array[Dictionary] = []
	for item_id in normalized:
		var item := EquipmentCatalogScript.get_item(item_id)
		var cost := int(item.get("cost", 0))
		var delivery := _build_equipment_delivery(item, cost)
		_pending_deliveries.append(delivery)
		created.append(delivery)
		order_placed.emit(delivery.duplicate(true))

	pending_deliveries_changed.emit(get_pending_deliveries())
	_check_due_deliveries()
	return {"ok": true, "deliveries": created, "delivery": created[0]}


func place_product_order(product_id: String, quantity: int) -> Dictionary:
	return place_product_orders([{"product_id": product_id, "quantity": quantity}])


func place_product_orders(lines: Array) -> Dictionary:
	if lines.is_empty():
		return {"ok": false, "reason": "nothing_selected"}

	var normalized: Array[Dictionary] = []
	for line in lines:
		if not line is Dictionary:
			continue
		var product_id := String(line.get("product_id", ""))
		var qty := ProductReorderConfigScript.clamp_quantity(int(line.get("quantity", 0)))
		if not _is_reorderable_product(product_id):
			return {"ok": false, "reason": "unknown_product"}
		normalized.append({"product_id": product_id, "quantity": qty})

	if normalized.is_empty():
		return {"ok": false, "reason": "nothing_selected"}

	var logistics_fee := ProductReorderConfigScript.logistics_fee()
	var product_cost_total := 0
	for line in normalized:
		product_cost_total += (
			ProductReorderConfigScript.unit_cost(String(line.get("product_id", "")))
			* int(line.get("quantity", 0))
		)
	var total := logistics_fee + product_cost_total

	var economy := _get_economy()
	if economy == null:
		return {"ok": false, "reason": "no_economy"}
	if not economy.try_spend(total, "product_reorder_batch:x%d" % normalized.size()):
		return {"ok": false, "reason": "insufficient_coins"}

	var created: Array[Dictionary] = []
	for i in range(normalized.size()):
		var line: Dictionary = normalized[i]
		var product_id := String(line.get("product_id", ""))
		var qty := int(line.get("quantity", 0))
		var line_logistics := logistics_fee if i == 0 else 0
		var line_product_cost := ProductReorderConfigScript.unit_cost(product_id) * qty
		var delivery := _build_product_delivery(
			product_id,
			qty,
			line_logistics,
			line_product_cost,
			line_logistics + line_product_cost
		)
		_pending_deliveries.append(delivery)
		created.append(delivery)
		order_placed.emit(delivery.duplicate(true))

	pending_deliveries_changed.emit(get_pending_deliveries())
	_check_due_deliveries()
	return {"ok": true, "deliveries": created, "delivery": created[0]}


func complete_order(order_id: int) -> bool:
	for i in range(_pending_deliveries.size()):
		if int(_pending_deliveries[i].get("order_id", 0)) == order_id:
			_pending_deliveries.remove_at(i)
			pending_deliveries_changed.emit(get_pending_deliveries())
			return true
	return false


func export_save_state() -> Dictionary:
	return {
		"pending": _pending_deliveries.duplicate(true),
		"next_order_id": _next_order_id,
	}


func apply_save_state(data: Dictionary) -> void:
	_pending_deliveries.clear()
	for entry in data.get("pending", []):
		if entry is Dictionary:
			_pending_deliveries.append(entry.duplicate(true))
	_next_order_id = maxi(1, int(data.get("next_order_id", 1)))
	pending_deliveries_changed.emit(get_pending_deliveries())
	for delivery in _pending_deliveries:
		if String(delivery.get("status", "")) == STATUS_AT_DOCK:
			_spawn_dock_delivery(delivery)


func _build_equipment_delivery(item: Dictionary, cost: int) -> Dictionary:
	var deliver_at := _scheduled_delivery_minutes()
	var delivery := {
		"order_id": _next_order_id,
		"delivery_kind": DELIVERY_KIND_EQUIPMENT,
		"item_id": String(item.get("id", "")),
		"label": String(item.get("label", "")),
		"category": String(item.get("category", "")),
		"delivery_type": String(item.get("delivery_type", "")),
		"placeable_type": String(item.get("placeable_type", "")),
		"cost": cost,
		"status": STATUS_ORDERED,
		"deliver_at_minutes": deliver_at,
	}
	_next_order_id += 1
	return delivery


func _build_product_delivery(
	product_id: String,
	quantity: int,
	logistics_fee: int,
	product_cost: int,
	total_cost: int
) -> Dictionary:
	var deliver_at := _scheduled_delivery_minutes()
	var delivery := {
		"order_id": _next_order_id,
		"delivery_kind": DELIVERY_KIND_PRODUCT,
		"product_id": product_id,
		"quantity": quantity,
		"label": "%s (×%d)" % [ProductCatalogScript.display_name(product_id), quantity],
		"logistics_fee": logistics_fee,
		"product_cost": product_cost,
		"cost": total_cost,
		"status": STATUS_ORDERED,
		"deliver_at_minutes": deliver_at,
	}
	_next_order_id += 1
	return delivery


func _scheduled_delivery_minutes() -> float:
	var game_time := _get_game_time()
	var now := float(game_time.get_precise_minutes()) if game_time else 0.0
	return now + EquipmentOrderConfigScript.DELIVERY_DELAY_GAME_MINUTES


func _bind_game_time() -> void:
	var game_time := _get_game_time()
	if game_time == null:
		return
	if game_time.has_signal("minute_advanced"):
		if not game_time.minute_advanced.is_connected(_on_minute_advanced):
			game_time.minute_advanced.connect(_on_minute_advanced)
	if game_time.has_signal("time_changed"):
		if not game_time.time_changed.is_connected(_on_time_changed):
			game_time.time_changed.connect(_on_time_changed)


func _on_minute_advanced(_minutes: int, _day: int) -> void:
	_check_due_deliveries()


func _on_time_changed(_minutes: int, _day: int) -> void:
	_check_due_deliveries()


func _check_due_deliveries() -> void:
	var game_time := _get_game_time()
	if game_time == null:
		return
	var now := float(game_time.get_precise_minutes())
	for delivery in _pending_deliveries:
		if String(delivery.get("status", "")) != STATUS_ORDERED:
			continue
		if now < float(delivery.get("deliver_at_minutes", 0.0)):
			continue
		_arrive_delivery(delivery)


func _arrive_delivery(delivery: Dictionary) -> void:
	delivery["status"] = STATUS_AT_DOCK
	pending_deliveries_changed.emit(get_pending_deliveries())
	delivery_arrived.emit(delivery.duplicate(true))
	_spawn_dock_delivery(delivery)


func _spawn_dock_delivery(delivery: Dictionary) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var dock := tree.get_first_node_in_group("loading_dock")
	if dock == null:
		return
	if _delivery_kind(delivery) == DELIVERY_KIND_PRODUCT:
		if dock.has_method("deliver_product_order"):
			dock.deliver_product_order(delivery, false)
	elif dock.has_method("deliver_equipment_order"):
		dock.deliver_equipment_order(delivery, false)


func process_due_deliveries() -> void:
	_check_due_deliveries()


func force_arrive_order(order_id: int, instant: bool = true) -> bool:
	for delivery in _pending_deliveries:
		if int(delivery.get("order_id", 0)) != order_id:
			continue
		if String(delivery.get("status", "")) == STATUS_AT_DOCK:
			return true
		delivery["status"] = STATUS_AT_DOCK
		pending_deliveries_changed.emit(get_pending_deliveries())
		delivery_arrived.emit(delivery.duplicate(true))
		var tree := get_tree()
		if tree == null:
			return true
		var dock := tree.get_first_node_in_group("loading_dock")
		if dock == null:
			return true
		if _delivery_kind(delivery) == DELIVERY_KIND_PRODUCT:
			if dock.has_method("deliver_product_order"):
				dock.deliver_product_order(delivery, instant)
		elif dock.has_method("deliver_equipment_order"):
			dock.deliver_equipment_order(delivery, instant)
		return true
	return false


func _delivery_kind(delivery: Dictionary) -> String:
	return String(delivery.get("delivery_kind", DELIVERY_KIND_EQUIPMENT))


func _is_reorderable_product(product_id: String) -> bool:
	if not ProductCatalogScript.has_id(product_id) or ProductCatalogScript.is_package(product_id):
		return false
	var unlocks := _get_unlocks()
	if unlocks != null and unlocks.has_method("is_product_unlocked"):
		return unlocks.is_product_unlocked(product_id)
	return ProductCatalogScript.orderable_product_ids().has(product_id)


func _get_economy() -> Node:
	return get_node_or_null("/root/EconomyManager")


func _get_game_time() -> Node:
	return get_node_or_null("/root/GameTimeManager")


func _get_unlocks() -> Node:
	return get_node_or_null("/root/UnlockManager")
