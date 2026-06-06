extends Node

## Applies level-based unlocks — products enter the catalog only after the player acknowledges the popup.

signal unlocks_changed
signal unlock_popup_requested(payload: Dictionary)

const UnlockConfigScript = preload("res://scripts/gameplay/unlock_config.gd")
const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")

var _unlocked_products: Array[String] = []
var _popup_queue: Array[Dictionary] = []
var _queued_levels: Array[int] = []
var _showing_popup := false


func _ready() -> void:
	call_deferred("_bind_progression")


func reset_for_new_game() -> void:
	_unlocked_products = UnlockConfigScript.starting_products()
	_popup_queue.clear()
	_queued_levels.clear()
	_showing_popup = false
	unlocks_changed.emit()


func get_unlocked_products() -> Array[String]:
	return _unlocked_products.duplicate()


func is_product_unlocked(product_id: String) -> bool:
	return _unlocked_products.has(product_id)


func get_orderable_product_ids() -> Array[String]:
	return _unlocked_products.duplicate()


func restore_unlocked_products(product_ids: Array) -> void:
	_unlocked_products.clear()
	if product_ids.is_empty():
		_unlocked_products = UnlockConfigScript.starting_products()
	else:
		for product_id in product_ids:
			var id := String(product_id)
			if ProductCatalogScript.has_id(id) and not ProductCatalogScript.is_package(id):
				_unlocked_products.append(id)
	if _unlocked_products.is_empty():
		_unlocked_products = UnlockConfigScript.starting_products()
	unlocks_changed.emit()


func sync_unlock_popups_for_level(current_level: int) -> void:
	for level in range(1, current_level + 1):
		if _level_has_pending_products(level):
			_enqueue_unlock_popup(level)


func on_levels_gained(from_level: int, to_level: int, _count: int) -> void:
	for level in range(from_level + 1, to_level + 1):
		if UnlockConfigScript.has_unlocks_at_level(level):
			_enqueue_unlock_popup(level)


func get_pending_popup_count() -> int:
	return _popup_queue.size() + (1 if _showing_popup else 0)


func is_popup_showing() -> bool:
	return _showing_popup


func acknowledge_unlock_popup(level: int) -> void:
	_apply_unlocks_for_level(level)
	_queued_levels.erase(level)
	_showing_popup = false
	unlocks_changed.emit()
	_emit_next_popup_if_needed()


func has_generic_level_up(level: int) -> bool:
	return not UnlockConfigScript.has_unlocks_at_level(level)


func _bind_progression() -> void:
	var progression := get_node_or_null("/root/ProgressionManager")
	if progression == null:
		return
	if not progression.levels_gained.is_connected(on_levels_gained):
		progression.levels_gained.connect(on_levels_gained)


func _enqueue_unlock_popup(level: int) -> void:
	if _queued_levels.has(level):
		return
	var products := _pending_products_for_level(level)
	if products.is_empty():
		return
	_queued_levels.append(level)
	_popup_queue.append({
		"level": level,
		"products": products,
		"unlocks": UnlockConfigScript.unlocks_for_level(level),
	})
	if not _showing_popup:
		_emit_next_popup_if_needed()


func _emit_next_popup_if_needed() -> void:
	if _showing_popup or _popup_queue.is_empty():
		return
	_showing_popup = true
	unlock_popup_requested.emit(_popup_queue.pop_front())


func _level_has_pending_products(level: int) -> bool:
	return not _pending_products_for_level(level).is_empty()


func _pending_products_for_level(level: int) -> Array[String]:
	var pending: Array[String] = []
	for product_id in UnlockConfigScript.product_unlocks_for_level(level):
		if not _unlocked_products.has(product_id):
			pending.append(product_id)
	return pending


func _apply_unlocks_for_level(level: int) -> void:
	var unlocks := UnlockConfigScript.unlocks_for_level(level)
	for product_id in unlocks.get("products", []):
		var id := String(product_id)
		if ProductCatalogScript.has_id(id) and not _unlocked_products.has(id):
			_unlocked_products.append(id)
