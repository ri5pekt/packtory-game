extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/product_reorder_test.gd

const ComputerInterfaceUIScript = preload("res://scripts/ui/computer_interface_ui.gd")
const ComputerReorderProductsScreenScript = preload(
	"res://scripts/ui/computer_reorder_products_screen.gd"
)
const ComputerSectionsConfigScript = preload("res://scripts/gameplay/computer_sections_config.gd")
const DeliveryBoxScript = preload("res://scripts/gameplay/delivery_box.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")
const EconomyManagerScript = preload("res://scripts/gameplay/economy_manager.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const IncomingDeliveryManagerScript = preload(
	"res://scripts/gameplay/incoming_delivery_manager.gd"
)
const LoadingDockScript = preload("res://scripts/warehouse/loading_dock.gd")
const ProductReorderConfigScript = preload("res://scripts/gameplay/product_reorder_config.gd")
const UnlockManagerScript = preload("res://scripts/gameplay/unlock_manager.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const WorkerScene = preload("res://scenes/worker/worker.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("reorder section is implemented", _test_section_implemented())
	failed += _assert("logistics fee only for now", _test_fee_is_logistics_only())
	failed += _assert("reorder deducts logistics fee", _test_reorder_deducts_fee())
	failed += _assert("reorder creates pending delivery", _test_reorder_creates_pending())
	failed += _assert("insufficient coins block reorder", _test_insufficient_coins_blocked())
	failed += _assert("computer navigates to reorder products", _test_computer_navigation())
	failed += _assert("reorder screen lists unlocked products", _test_reorder_screen_catalog())
	failed += _assert("instant delivery spawns product box", await _test_instant_box_spawn())
	failed += _assert("product box has correct contents", await _test_box_contents())
	failed += _assert("pickup completes pending order", await _test_pickup_completes_order())
	failed += _assert("time advance triggers product arrival", await _test_delayed_arrival())
	failed += _assert("pending product deliveries persist in save", _test_pending_persist_in_save())

	if failed == 0:
		print("product_reorder_test: ALL PASSED")
		quit(0)
	else:
		push_error("product_reorder_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_autoloads() -> void:
	if root.get_node_or_null("GridService") == null:
		var grid: WarehouseGrid = GridScript.new()
		grid.name = "GridService"
		root.add_child(grid)
	if root.get_node_or_null("EconomyManager") == null:
		var economy: Node = EconomyManagerScript.new()
		economy.name = "EconomyManager"
		root.add_child(economy)
	if root.get_node_or_null("GameTimeManager") == null:
		var time: Node = GameTimeManagerScript.new()
		time.name = "GameTimeManager"
		root.add_child(time)
	if root.get_node_or_null("UnlockManager") == null:
		var unlocks: Node = UnlockManagerScript.new()
		unlocks.name = "UnlockManager"
		root.add_child(unlocks)
	if root.get_node_or_null("IncomingDeliveryManager") == null:
		var deliveries: Node = IncomingDeliveryManagerScript.new()
		deliveries.name = "IncomingDeliveryManager"
		root.add_child(deliveries)


func _economy() -> Node:
	return root.get_node("EconomyManager")


func _deliveries() -> Node:
	return root.get_node("IncomingDeliveryManager")


func _reset_state() -> void:
	_deliveries().reset_for_new_game()
	_economy().set_coins(100)


func _clear_docks() -> void:
	for child in root.get_children():
		if child.is_in_group("loading_dock"):
			child.queue_free()
	await process_frame


func _make_dock() -> Node:
	await _clear_docks()
	var dock: Node = LoadingDockScript.new()
	dock.name = "LoadingDock"
	root.add_child(dock)
	await process_frame
	return dock


func _clear_workers() -> void:
	for node in root.get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(node):
			node.queue_free()
	await process_frame


func _make_worker() -> Worker:
	await _clear_workers()
	var worker: Worker = WorkerScene.instantiate()
	worker.name = "Worker"
	root.add_child(worker)
	await process_frame
	return worker


func _test_section_implemented() -> bool:
	return not ComputerSectionsConfigScript.is_placeholder(
		ComputerSectionsConfigScript.SECTION_REORDER_PRODUCTS
	)


func _test_fee_is_logistics_only() -> bool:
	var fee := ProductReorderConfigScript.order_total("mouse", 6)
	return (
		fee == EconomyConfigScript.DELIVERY_FEE_PLACEHOLDER
		and ProductReorderConfigScript.unit_cost("mouse") == 0
	)


func _test_reorder_deducts_fee() -> bool:
	_reset_state()
	var before: int = _economy().get_coins()
	var result: Dictionary = _deliveries().place_product_order("mouse", 6)
	var fee: int = ProductReorderConfigScript.order_total("mouse", 6)
	return (
		bool(result.get("ok", false))
		and _economy().get_coins() == before - fee
	)


func _test_reorder_creates_pending() -> bool:
	_reset_state()
	var result: Dictionary = _deliveries().place_product_order("mouse", 4)
	if not bool(result.get("ok", false)):
		return false
	var delivery: Dictionary = result.get("delivery", {})
	var pending: Array = _deliveries().get_pending_deliveries_of_kind(
		IncomingDeliveryManagerScript.DELIVERY_KIND_PRODUCT
	)
	return (
		pending.size() == 1
		and String(delivery.get("delivery_kind", "")) == IncomingDeliveryManagerScript.DELIVERY_KIND_PRODUCT
		and String(delivery.get("product_id", "")) == "mouse"
		and int(delivery.get("quantity", 0)) == 4
		and int(delivery.get("logistics_fee", 0)) == EconomyConfigScript.DELIVERY_FEE_PLACEHOLDER
		and int(delivery.get("product_cost", 0)) == 0
		and String(delivery.get("status", "")) == "ordered"
		and float(delivery.get("deliver_at_minutes", 0.0)) > 0.0
	)


func _test_insufficient_coins_blocked() -> bool:
	_reset_state()
	_economy().set_coins(0)
	var result: Dictionary = _deliveries().place_product_order("mouse", 6)
	return (
		not bool(result.get("ok", false))
		and String(result.get("reason", "")) == "insufficient_coins"
		and _deliveries().get_pending_count() == 0
		and _economy().get_coins() == 0
	)


func _test_computer_navigation() -> bool:
	var ui: Control = ComputerInterfaceUIScript.new()
	ui.set_size(Vector2(720.0, 520.0))
	root.add_child(ui)
	ui.open()
	ui.navigate_to(ComputerSectionsConfigScript.SECTION_REORDER_PRODUCTS)
	var screen: VBoxContainer = ui.get_reorder_products_screen()
	var ok: bool = (
		ui.get_active_screen() == ComputerSectionsConfigScript.SECTION_REORDER_PRODUCTS
		and screen != null
		and screen.has_method("get_catalog_card_count")
		and screen.get_catalog_card_count() >= 1
	)
	ui.close()
	return ok


func _test_reorder_screen_catalog() -> bool:
	_reset_state()
	var screen: VBoxContainer = ComputerReorderProductsScreenScript.new()
	root.add_child(screen)
	screen.ensure_ready()
	return screen.get_catalog_card_count() >= 3


func _make_product_delivery() -> Dictionary:
	return {
		"order_id": 11,
		"delivery_kind": IncomingDeliveryManagerScript.DELIVERY_KIND_PRODUCT,
		"product_id": "mouse",
		"quantity": 6,
		"label": "Computer Mouse (×6)",
		"status": "at_dock",
	}


func _test_instant_box_spawn() -> bool:
	var dock := await _make_dock()
	dock.deliver_product_order(_make_product_delivery(), true)
	return dock.get_reorder_box_count() == 1


func _test_box_contents() -> bool:
	var dock := await _make_dock()
	dock.deliver_product_order(_make_product_delivery(), true)
	for child in dock.get_children():
		if child is DeliveryBox and child.reorder_order_id == 11:
			return child.product_id == "mouse" and child.count == 6
	return false


func _test_pickup_completes_order() -> bool:
	_reset_state()
	_deliveries().place_product_order("mouse", 6)
	var pending: Array = _deliveries().get_pending_deliveries()
	if pending.is_empty():
		return false
	var delivery: Dictionary = pending[0]
	delivery["status"] = "at_dock"
	var dock := await _make_dock()
	dock.deliver_product_order(delivery, true)
	var worker := await _make_worker()
	for child in dock.get_children():
		if child is DeliveryBox and child.reorder_order_id > 0:
			if not child.pickup_into(worker):
				return false
			break
	return _deliveries().get_pending_count() == 0 and worker.get_carried_boxes().size() == 1


func _test_delayed_arrival() -> bool:
	var deliveries: Node = _deliveries()
	var economy: Node = _economy()
	var time: Node = root.get_node("GameTimeManager")
	var dock := await _make_dock()
	deliveries.reset_for_new_game()
	economy.set_coins(100)
	time.set_time(1, 480)
	var result: Dictionary = deliveries.place_product_order("mouse", 6)
	if not bool(result.get("ok", false)):
		return false
	if dock.get_reorder_box_count() != 0:
		return false
	var pending: Array = deliveries.get_pending_deliveries()
	var delivery: Dictionary = pending[0]
	var deliver_at: float = float(delivery.get("deliver_at_minutes", 0.0))
	time.advance_by_game_minutes(deliver_at - float(time.get_precise_minutes()) + 1.0)
	deliveries.process_due_deliveries()
	await process_frame
	pending = deliveries.get_pending_deliveries()
	if pending.is_empty():
		return false
	delivery = pending[0]
	return String(delivery.get("status", "")) == "at_dock"


func _test_pending_persist_in_save() -> bool:
	_reset_state()
	_deliveries().place_product_order("mouse", 6)
	var exported: Dictionary = _deliveries().export_save_state()
	_deliveries().reset_for_new_game()
	_deliveries().apply_save_state(exported)
	var pending: Array = _deliveries().get_pending_deliveries_of_kind(
		IncomingDeliveryManagerScript.DELIVERY_KIND_PRODUCT
	)
	if pending.is_empty():
		return false
	var entry: Dictionary = pending[0]
	return String(entry.get("product_id", "")) == "mouse"
