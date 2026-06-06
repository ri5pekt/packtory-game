extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/equipment_order_test.gd

const ComputerSectionsConfigScript = preload("res://scripts/gameplay/computer_sections_config.gd")
const EquipmentCatalogScript = preload("res://scripts/gameplay/equipment_catalog.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")

const COMPUTER_INTERFACE_UI_SCRIPT := "res://scripts/ui/computer_interface_ui.gd"

const ECONOMY_MANAGER_SCRIPT := "res://scripts/gameplay/economy_manager.gd"
const INCOMING_DELIVERY_MANAGER_SCRIPT := "res://scripts/gameplay/incoming_delivery_manager.gd"
const ORDER_EQUIPMENT_SCREEN_SCRIPT := "res://scripts/ui/computer_order_equipment_screen.gd"
const SAVE_MANAGER_SCRIPT := "res://scripts/gameplay/save_manager.gd"


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("catalog includes shelf item", _test_catalog_has_shelf())
	failed += _assert("catalog includes storage shelf item", _test_catalog_has_storage_shelf())
	failed += _assert("order shelf deducts coins", _test_order_shelf_deducts_coins())
	failed += _assert("order shelf creates pending delivery", _test_order_creates_pending())
	failed += _assert("insufficient coins block order", _test_insufficient_coins_blocked())
	failed += _assert("batch order deducts combined cost", _test_batch_order_deducts_coins())
	failed += _assert("computer navigates to order equipment", _test_computer_navigation())
	failed += _assert(
		"order equipment catalog scroll is visible",
		await _test_order_equipment_catalog_visible()
	)
	failed += _assert("equipment screen places shelf order", _test_equipment_screen_order())
	failed += _assert(
		"equipment screen reports insufficient coins",
		_test_equipment_screen_insufficient_feedback()
	)
	failed += _assert("pending deliveries persist in save", _test_pending_persist_in_save())

	if failed == 0:
		print("equipment_order_test: ALL PASSED")
		quit(0)
	else:
		push_error("equipment_order_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_autoloads() -> void:
	if root.get_node_or_null("EconomyManager") == null:
		var economy: Node = load(ECONOMY_MANAGER_SCRIPT).new()
		economy.name = "EconomyManager"
		root.add_child(economy)
	if root.get_node_or_null("IncomingDeliveryManager") == null:
		var deliveries: Node = load(INCOMING_DELIVERY_MANAGER_SCRIPT).new()
		deliveries.name = "IncomingDeliveryManager"
		root.add_child(deliveries)
	if root.get_node_or_null("SaveManager") == null:
		var save: Node = load(SAVE_MANAGER_SCRIPT).new()
		save.name = "SaveManager"
		root.add_child(save)


func _economy() -> Node:
	return root.get_node("EconomyManager")


func _deliveries() -> Node:
	return root.get_node("IncomingDeliveryManager")


func _reset_state() -> void:
	_save().prepare_new_game()
	_deliveries().reset_for_new_game()


func _save() -> Node:
	return root.get_node("SaveManager")


func _test_catalog_has_shelf() -> bool:
	var item: Dictionary = EquipmentCatalogScript.get_item(EquipmentCatalogScript.ITEM_SHELF)
	return (
		not item.is_empty()
		and String(item.get("label", "")) == "Shelf"
		and int(item.get("cost", 0)) == EconomyConfigScript.WAREHOUSE_PURCHASE_PLACEHOLDER
		and String(item.get("category", "")) == EquipmentCatalogScript.CATEGORY_SHELVES
	)


func _test_catalog_has_storage_shelf() -> bool:
	var item: Dictionary = EquipmentCatalogScript.get_item(EquipmentCatalogScript.ITEM_STORAGE_SHELF)
	return (
		not item.is_empty()
		and String(item.get("label", "")) == "Storage Shelf"
		and String(item.get("placeable_type", "")) == "storage_shelf"
		and int(item.get("cost", 0)) == EconomyConfigScript.WAREHOUSE_PURCHASE_PLACEHOLDER
		and String(item.get("category", "")) == EquipmentCatalogScript.CATEGORY_SHELVES
	)


func _test_order_shelf_deducts_coins() -> bool:
	_reset_state()
	_economy().set_coins(100)
	var before: int = _economy().get_coins()
	var result: Dictionary = _deliveries().place_order(EquipmentCatalogScript.ITEM_SHELF)
	var cost: int = EquipmentCatalogScript.get_cost(EquipmentCatalogScript.ITEM_SHELF)
	return (
		bool(result.get("ok", false))
		and _economy().get_coins() == before - cost
	)


func _test_order_creates_pending() -> bool:
	_reset_state()
	_economy().set_coins(100)
	var result: Dictionary = _deliveries().place_order(EquipmentCatalogScript.ITEM_SHELF)
	if not bool(result.get("ok", false)):
		return false
	var delivery: Dictionary = result.get("delivery", {})
	var pending: Array = _deliveries().get_pending_deliveries()
	return (
		_deliveries().has_pending_deliveries()
		and pending.size() == 1
		and String(delivery.get("item_id", "")) == EquipmentCatalogScript.ITEM_SHELF
		and String(delivery.get("label", "")) == "Shelf"
		and String(delivery.get("status", "")) == "ordered"
		and float(delivery.get("deliver_at_minutes", 0.0)) > 0.0
		and int(delivery.get("order_id", 0)) == 1
	)


func _test_insufficient_coins_blocked() -> bool:
	_reset_state()
	_economy().set_coins(10)
	var result: Dictionary = _deliveries().place_order(EquipmentCatalogScript.ITEM_SHELF)
	return (
		not bool(result.get("ok", false))
		and String(result.get("reason", "")) == "insufficient_coins"
		and _deliveries().get_pending_count() == 0
		and _economy().get_coins() == 10
	)


func _test_batch_order_deducts_coins() -> bool:
	_reset_state()
	_economy().set_coins(200)
	var before: int = _economy().get_coins()
	var ids: Array = [
		EquipmentCatalogScript.ITEM_SHELF,
		EquipmentCatalogScript.ITEM_STORAGE_SHELF,
	]
	var result: Dictionary = _deliveries().place_equipment_orders(ids)
	var total := EquipmentCatalogScript.batch_order_total(ids)
	return (
		bool(result.get("ok", false))
		and _economy().get_coins() == before - total
		and _deliveries().get_pending_count() == 2
	)


func _test_computer_navigation() -> bool:
	var ui: Control = load(COMPUTER_INTERFACE_UI_SCRIPT).new()
	ui.set_size(Vector2(720.0, 520.0))
	root.add_child(ui)
	ui.open()
	ui.navigate_to(ComputerSectionsConfigScript.SECTION_ORDER_EQUIPMENT)
	var screen: VBoxContainer = ui.get_order_equipment_screen()
	var ok: bool = (
		ui.get_active_screen() == ComputerSectionsConfigScript.SECTION_ORDER_EQUIPMENT
		and screen != null
		and screen.has_method("get_catalog_card_count")
		and screen.get_catalog_card_count() >= 2
	)
	ui.close()
	return ok


func _test_order_equipment_catalog_visible() -> bool:
	var ui: Control = load(COMPUTER_INTERFACE_UI_SCRIPT).new()
	ui.set_size(Vector2(720.0, 520.0))
	root.add_child(ui)
	ui.open()
	ui.navigate_to(ComputerSectionsConfigScript.SECTION_ORDER_EQUIPMENT)
	await process_frame
	await process_frame
	var screen: VBoxContainer = ui.get_order_equipment_screen()
	if screen == null:
		ui.close()
		return false
	var scroll := screen.get_node_or_null("Scroll") as ScrollContainer
	if scroll == null:
		for child in screen.get_children():
			if child is ScrollContainer:
				scroll = child as ScrollContainer
				break
	var ok: bool = (
		screen.get_catalog_card_count() >= 2
		and scroll != null
		and scroll.size.y > 40.0
	)
	ui.close()
	return ok


func _test_equipment_screen_order() -> bool:
	_reset_state()
	_economy().set_coins(80)
	var screen: VBoxContainer = load(ORDER_EQUIPMENT_SCREEN_SCRIPT).new()
	root.add_child(screen)
	screen.ensure_ready()
	var result: Dictionary = _deliveries().place_order(EquipmentCatalogScript.ITEM_SHELF)
	screen.refresh()
	return bool(result.get("ok", false)) and screen.get_pending_card_count() >= 1


func _test_equipment_screen_insufficient_feedback() -> bool:
	_reset_state()
	_economy().set_coins(0)
	var screen: VBoxContainer = load(ORDER_EQUIPMENT_SCREEN_SCRIPT).new()
	root.add_child(screen)
	screen.ensure_ready()
	screen._item_checkboxes[EquipmentCatalogScript.ITEM_SHELF].button_pressed = true
	screen._submit_order()
	var status: String = screen.get_status_text()
	return (
		status.contains("Not enough coins")
		and status.contains("need %d" % EconomyConfigScript.WAREHOUSE_PURCHASE_PLACEHOLDER)
		and status.contains("you have 0")
	)


func _test_pending_persist_in_save() -> bool:
	_reset_state()
	_economy().set_coins(100)
	_deliveries().place_order(EquipmentCatalogScript.ITEM_SHELF)
	var exported: Dictionary = _deliveries().export_save_state()
	_deliveries().reset_for_new_game()
	_deliveries().apply_save_state(exported)
	var pending: Array = _deliveries().get_pending_deliveries()
	if pending.is_empty():
		return false
	var entry: Dictionary = pending[0]
	return String(entry.get("item_id", "")) == EquipmentCatalogScript.ITEM_SHELF
