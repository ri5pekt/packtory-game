extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/save_load_test.gd

const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const DayEndManagerScript = preload("res://scripts/gameplay/day_end_manager.gd")
const DayStatsTrackerScript = preload("res://scripts/gameplay/day_stats_tracker.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")
const GameSessionScript = preload("res://scripts/gameplay/game_session.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const GarbageDropManagerScript = preload("res://scripts/gameplay/garbage_drop_manager.gd")
const IncomingDeliveryManagerScript = preload("res://scripts/gameplay/incoming_delivery_manager.gd")
const LoadingDockScript = preload("res://scripts/warehouse/loading_dock.gd")
const OutboundDeliveryVehicleScript = preload("res://scripts/warehouse/outbound_delivery_vehicle.gd")
const ReputationConfigScript = preload("res://scripts/gameplay/reputation_config.gd")
const ReputationManagerScript = preload("res://scripts/gameplay/reputation_manager.gd")
const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")
const SaveMigrationScript = preload("res://scripts/gameplay/save_migration.gd")
const ProgressionConfigScript = preload("res://scripts/gameplay/progression_config.gd")
const UnlockConfigScript = preload("res://scripts/gameplay/unlock_config.gd")
const MainMenuScript = preload("res://scripts/ui/main_menu.gd")
const WorkerScript = preload("res://scenes/worker/worker.tscn")
const WorkerHireManagerScript = preload("res://scripts/gameplay/worker_hire_manager.gd")
const ProductShelfScript = preload("res://scripts/warehouse/product_shelf.gd")
const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")

const TEST_SAVE_PATH := "user://packtory_test_save.json"


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var save := _ensure_save_manager()
	save.set_test_mode(true, TEST_SAVE_PATH)
	save.delete_save()

	var failed := 0
	failed += _assert("no save file initially", not save.has_save())
	failed += _assert("new game resets progression", _test_new_game_defaults(save))
	failed += _assert("write and read save file", _test_write_read_roundtrip(save))
	failed += _assert("continue prepares pending load", _test_continue_prepares_load(save))
	failed += _assert("worker state roundtrip", await _test_worker_roundtrip())
	failed += _assert("shelf stock roundtrip", await _test_shelf_roundtrip())
	failed += _assert("main menu hides continue without save", _test_menu_continue_hidden(save))
	failed += _assert("main menu shows continue with save", _test_menu_continue_visible(save))
	failed += _assert("v1 save migrates to v2", _test_v1_migration(save))
	failed += _assert("reputation and day stats roundtrip", _test_progression_extras(save))
	failed += _assert("economy day expenses restore without double charge", _test_day_expenses_restore(save))
	failed += _assert("customer queue restores active order", await _test_customer_queue_roundtrip())
	failed += _assert("garbage pieces restore", await _test_garbage_roundtrip())
	failed += _assert("outbound van route state roundtrip", await _test_outbound_van_roundtrip())
	failed += _assert("full mid-day collect apply restores world", await _test_full_midday_roundtrip(save))

	save.delete_save()
	if failed == 0:
		print("save_load_test: ALL PASSED")
		quit(0)
	else:
		push_error("save_load_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_save_manager() -> Node:
	_ensure_autoloads()
	var existing := root.get_node_or_null("SaveManager")
	if existing:
		return existing
	var save: Node = SaveManagerScript.new()
	save.name = "SaveManager"
	root.add_child(save)
	return save


func _ensure_autoloads() -> void:
	if root.get_node_or_null("EconomyManager") == null:
		var economy_script: Script = load("res://scripts/gameplay/economy_manager.gd") as Script
		var economy: Node = economy_script.new()
		economy.name = "EconomyManager"
		root.add_child(economy)
	if root.get_node_or_null("ProgressionManager") == null:
		var progression_script: Script = load("res://scripts/gameplay/progression_manager.gd") as Script
		var progression: Node = progression_script.new()
		progression.name = "ProgressionManager"
		root.add_child(progression)
	if root.get_node_or_null("UnlockManager") == null:
		var unlock_script: Script = load("res://scripts/gameplay/unlock_manager.gd") as Script
		var unlocks: Node = unlock_script.new()
		unlocks.name = "UnlockManager"
		root.add_child(unlocks)
	if root.get_node_or_null("GameTimeManager") == null:
		var game_time: Node = GameTimeManagerScript.new()
		game_time.name = "GameTimeManager"
		root.add_child(game_time)
	if root.get_node_or_null("GameSession") == null:
		var session: Node = GameSessionScript.new()
		session.name = "GameSession"
		root.add_child(session)
	if root.get_node_or_null("ReputationManager") == null:
		var reputation: Node = ReputationManagerScript.new()
		reputation.name = "ReputationManager"
		root.add_child(reputation)
	if root.get_node_or_null("DayEndManager") == null:
		var day_end: Node = DayEndManagerScript.new()
		day_end.name = "DayEndManager"
		root.add_child(day_end)
	if root.get_node_or_null("DayStatsTracker") == null:
		var tracker: Node = DayStatsTrackerScript.new()
		tracker.name = "DayStatsTracker"
		root.add_child(tracker)
	if root.get_node_or_null("GarbageDropManager") == null:
		var garbage: Node = GarbageDropManagerScript.new()
		garbage.name = "GarbageDropManager"
		root.add_child(garbage)
	if root.get_node_or_null("IncomingDeliveryManager") == null:
		var deliveries: Node = IncomingDeliveryManagerScript.new()
		deliveries.name = "IncomingDeliveryManager"
		root.add_child(deliveries)
	if root.get_node_or_null("WorkerHireManager") == null:
		var hire: Node = WorkerHireManagerScript.new()
		hire.name = "WorkerHireManager"
		root.add_child(hire)
	if root.get_node_or_null("DayEndFlow") == null:
		var flow_script: Script = load("res://scripts/gameplay/day_end_flow.gd") as Script
		var flow: Node = flow_script.new()
		flow.name = "DayEndFlow"
		root.add_child(flow)


func _test_new_game_defaults(save: Node) -> bool:
	save.prepare_new_game()
	return (
		save.get_coins() == EconomyConfigScript.STARTING_COINS
		and save.get_xp() == 0
		and save.get_level() == 0
		and save.get_day() == 1
		and save.get_game_minutes() == 480
		and save.get_unlocked_products().size() == UnlockConfigScript.starting_products().size()
		and not save.is_product_unlocked("smart_watch")
	)


func _test_write_read_roundtrip(save: Node) -> bool:
	save.set_coins(4321)
	var total_xp := ProgressionConfigScript.total_xp_for_level(3) + 25
	save.set_total_xp(total_xp)
	save.set_day(5)
	save.set_game_minutes(615)
	save.set_unlocked_products(["headphones", "mouse", "hair_dryer", "smart_watch"])
	var data: Dictionary = save.build_test_save(
		{
			"coins": 4321,
			"total_xp": total_xp,
			"xp": 25,
			"level": 3,
			"day": 5,
			"game_minutes": 615,
			"unlocked_products": ["headphones", "mouse", "hair_dryer", "smart_watch"],
		},
		{
			"id": "manager",
			"position": [13.0, 0.0, 16.0],
			"yaw": 180.0,
			"stacks": [{"id": "mouse", "count": 2}],
			"carried_boxes": [],
			"package_meta": {},
			"next_box_id": 1,
		},
		[
			{
				"type": "shelf",
				"cell": [14, 14],
				"yaw": 0.0,
				"product_id": "headphones",
				"count": 4,
			}
		]
	)
	data["session"] = {"is_day_started": true}
	data["dock"] = {
		"delivery_started": true,
		"queue_started": true,
		"boxes": [{"product_id": "mouse", "count": 3, "cell": [24, 15], "yaw": 90.0}],
	}
	if not save.write_save(data):
		return false
	if not save.has_save():
		return false
	save.prepare_new_game()
	if not save.prepare_continue_game():
		return false
	return (
		save.get_coins() == 4321
		and save.get_xp() == 25
		and save.get_level() == 3
		and save.get_total_xp() == total_xp
		and save.get_day() == 5
		and save.get_game_minutes() == 615
		and save.get_unlocked_products().has("smart_watch")
		and save.get_unlocked_products().has("headphones")
		and save.is_loading_save()
		and bool(save.get_pending_data().get("session", {}).get("is_day_started", false))
	)


func _test_continue_prepares_load(save: Node) -> bool:
	return save.is_loading_save() and not save.get_pending_data().is_empty()


func _test_worker_roundtrip() -> bool:
	_ensure_grid_service()
	var save := _ensure_save_manager()
	var worker: Worker = WorkerScript.instantiate()
	worker.name = "TestWorker"
	root.add_child(worker)
	await process_frame
	worker.add_products("mouse", 2)
	worker.add_delivery_box("headphones", 5)
	var exported := worker.export_save_state()
	worker.apply_save_state({
		"id": "manager",
		"position": [10.0, 0.0, 12.0],
		"yaw": 90.0,
		"stacks": [
			{"id": "hair_dryer", "count": 1},
			{"id": "package", "count": 1},
		],
		"carried_boxes": [{"id": 7, "product_id": "mouse", "count": 4}],
		"package_meta": {"source": "online", "order_number": 1001},
		"next_box_id": 8,
	})
	var stacks := worker.get_inventory_stacks()
	var ok := (
		worker.count_product("hair_dryer") == 1
		and worker.get_carried_boxes().size() == 1
		and int(worker.get_carried_boxes()[0].get("id", -1)) == 7
		and worker.is_online_package()
		and absf(worker.global_position.x - 10.0) < 0.01
		and not exported.is_empty()
		and stacks.size() >= 1
	)
	worker.queue_free()
	return ok


func _test_shelf_roundtrip() -> bool:
	_ensure_grid_service()
	var shelf: ProductShelf = ProductShelfScript.new()
	shelf.name = "TestShelf"
	root.add_child(shelf)
	await process_frame
	shelf.setup(Vector3(14.0, 0.0, 14.0), 0.0)
	shelf.stock_product("headphones", 3)
	shelf.clear_stock()
	shelf.stock_product("mouse", 2)
	return shelf.product_id == "mouse" and shelf.count == 2


func _test_menu_continue_hidden(save: Node) -> bool:
	save.delete_save()
	var menu: Control = MainMenuScript.new()
	root.add_child(menu)
	menu.ensure_built()
	menu._refresh_continue_button()
	var btn := menu.find_child("ContinueGameButton", true, false) as Button
	return btn != null and not btn.visible and btn.disabled


func _test_menu_continue_visible(save: Node) -> bool:
	var data: Dictionary = save.build_test_save({"coins": 100, "day": 2})
	save.write_save(data)
	var menu: Control = MainMenuScript.new()
	root.add_child(menu)
	menu.ensure_built()
	menu._refresh_continue_button()
	var btn := menu.find_child("ContinueGameButton", true, false) as Button
	return btn != null and btn.visible and not btn.disabled


func _ensure_grid_service() -> void:
	if root.get_node_or_null("GridService") != null:
		return
	var grid_script: Script = load("res://scripts/autoload/grid_service.gd") as Script
	var grid: Node = grid_script.new()
	grid.name = "GridService"
	root.add_child(grid)


func _ensure_spawn_parent() -> void:
	if root.get_node_or_null("WorkerSpawn") != null:
		return
	var spawn := Node3D.new()
	spawn.name = "WorkerSpawn"
	spawn.add_to_group("worker_spawn")
	root.add_child(spawn)


func _test_v1_migration(save: Node) -> bool:
	var v1 := {
		"version": 1,
		"progression": {
			"coins": 250,
			"total_xp": 40,
			"xp": 40,
			"level": 1,
			"day": 3,
			"game_minutes": 720,
			"unlocked_products": ["headphones", "mouse"],
		},
		"session": {"is_day_started": true},
		"placeables": [],
		"workers": [],
		"dock": {"delivery_started": false, "queue_started": false, "boxes": []},
		"outbound_van": {"loaded_packages": [], "capacity": 4},
		"customer_queue": {},
		"incoming_deliveries": {"pending": [], "next_order_id": 1},
	}
	var migrated: Dictionary = SaveMigrationScript.migrate(v1, 2)
	return (
		int(migrated.get("version", 0)) == 2
		and migrated.has("economy")
		and migrated.has("day_stats")
		and migrated.has("garbage")
		and bool(migrated.get("session", {}).get("time_running", false))
	)


func _test_progression_extras(save: Node) -> bool:
	save.prepare_new_game()
	save.set_reputation(88)
	var tracker := root.get_node("DayStatsTracker")
	tracker.begin_day_tracking()
	tracker.call("_on_order_fulfilled", {"source": "in_person"})
	var data: Dictionary = save.collect_from_scene(self)
	return (
		int(data.get("progression", {}).get("reputation", 0)) == 88
		and int(data.get("day_stats", {}).get("in_person_orders", 0)) == 1
	)


func _test_day_expenses_restore(save: Node) -> bool:
	save.prepare_new_game()
	var economy := root.get_node("EconomyManager")
	economy.set_coins(500)
	economy.charge_expense(25, "salary:test", economy.get_expense_category_salary(), {})
	var before: int = economy.get_coins()
	var data: Dictionary = save.collect_from_scene(self)
	save.prepare_new_game()
	save.write_save(data)
	save.prepare_continue_game()
	save.apply_to_scene(self)
	return (
		economy.get_coins() == before
		and economy.get_day_expenses().size() == 1
		and int(economy.get_day_expenses()[0].get("amount", 0)) == 25
	)


func _test_customer_queue_roundtrip() -> bool:
	_ensure_grid_service()
	_ensure_autoloads()
	var queue: Node3D = CustomerQueueScript.new()
	queue.name = "TestCustomerQueue"
	queue.add_to_group("customer_queue")
	root.add_child(queue)
	await process_frame
	queue.apply_save_state({
		"service_started": true,
		"active_order": {"headphones": 1},
		"order_source": "in_person",
		"online_order_number": 0,
		"active_customer_slot": 0,
		"delivery_customer_slot": -1,
		"next_spawn_at_minutes": 900.0,
		"use_game_time_spawn": true,
		"customers": [
			{
				"slot_index": 0,
				"model_path": "res://blender/assets/kenney_mini-characters/Models/GLB format/character-female-a.glb",
				"state": 1,
				"order": {"headphones": 1},
				"position": [16.0, 0.0, 18.0],
				"yaw": 0.0,
				"queue_wait_origin_set": true,
				"tracking_queue_wait": true,
				"queue_wait_started_day": 1,
				"queue_wait_started_minutes": 700.0,
			},
		],
	})
	await process_frame
	var ok: bool = (
		queue.get_customer_count() == 1
		and queue.get_active_order().get("headphones", 0) == 1
		and queue.get_active_customer() != null
	)
	queue.queue_free()
	await process_frame
	return ok


func _test_garbage_roundtrip() -> bool:
	_ensure_grid_service()
	_ensure_autoloads()
	var garbage_mgr := root.get_node("GarbageDropManager")
	garbage_mgr.spawn_garbage_at(Vector3(15.0, 0.0, 16.0))
	await process_frame
	var save := _ensure_save_manager()
	var data: Dictionary = save.collect_from_scene(self)
	garbage_mgr.clear_all_garbage()
	save.write_save(data)
	save.prepare_continue_game()
	save.apply_to_scene(self)
	await process_frame
	return garbage_mgr.get_garbage_count() == 1


func _test_outbound_van_roundtrip() -> bool:
	_ensure_grid_service()
	var van: Node3D = OutboundDeliveryVehicleScript.new()
	van.name = "TestVan"
	van.add_to_group("outbound_delivery_vehicles")
	root.add_child(van)
	await process_frame
	var grid := root.get_node("GridService") as WarehouseGrid
	van.setup(grid.cell_to_world(Vector2i(24, 16)), 90.0)
	van.load_test_package({"source": "online", "order_number": 42, "items": ["mouse"]})
	var exported: Dictionary = van.export_save_state()
	van.apply_save_state({
		"loaded_packages": [],
		"capacity": 4,
		"state": "on_route",
		"route_started_at": 700.0,
		"route_ends_at": 760.0,
		"packages_on_route": [{"source": "online", "order_number": 42}],
		"home_position": exported.get("home_position", [24.0, 0.0, 16.0]),
		"home_yaw": 90.0,
	})
	return van.is_on_route() and van.get_loaded_count() == 0


func _test_full_midday_roundtrip(save: Node) -> bool:
	_ensure_grid_service()
	_ensure_autoloads()
	_ensure_spawn_parent()
	for node in root.get_tree().get_nodes_in_group("customer_queue"):
		if is_instance_valid(node):
			node.queue_free()
	await process_frame
	save.prepare_new_game()
	var economy := root.get_node("EconomyManager")
	var game_time := root.get_node("GameTimeManager")
	var session := root.get_node("GameSession")
	var reputation := root.get_node("ReputationManager")
	var tracker := root.get_node("DayStatsTracker")
	var deliveries := root.get_node("IncomingDeliveryManager")
	economy.set_coins(777)
	save.set_total_xp(ProgressionConfigScript.total_xp_for_level(2) + 10)
	save.set_unlocked_products(["headphones", "mouse", "hair_dryer"])
	game_time.set_time(2, 690)
	game_time.set_running(false)
	session.acknowledge_day_start()
	tracker.begin_day_tracking()
	tracker.call("_on_order_fulfilled", {"source": "online"})
	deliveries.apply_save_state({
		"pending": [{
			"order_id": 9,
			"delivery_kind": "product",
			"product_id": "mouse",
			"quantity": 5,
			"status": "ordered",
			"deliver_at_minutes": 800.0,
		}],
		"next_order_id": 10,
	})
	var queue: Node3D = CustomerQueueScript.new()
	queue.name = "MiddayQueue"
	queue.add_to_group("customer_queue")
	root.add_child(queue)
	var dock: Node3D = LoadingDockScript.new()
	dock.name = "MiddayDock"
	root.add_child(dock)
	var shelf_parent := Node3D.new()
	shelf_parent.name = "WarehouseShelves"
	shelf_parent.add_to_group("warehouse_shelves")
	root.add_child(shelf_parent)
	var shelf: ProductShelf = ProductShelfScript.new()
	shelf_parent.add_child(shelf)
	await process_frame
	shelf.add_to_group("shelves")
	shelf.setup(Vector3(14.0, 0.0, 14.0), 0.0)
	shelf.stock_product("mouse", 6)
	queue.apply_save_state({
		"service_started": true,
		"active_order": {"mouse": 2},
		"order_source": "in_person",
		"customers": [],
		"use_game_time_spawn": true,
		"next_spawn_at_minutes": 710.0,
	})
	dock.apply_save_state({
		"queue_started": true,
		"boxes": [{
			"product_id": "headphones",
			"count": 4,
			"cell": [24, 15],
			"yaw": 90.0,
			"label_offset": [0, 0, 0],
		}],
		"equipment_boxes": [],
	})
	_hire_manager().hire_worker("helper_alex")
	await process_frame
	save.set_reputation(92)
	var expected_coins: int = economy.get_coins()
	var snapshot: Dictionary = save.collect_from_scene(self)
	if int(snapshot.get("progression", {}).get("reputation", -1)) != 92:
		push_error("collect reputation %d" % int(snapshot.get("progression", {}).get("reputation", -1)))
		return false
	if not save.write_save(snapshot):
		return false
	if not save.prepare_continue_game():
		return false
	for node in root.get_tree().get_nodes_in_group("customer_queue"):
		if node.name == "MiddayQueue":
			node.queue_free()
	for node in root.get_tree().get_nodes_in_group("loading_dock"):
		if node.name == "MiddayDock":
			node.queue_free()
	shelf_parent.queue_free()
	for worker in root.get_tree().get_nodes_in_group("workers"):
		if is_instance_valid(worker) and not worker.is_manager():
			worker.queue_free()
	await process_frame
	var queue2: Node3D = CustomerQueueScript.new()
	queue2.name = "MiddayQueue"
	queue2.add_to_group("customer_queue")
	root.add_child(queue2)
	var dock2: Node3D = LoadingDockScript.new()
	dock2.name = "MiddayDock"
	root.add_child(dock2)
	var shelf_parent2 := Node3D.new()
	shelf_parent2.name = "WarehouseShelves"
	shelf_parent2.add_to_group("warehouse_shelves")
	root.add_child(shelf_parent2)
	var shelf2: ProductShelf = ProductShelfScript.new()
	shelf_parent2.add_child(shelf2)
	await process_frame
	save.apply_to_scene(self)
	await process_frame
	var ok: bool = (
		save.get_coins() == expected_coins
		and save.get_level() == 2
		and save.get_day() == 2
		and save.get_game_minutes() == 690
		and reputation.get_reputation() == 92
		and save.is_product_unlocked("hair_dryer")
		and int(tracker.get_online_orders()) == 1
		and deliveries.get_pending_deliveries().size() == 1
		and queue2.get_active_order().get("mouse", 0) == 2
		and dock2.is_queue_started()
	)
	queue2.queue_free()
	dock2.queue_free()
	shelf_parent2.queue_free()
	return ok


func _hire_manager() -> Node:
	return root.get_node("WorkerHireManager")
