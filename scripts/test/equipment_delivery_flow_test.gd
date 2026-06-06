extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/equipment_delivery_flow_test.gd

const EquipmentCatalogScript = preload("res://scripts/gameplay/equipment_catalog.gd")
const EquipmentDeliveryBoxScript = preload("res://scripts/gameplay/equipment_delivery_box.gd")
const EquipmentOrderConfigScript = preload("res://scripts/gameplay/equipment_order_config.gd")
const EconomyManagerScript = preload("res://scripts/gameplay/economy_manager.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const IncomingDeliveryManagerScript = preload(
	"res://scripts/gameplay/incoming_delivery_manager.gd"
)
const LoadingDockScript = preload("res://scripts/warehouse/loading_dock.gd")
const ProductShelfScript = preload("res://scripts/warehouse/product_shelf.gd")
const StorageShelfScript = preload("res://scripts/warehouse/storage_shelf.gd")
const WarehousePlacementModeScript = preload(
	"res://scripts/warehouse/warehouse_placement_mode.gd"
)
const WorkerScene = preload("res://scenes/worker/worker.tscn")
const GridScript = preload("res://scripts/autoload/grid_service.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("delivery delay is a positive, short game-minute span", _test_delay_config())
	failed += _assert("truck arrival spawns equipment box", await _test_truck_spawns_box())
	failed += _assert("equipment box enters inventory", await _test_box_enters_inventory())
	failed += _assert("placement mode accepts shelf box", await _test_placement_begins())
	failed += _assert("placement mode accepts storage shelf box", await _test_storage_placement_begins())
	failed += _assert("valid shelf placement works", await _test_valid_placement())
	failed += _assert("blocked placement is rejected", await _test_blocked_placement())
	failed += _assert("outside warehouse placement is rejected", _test_outside_placement())
	failed += _assert("time advance triggers dock arrival", await _test_delayed_arrival())

	if failed == 0:
		print("equipment_delivery_flow_test: ALL PASSED")
		quit(0)
	else:
		push_error("equipment_delivery_flow_test: %d FAILED" % failed)
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
	if root.get_node_or_null("IncomingDeliveryManager") == null:
		var deliveries: Node = IncomingDeliveryManagerScript.new()
		deliveries.name = "IncomingDeliveryManager"
		root.add_child(deliveries)


func _clear_docks() -> void:
	for child in root.get_children():
		if child.is_in_group("loading_dock"):
			child.queue_free()
	await process_frame


func _make_dock() -> Node:
	_clear_docks()
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
	_clear_workers()
	var worker: Worker = WorkerScene.instantiate()
	worker.name = "Worker"
	root.add_child(worker)
	await process_frame
	return worker


func _make_placement_mode() -> Node:
	var mode: Node = WarehousePlacementModeScript.new()
	mode.name = "WarehousePlacementMode"
	root.add_child(mode)
	await process_frame
	return mode


func _make_delivery() -> Dictionary:
	return {
		"order_id": 7,
		"item_id": EquipmentCatalogScript.ITEM_SHELF,
		"label": "Shelf",
		"placeable_type": "shelf",
		"status": "at_dock",
	}


func _test_delay_config() -> bool:
	# Delivery is intentionally fast now; just assert it's a sane positive span.
	var delay := EquipmentOrderConfigScript.DELIVERY_DELAY_GAME_MINUTES
	return delay > 0.0 and delay <= 120.0


func _test_truck_spawns_box() -> bool:
	var dock := await _make_dock()
	dock.deliver_equipment_order(_make_delivery(), true)
	return dock.get_equipment_box_count() == 1


func _test_box_enters_inventory() -> bool:
	var dock := await _make_dock()
	var worker := await _make_worker()
	dock.deliver_equipment_order(_make_delivery(), true)
	var box: Node3D = dock.get_child(dock.get_child_count() - 1) as Node3D
	if box == null or not box.has_method("pickup_into"):
		return false
	if not box.pickup_into(worker):
		return false
	return worker.get_carried_placeables().size() == 1


func _test_placement_begins() -> bool:
	var worker := await _make_worker()
	var mode: Node = await _make_placement_mode()
	worker.add_placeable_box(9, "shelf", EquipmentCatalogScript.ITEM_SHELF, "Shelf")
	var stacks: Array = worker.get_inventory_stacks()
	var stack: Dictionary = stacks[stacks.size() - 1]
	return bool(stack.get("is_placeable_box", false)) and mode.begin_placement(stack)


func _test_storage_placement_begins() -> bool:
	for child in root.get_children():
		if child.is_in_group("warehouse_placement_mode"):
			child.queue_free()
	await process_frame
	var worker := await _make_worker()
	var mode: Node = await _make_placement_mode()
	worker.add_placeable_box(
		11,
		"storage_shelf",
		EquipmentCatalogScript.ITEM_STORAGE_SHELF,
		"Storage Shelf"
	)
	var stacks: Array = worker.get_inventory_stacks()
	var stack: Dictionary = stacks[stacks.size() - 1]
	if not bool(stack.get("is_placeable_box", false)):
		return false
	if not mode.begin_placement(stack):
		return false
	mode.set_preview_anchor(Vector2i(18, 14))
	if not mode.is_preview_valid():
		return false
	if not mode.apply_placement():
		return false
	var placed := false
	for node in root.get_tree().get_nodes_in_group("storage_shelves"):
		if node.get_anchor_cell() == Vector2i(18, 14):
			placed = node.get_script() == StorageShelfScript
			break
	return placed and worker.get_carried_placeables().is_empty()


func _test_valid_placement() -> bool:
	for child in root.get_children():
		if child.is_in_group("warehouse_placement_mode"):
			child.queue_free()
	await process_frame
	var shelves_parent := Node3D.new()
	shelves_parent.name = "WarehouseShelves"
	shelves_parent.add_to_group("warehouse_shelves")
	root.add_child(shelves_parent)
	var worker := await _make_worker()
	var mode: Node = await _make_placement_mode()
	worker.add_placeable_box(9, "shelf", EquipmentCatalogScript.ITEM_SHELF, "Shelf")
	var stacks: Array = worker.get_inventory_stacks()
	var stack: Dictionary = stacks[stacks.size() - 1]
	if not bool(stack.get("is_placeable_box", false)):
		return false
	if not mode.begin_placement(stack):
		return false
	mode.set_preview_anchor(Vector2i(19, 14))
	if not mode.is_preview_valid():
		return false
	if not mode.apply_placement():
		return false
	return worker.get_carried_placeables().is_empty()


func _test_blocked_placement() -> bool:
	var grid: WarehouseGrid = root.get_node("GridService")
	var blocker := Vector2i(16, 14)
	grid.block_cell(blocker)
	var shelf: ProductShelf = ProductShelfScript.new()
	root.add_child(shelf)
	shelf.setup(grid.cell_to_world(blocker), 0.0)
	return not grid.can_occupy_cells([blocker], [])


func _test_outside_placement() -> bool:
	var grid: WarehouseGrid = root.get_node("GridService")
	var outside := grid.warehouse_origin + Vector2i(-1, 0)
	return not grid.is_warehouse_cell(outside)


func _test_delayed_arrival() -> bool:
	var deliveries: Node = root.get_node("IncomingDeliveryManager")
	var economy: Node = root.get_node("EconomyManager")
	var time: Node = root.get_node("GameTimeManager")
	var dock := await _make_dock()
	deliveries.reset_for_new_game()
	economy.set_coins(100)
	time.set_time(1, 480)
	var result: Dictionary = deliveries.place_order(EquipmentCatalogScript.ITEM_SHELF)
	if not bool(result.get("ok", false)):
		return false
	if dock.get_equipment_box_count() != 0:
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
