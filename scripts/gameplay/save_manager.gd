extends Node

## Cross-platform save/load using JSON in user:// (works on desktop, Android, iOS).

signal progression_changed
signal save_completed
signal load_completed

const SaveMigrationScript = preload("res://scripts/gameplay/save_migration.gd")

const SAVE_VERSION := 2
const DEFAULT_SAVE_PATH := "user://packtory_save.json"

const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")
const DeliveryBoxScript = preload("res://scripts/gameplay/delivery_box.gd")
const ProductShelfScript = preload("res://scripts/warehouse/product_shelf.gd")
const StorageShelfScript = preload("res://scripts/warehouse/storage_shelf.gd")
const PackingTableScript = preload("res://scripts/warehouse/packing_table.gd")
const ReceptionTableScript = preload("res://scripts/warehouse/reception_table.gd")
const ComputerWorkstationScript = preload("res://scripts/warehouse/computer_workstation.gd")
const OutboundDeliveryVehicleScript = preload(
	"res://scripts/warehouse/outbound_delivery_vehicle.gd"
)
const ProgressionConfigScript = preload("res://scripts/gameplay/progression_config.gd")
const ReputationConfigScript = preload("res://scripts/gameplay/reputation_config.gd")
const UnlockConfigScript = preload("res://scripts/gameplay/unlock_config.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")

var _save_path := DEFAULT_SAVE_PATH
var _load_pending := false
var _pending_data: Dictionary = {}
var _test_mode := false

var _coins := 0
var _xp := 0
var _level := 0
var _day := 1
var _game_minutes := GameTimeConfigScript.DAY_START_MINUTES
var _unlocked_products: Array[String] = []


func _ready() -> void:
	_reset_unlocked_products_defaults()


func set_test_mode(enabled: bool, save_path: String = "user://packtory_test_save.json") -> void:
	_test_mode = enabled
	_save_path = save_path if enabled else DEFAULT_SAVE_PATH


func get_save_path() -> String:
	return _save_path


func has_save() -> bool:
	return FileAccess.file_exists(_save_path)


func delete_save() -> void:
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	_load_pending = false
	_pending_data = {}


func prepare_new_game() -> void:
	_load_pending = false
	_pending_data = {}
	reset_progression_to_defaults()


func prepare_continue_game() -> bool:
	if not load_save_file():
		return false
	_load_pending = true
	_apply_progression_from_dict(_pending_data.get("progression", {}))
	return true


func is_loading_save() -> bool:
	return _load_pending and not _pending_data.is_empty()


func get_pending_data() -> Dictionary:
	return _pending_data.duplicate(true)


func reset_progression_to_defaults() -> void:
	_sync_coins_from_economy_reset()
	_sync_day_end_from_reset()
	_sync_worker_tasks_from_reset()
	_sync_garbage_from_reset()
	_sync_progression_from_reset()
	_sync_reputation_from_reset()
	_sync_unlocks_from_reset()
	_sync_game_time_from_reset()
	_sync_incoming_deliveries_reset()
	_reset_unlocked_products_defaults()
	progression_changed.emit()


func get_coins() -> int:
	return _get_economy().get_coins() if _get_economy() else _coins


func set_coins(value: int) -> void:
	var economy := _get_economy()
	if economy:
		economy.set_coins(value)
	else:
		_coins = maxi(0, value)
	progression_changed.emit()


func get_xp() -> int:
	return _get_progression().get_xp() if _get_progression() else _xp


func set_xp(value: int) -> void:
	var progression := _get_progression()
	if progression:
		var total := ProgressionConfigScript.total_xp_for_level(progression.get_level()) + maxi(0, value)
		progression.set_total_xp(total)
	else:
		_xp = maxi(0, value)
	progression_changed.emit()


func get_level() -> int:
	return _get_progression().get_level() if _get_progression() else _level


func set_level(value: int) -> void:
	var progression := _get_progression()
	if progression:
		progression.set_total_xp(ProgressionConfigScript.total_xp_for_level(maxi(0, value)))
	else:
		_level = maxi(0, value)
	progression_changed.emit()


func get_total_xp() -> int:
	return _get_progression().get_total_xp() if _get_progression() else _xp


func set_total_xp(value: int) -> void:
	var progression := _get_progression()
	if progression:
		progression.set_total_xp(value)
	else:
		_xp = maxi(0, value)
		_level = ProgressionConfigScript.level_from_total_xp(_xp)
	progression_changed.emit()


func get_day() -> int:
	return _get_game_time().get_day() if _get_game_time() else _day


func set_day(value: int) -> void:
	var game_time := _get_game_time()
	if game_time:
		game_time.set_day(value)
	else:
		_day = maxi(1, value)
	progression_changed.emit()


func get_game_minutes() -> int:
	return _get_game_time().get_game_minutes() if _get_game_time() else _game_minutes


func set_game_minutes(value: int) -> void:
	var game_time := _get_game_time()
	if game_time:
		game_time.set_game_minutes(value)
	else:
		_game_minutes = GameTimeConfigScript.clamp_minutes_int(value)
	progression_changed.emit()


func get_unlocked_products() -> Array[String]:
	return _get_unlocks().get_unlocked_products() if _get_unlocks() else _unlocked_products.duplicate()


func set_unlocked_products(product_ids: Array) -> void:
	var unlocks := _get_unlocks()
	if unlocks:
		unlocks.restore_unlocked_products(product_ids)
	else:
		_restore_unlocked_products_local(product_ids)
	progression_changed.emit()


func is_product_unlocked(product_id: String) -> bool:
	return _get_unlocks().is_product_unlocked(product_id) if _get_unlocks() else _unlocked_products.has(product_id)


func save_current_scene(tree: SceneTree) -> bool:
	var data := collect_from_scene(tree)
	return write_save(data)


func write_save(data: Dictionary) -> bool:
	data["version"] = SAVE_VERSION
	data["meta"] = {
		"saved_at_unix": Time.get_unix_time_from_system(),
		"platform": OS.get_name(),
	}
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to write %s" % _save_path)
		return false
	file.store_string(json)
	file.close()
	save_completed.emit()
	return true


func load_save_file() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to read %s" % _save_path)
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: invalid save JSON")
		return false
	var version := int(parsed.get("version", 0))
	if version > SAVE_VERSION:
		push_error("SaveManager: save version %d is newer than supported %d" % [version, SAVE_VERSION])
		return false
	_pending_data = SaveMigrationScript.migrate(parsed, SAVE_VERSION)
	if version != SAVE_VERSION:
		push_warning("SaveManager: migrated save from v%d to v%d" % [version, SAVE_VERSION])
	load_completed.emit()
	return true


func apply_to_scene(tree: SceneTree) -> void:
	if not is_loading_save():
		return
	_apply_progression_from_dict(_pending_data.get("progression", {}))
	_apply_session(tree, _pending_data.get("session", {}))
	_apply_placeables(tree, _pending_data.get("placeables", []))
	_apply_workers(tree, _pending_data.get("workers", []))
	_apply_dock(tree, _pending_data.get("dock", {}))
	_apply_outbound_van(tree, _pending_data.get("outbound_van", {}))
	_apply_customer_queue(tree, _pending_data.get("customer_queue", {}))
	_apply_incoming_deliveries(_pending_data.get("incoming_deliveries", {}))
	_apply_economy(_pending_data.get("economy", {}))
	_apply_day_end(_pending_data.get("day_end", {}))
	_apply_day_stats(_pending_data.get("day_stats", {}))
	_apply_garbage(_pending_data.get("garbage", {}))
	_apply_game_time_runtime(_pending_data.get("game_time", {}), _pending_data.get("session", {}))
	_reset_day_end_flow()
	_sync_hud(tree)
	_load_pending = false
	load_completed.emit()


func collect_from_scene(tree: SceneTree) -> Dictionary:
	var root := tree.root
	return {
		"version": SAVE_VERSION,
		"progression": _collect_progression(),
		"session": _collect_session(),
		"game_time": _collect_game_time_runtime(),
		"economy": _collect_economy(),
		"day_end": _collect_day_end(),
		"day_stats": _collect_day_stats(),
		"garbage": _collect_garbage(),
		"placeables": _collect_placeables(root),
		"workers": _collect_workers(root),
		"dock": _collect_dock(root),
		"outbound_van": _collect_outbound_van(root),
		"customer_queue": _collect_customer_queue(root),
		"incoming_deliveries": _collect_incoming_deliveries(),
	}


func build_test_save(
	progression: Dictionary = {},
	worker_state: Dictionary = {},
	shelf_states: Array = []
) -> Dictionary:
	var data := _empty_save_template()
	if not progression.is_empty():
		data["progression"] = progression
	if not worker_state.is_empty():
		data["workers"] = [worker_state]
	if not shelf_states.is_empty():
		data["placeables"] = shelf_states
	return data


# ── collection ────────────────────────────────────────────────────────────────

func _collect_progression() -> Dictionary:
	return {
		"coins": get_coins(),
		"total_xp": get_total_xp(),
		"xp": get_xp(),
		"level": get_level(),
		"day": get_day(),
		"game_minutes": get_game_minutes(),
		"reputation": get_reputation(),
		"unlocked_products": get_unlocked_products(),
	}


func _collect_session() -> Dictionary:
	var session := get_node_or_null("/root/GameSession")
	var game_time := _get_game_time()
	var day_started: bool = session.is_gameplay_active() if session else false
	var time_running: bool = game_time.is_running() if game_time else false
	return {
		"is_day_started": day_started,
		"time_running": time_running and day_started,
	}


func _collect_game_time_runtime() -> Dictionary:
	var game_time := _get_game_time()
	if game_time == null:
		return {"running": false}
	return {
		"day": game_time.get_day(),
		"game_minutes": game_time.get_game_minutes(),
		"running": game_time.is_running(),
	}


func _collect_economy() -> Dictionary:
	var economy := _get_economy()
	return {
		"day_expenses": economy.get_day_expenses() if economy else [],
	}


func _collect_day_end() -> Dictionary:
	var day_end := _get_day_end()
	if day_end and day_end.has_method("export_save_state"):
		return day_end.export_save_state()
	return {"payroll_settled_day": -1, "last_checked_minute": -1, "last_summary": {}}


func _collect_day_stats() -> Dictionary:
	var tracker := _get_day_stats()
	if tracker and tracker.has_method("export_save_state"):
		return tracker.export_save_state()
	return {}


func _collect_garbage() -> Dictionary:
	var garbage := _get_garbage_drop_manager()
	if garbage and garbage.has_method("export_save_state"):
		return garbage.export_save_state()
	return {"pieces": []}


func _collect_placeables(root: Node) -> Array:
	var entries: Array = []
	for shelf in root.get_tree().get_nodes_in_group("shelves"):
		if not shelf.has_method("get_anchor_cell"):
			continue
		entries.append({
			"type": "shelf",
			"cell": vec2i_to_array(shelf.get_anchor_cell()),
			"yaw": shelf.get_placement_yaw(),
			"product_id": String(shelf.product_id),
			"count": int(shelf.count),
		})
	for storage in root.get_tree().get_nodes_in_group("storage_shelves"):
		if not storage.has_method("get_anchor_cell"):
			continue
		var storage_entry := {
			"type": "storage_shelf",
			"cell": vec2i_to_array(storage.get_anchor_cell()),
			"yaw": storage.get_placement_yaw(),
		}
		if storage.has_method("export_boxes_state"):
			storage_entry["boxes"] = storage.export_boxes_state()
		if storage.has_method("get_next_box_id"):
			storage_entry["next_box_id"] = storage.get_next_box_id()
		entries.append(storage_entry)
	for node in root.get_tree().get_nodes_in_group("warehouse_placeables"):
		if node.is_in_group("shelves") or node.is_in_group("storage_shelves"):
			continue
		var entry := _placeable_entry_from_node(node)
		if not entry.is_empty():
			entries.append(entry)
	for van in root.get_tree().get_nodes_in_group("outbound_delivery_vehicles"):
		if van.has_method("get_anchor_cell"):
			continue
		entries.append({
			"type": "outbound_van",
			"cell": vec2i_to_array(_world_to_cell(root, van.global_position)),
			"yaw": van.rotation_degrees.y,
		})
	return entries


func _placeable_entry_from_node(node: Node) -> Dictionary:
	if node is ProductShelf:
		return {}
	var type_name := ""
	if node.get_script() == PackingTableScript:
		type_name = "packing_table"
	elif node.get_script() == ReceptionTableScript:
		type_name = "reception_table"
	elif node.get_script() == ComputerWorkstationScript:
		type_name = "computer_workstation"
	elif node.has_method("get_placeable_label"):
		type_name = String(node.get_placeable_label()).to_lower().replace(" ", "_")
	else:
		return {}
	return {
		"type": type_name,
		"cell": vec2i_to_array(node.get_anchor_cell()),
		"yaw": node.get_placement_yaw(),
	}


func _collect_workers(root: Node) -> Array:
	var entries: Array = []
	for worker in root.get_tree().get_nodes_in_group("workers"):
		if worker.has_method("export_save_state"):
			entries.append(worker.export_save_state())
	return entries


func _collect_dock(root: Node) -> Dictionary:
	var dock := root.get_tree().get_first_node_in_group("loading_dock")
	if dock and dock.has_method("export_save_state"):
		return dock.export_save_state()
	var boxes: Array = []
	for box in root.get_tree().get_nodes_in_group("delivery_boxes"):
		if not is_instance_valid(box):
			continue
		boxes.append({
			"product_id": String(box.product_id),
			"count": int(box.count),
			"cell": vec2i_to_array(_world_to_cell(root, box.global_position)),
			"yaw": box.rotation_degrees.y,
		})
	return {
		"delivery_started": dock != null,
		"queue_started": dock.is_queue_started() if dock and dock.has_method("is_queue_started") else false,
		"boxes": boxes,
		"equipment_boxes": [],
	}


func _collect_outbound_van(root: Node) -> Dictionary:
	var van := root.get_tree().get_first_node_in_group("outbound_delivery_vehicles")
	if van == null:
		return {"loaded_packages": [], "capacity": 4, "state": "idle"}
	if van.has_method("export_save_state"):
		return van.export_save_state()
	if van.has_method("get_loaded_packages"):
		return {
			"loaded_packages": van.get_loaded_packages(),
			"capacity": van.get_capacity(),
			"state": "idle",
		}
	return {"loaded_packages": [], "capacity": 4, "state": "idle"}


func _collect_customer_queue(root: Node) -> Dictionary:
	var queue := root.get_tree().get_first_node_in_group("customer_queue")
	if queue == null or not queue.has_method("export_save_state"):
		return {}
	return queue.export_save_state()


# ── apply ─────────────────────────────────────────────────────────────────────

func _apply_progression_from_dict(data: Dictionary) -> void:
	var coins := int(data.get("coins", get_coins()))
	var economy := _get_economy()
	if economy:
		economy.set_coins(coins)
	else:
		_coins = maxi(0, coins)
	var progression := _get_progression()
	if progression:
		if data.has("total_xp"):
			progression.set_total_xp(int(data.get("total_xp", 0)))
		else:
			progression.set_total_xp(
				ProgressionConfigScript.total_xp_from_legacy_save(
					int(data.get("level", ProgressionConfigScript.STARTING_LEVEL)),
					int(data.get("xp", 0))
				)
			)
		_xp = progression.get_xp()
		_level = progression.get_level()
	else:
		if data.has("total_xp"):
			_xp = maxi(0, int(data.get("total_xp", 0)))
			_level = ProgressionConfigScript.level_from_total_xp(_xp)
		else:
			_xp = int(data.get("xp", _xp))
			_level = maxi(0, int(data.get("level", _level)))
	var day := maxi(1, int(data.get("day", _day)))
	var minutes := GameTimeConfigScript.clamp_minutes_int(int(data.get("game_minutes", _game_minutes)))
	var game_time := _get_game_time()
	if game_time:
		game_time.set_time(day, minutes)
	else:
		_day = day
		_game_minutes = minutes
	var reputation := int(data.get("reputation", ReputationConfigScript.STARTING_REPUTATION))
	var reputation_manager := _get_reputation()
	if reputation_manager:
		reputation_manager.set_reputation(reputation)
	var unlocks: Array = data.get("unlocked_products", [])
	var unlock_manager := _get_unlocks()
	if unlock_manager:
		if unlocks.is_empty():
			unlock_manager.reset_for_new_game()
		else:
			unlock_manager.restore_unlocked_products(unlocks)
		unlock_manager.sync_unlock_popups_for_level(get_level())
	else:
		if unlocks.is_empty():
			_reset_unlocked_products_defaults()
		else:
			_restore_unlocked_products_local(unlocks)
	progression_changed.emit()


func _apply_session(tree: SceneTree, data: Dictionary) -> void:
	var session := tree.root.get_node_or_null("GameSession")
	if session == null:
		return
	if bool(data.get("is_day_started", false)):
		if session.has_method("restore_started_state"):
			session.restore_started_state()
		elif session.has_method("acknowledge_day_start"):
			session.acknowledge_day_start()
	else:
		if session.has_method("reset_for_new_day"):
			session.reset_for_new_day()


func _apply_economy(data: Dictionary) -> void:
	var economy := _get_economy()
	if economy == null:
		return
	if economy.has_method("restore_day_expenses"):
		economy.restore_day_expenses(data.get("day_expenses", []))


func _apply_day_end(data: Dictionary) -> void:
	var day_end := _get_day_end()
	if day_end and day_end.has_method("apply_save_state"):
		day_end.apply_save_state(data)


func _apply_day_stats(data: Dictionary) -> void:
	var tracker := _get_day_stats()
	if tracker and tracker.has_method("apply_save_state"):
		tracker.apply_save_state(data)


func _apply_garbage(data: Dictionary) -> void:
	var garbage := _get_garbage_drop_manager()
	if garbage and garbage.has_method("apply_save_state"):
		garbage.apply_save_state(data)


func _apply_game_time_runtime(game_time_data: Dictionary, session_data: Dictionary) -> void:
	var game_time := _get_game_time()
	if game_time == null:
		return
	var should_run := bool(session_data.get("time_running", false))
	if game_time_data.has("running"):
		should_run = bool(game_time_data.get("running", should_run))
	if should_run and bool(session_data.get("is_day_started", false)):
		game_time.set_running(true)
	else:
		game_time.set_running(false)


func _reset_day_end_flow() -> void:
	var flow := get_node_or_null("/root/DayEndFlow")
	if flow and flow.has_method("reset_summary_state"):
		flow.reset_summary_state()


func _apply_placeables(tree: SceneTree, entries: Array) -> void:
	if entries.is_empty():
		return
	var grid := tree.root.get_node_or_null("GridService") as WarehouseGrid
	if grid == null:
		return
	for entry in entries:
		var type_name := String(entry.get("type", ""))
		var cell := array_to_vec2i(entry.get("cell", [0, 0]))
		var yaw := float(entry.get("yaw", 0.0))
		match type_name:
			"shelf":
				_apply_shelf_entry(tree, grid, cell, yaw, entry)
			"storage_shelf":
				_apply_storage_shelf_entry(tree, grid, cell, yaw, entry)
			"packing_table":
				_apply_named_placeable(tree, "packing_tables", PackingTableScript, grid, cell, yaw)
			"reception_table":
				_apply_named_placeable(tree, "reception_tables", ReceptionTableScript, grid, cell, yaw)
			"computer_workstation":
				_apply_named_placeable(
					tree, "computer_workstations", ComputerWorkstationScript, grid, cell, yaw
				)
			"outbound_van":
				_apply_outbound_van_position(tree, grid, cell, yaw)


func _apply_shelf_entry(
	tree: SceneTree,
	grid: WarehouseGrid,
	cell: Vector2i,
	yaw: float,
	entry: Dictionary
) -> void:
	var shelf: Node = null
	for node in tree.get_nodes_in_group("shelves"):
		if node.get_anchor_cell() == cell:
			shelf = node
			break
	if shelf == null:
		for node in tree.get_nodes_in_group("shelves"):
			if String(node.product_id) == "" and int(node.count) == 0:
				shelf = node
				break
	if shelf == null:
		shelf = ProductShelfScript.new()
		shelf.name = "Shelf_%d_%d" % [cell.x, cell.y]
		shelf.add_to_group("shelves")
		var parent := tree.get_first_node_in_group("warehouse_shelves")
		if parent:
			parent.add_child(shelf)
		else:
			tree.root.add_child(shelf)
	if shelf.has_method("apply_placement"):
		shelf.apply_placement(cell, yaw)
	var product_id := String(entry.get("product_id", ""))
	var count := int(entry.get("count", 0))
	if shelf.has_method("clear_stock"):
		shelf.clear_stock()
	if product_id != "" and count > 0 and shelf.has_method("stock_product"):
		shelf.stock_product(product_id, count)


func _apply_storage_shelf_entry(
	tree: SceneTree,
	grid: WarehouseGrid,
	cell: Vector2i,
	yaw: float,
	entry: Dictionary
) -> void:
	var shelf: Node = null
	for node in tree.get_nodes_in_group("storage_shelves"):
		if node.get_anchor_cell() == cell:
			shelf = node
			break
	if shelf == null:
		shelf = StorageShelfScript.new()
		shelf.name = "StorageShelf_%d_%d" % [cell.x, cell.y]
		var parent := tree.get_first_node_in_group("warehouse_shelves")
		if parent:
			parent.add_child(shelf)
		else:
			tree.root.add_child(shelf)
	if shelf.has_method("apply_placement"):
		shelf.apply_placement(cell, yaw)
	if shelf.has_method("apply_boxes_state"):
		var boxes: Array = entry.get("boxes", [])
		var next_id := int(entry.get("next_box_id", 1))
		shelf.apply_boxes_state(boxes, next_id)


func _apply_named_placeable(
	tree: SceneTree,
	group_name: String,
	script_ref: Script,
	grid: WarehouseGrid,
	cell: Vector2i,
	yaw: float
) -> void:
	var node: Node = tree.get_first_node_in_group(group_name)
	if node == null:
		for placeable in tree.get_nodes_in_group("warehouse_placeables"):
			if placeable.get_script() == script_ref:
				node = placeable
				break
	if node and node.has_method("apply_placement"):
		node.apply_placement(cell, yaw)


func _apply_workers(tree: SceneTree, entries: Array) -> void:
	if entries.is_empty():
		return
	var hire_manager := tree.root.get_node_or_null("WorkerHireManager")
	for entry in entries:
		if not entry is Dictionary:
			continue
		var worker_id := String(entry.get("worker_id", entry.get("id", "")))
		var worker: Node = _find_worker_by_id(tree, worker_id)
		if worker == null and hire_manager != null and hire_manager.has_method("spawn_worker_from_save"):
			worker = hire_manager.spawn_worker_from_save(entry)
		elif worker != null and worker.has_method("apply_save_state"):
			worker.apply_save_state(entry)


func _find_worker_by_id(tree: SceneTree, worker_id: String) -> Node:
	if worker_id == "":
		return null
	for worker in tree.get_nodes_in_group("workers"):
		if worker.has_method("get_worker_id") and worker.get_worker_id() == worker_id:
			return worker
	return null


func _apply_dock(tree: SceneTree, data: Dictionary) -> void:
	var dock := tree.get_first_node_in_group("loading_dock")
	if dock == null:
		return
	if dock.has_method("apply_save_state"):
		dock.apply_save_state(data)


func _apply_outbound_van(tree: SceneTree, data: Dictionary) -> void:
	var van := tree.get_first_node_in_group("outbound_delivery_vehicles")
	if van == null:
		return
	if van.has_method("apply_save_state"):
		van.apply_save_state(data)


func _apply_outbound_van_position(
	tree: SceneTree,
	grid: WarehouseGrid,
	cell: Vector2i,
	yaw: float
) -> void:
	var van := tree.get_first_node_in_group("outbound_delivery_vehicles")
	if van and van.has_method("setup"):
		van.setup(grid.cell_to_world(cell), yaw)


func _apply_customer_queue(tree: SceneTree, data: Dictionary) -> void:
	if data.is_empty():
		return
	var queue := tree.get_first_node_in_group("customer_queue")
	if queue and queue.has_method("apply_save_state"):
		queue.apply_save_state(data)


func _sync_hud(tree: SceneTree) -> void:
	for hud in tree.get_nodes_in_group("hud"):
		if hud.has_method("sync_from_progression_sources"):
			hud.sync_from_progression_sources()
		elif hud.has_method("sync_from_save_manager"):
			hud.sync_from_save_manager()


func _get_economy() -> Node:
	return get_node_or_null("/root/EconomyManager")


func _get_progression() -> Node:
	return get_node_or_null("/root/ProgressionManager")


func _get_unlocks() -> Node:
	return get_node_or_null("/root/UnlockManager")


func _get_game_time() -> Node:
	return get_node_or_null("/root/GameTimeManager")


func _sync_game_time_from_reset() -> void:
	var game_time := _get_game_time()
	if game_time and game_time.has_method("reset_for_new_game"):
		game_time.reset_for_new_game()
	_day = get_day()
	_game_minutes = get_game_minutes()


func _sync_unlocks_from_reset() -> void:
	var unlocks := _get_unlocks()
	if unlocks and unlocks.has_method("reset_for_new_game"):
		unlocks.reset_for_new_game()
	_unlocked_products = get_unlocked_products()


func _sync_progression_from_reset() -> void:
	var progression := _get_progression()
	if progression and progression.has_method("reset_for_new_game"):
		progression.reset_for_new_game()
	_xp = get_xp()
	_level = get_level()


func get_reputation() -> int:
	return _get_reputation().get_reputation() if _get_reputation() else ReputationConfigScript.STARTING_REPUTATION


func set_reputation(value: int) -> void:
	var reputation := _get_reputation()
	if reputation:
		reputation.set_reputation(value)
	progression_changed.emit()


func _sync_reputation_from_reset() -> void:
	var reputation := _get_reputation()
	if reputation and reputation.has_method("reset_for_new_game"):
		reputation.reset_for_new_game()


func _get_reputation() -> Node:
	return get_node_or_null("/root/ReputationManager")


func _sync_coins_from_economy_reset() -> void:
	var economy := _get_economy()
	if economy and economy.has_method("reset_for_new_game"):
		economy.reset_for_new_game()
	_coins = get_coins()


func _sync_day_end_from_reset() -> void:
	var day_end := _get_day_end()
	if day_end and day_end.has_method("reset_for_new_game"):
		day_end.reset_for_new_game()


func _get_day_end() -> Node:
	return get_node_or_null("/root/DayEndManager")


func _get_day_stats() -> Node:
	return get_node_or_null("/root/DayStatsTracker")


func _sync_worker_tasks_from_reset() -> void:
	var tasks := _get_worker_tasks()
	if tasks and tasks.has_method("reset_for_new_game"):
		tasks.reset_for_new_game()


func _get_worker_tasks() -> Node:
	return get_node_or_null("/root/WorkerTaskManager")


func _sync_garbage_from_reset() -> void:
	var garbage := _get_garbage_drop_manager()
	if garbage and garbage.has_method("reset_for_new_game"):
		garbage.reset_for_new_game()


func _get_garbage_drop_manager() -> Node:
	return get_node_or_null("/root/GarbageDropManager")


func _collect_incoming_deliveries() -> Dictionary:
	var manager := _get_incoming_deliveries()
	if manager and manager.has_method("export_save_state"):
		return manager.export_save_state()
	return {"pending": [], "next_order_id": 1}


func _apply_incoming_deliveries(data: Dictionary) -> void:
	var manager := _get_incoming_deliveries()
	if manager and manager.has_method("apply_save_state"):
		manager.apply_save_state(data)


func _sync_incoming_deliveries_reset() -> void:
	var manager := _get_incoming_deliveries()
	if manager and manager.has_method("reset_for_new_game"):
		manager.reset_for_new_game()


func _get_incoming_deliveries() -> Node:
	return get_node_or_null("/root/IncomingDeliveryManager")


# ── helpers ───────────────────────────────────────────────────────────────────

func _reset_unlocked_products_defaults() -> void:
	var unlocks := _get_unlocks()
	if unlocks and unlocks.has_method("reset_for_new_game"):
		unlocks.reset_for_new_game()
		_unlocked_products = unlocks.get_unlocked_products()
		return
	_restore_unlocked_products_local(UnlockConfigScript.starting_products())


func _restore_unlocked_products_local(product_ids: Array) -> void:
	_unlocked_products.clear()
	for product_id in product_ids:
		var id := String(product_id)
		if ProductCatalogScript.has_id(id) and not ProductCatalogScript.is_package(id):
			_unlocked_products.append(id)
	if _unlocked_products.is_empty():
		for starter_id in UnlockConfigScript.starting_products():
			_unlocked_products.append(starter_id)


func _empty_save_template() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"progression": _collect_progression(),
		"session": {"is_day_started": false, "time_running": false},
		"game_time": _collect_game_time_runtime(),
		"economy": {"day_expenses": []},
		"day_end": {"payroll_settled_day": -1, "last_checked_minute": -1, "last_summary": {}},
		"day_stats": {},
		"garbage": {"pieces": []},
		"placeables": [],
		"workers": [],
		"dock": {
			"delivery_started": false,
			"queue_started": false,
			"boxes": [],
			"equipment_boxes": [],
		},
		"outbound_van": {"loaded_packages": [], "capacity": 4, "state": "idle"},
		"customer_queue": {},
		"incoming_deliveries": {"pending": [], "next_order_id": 1},
	}


func _world_to_cell(root: Node, world_position: Vector3) -> Vector2i:
	var grid := root.get_node_or_null("/root/GridService") as WarehouseGrid
	if grid:
		return grid.world_to_cell(world_position)
	return Vector2i(int(world_position.x), int(world_position.z))


static func vec2i_to_array(cell: Vector2i) -> Array:
	return [cell.x, cell.y]


static func array_to_vec2i(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


static func vec3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func array_to_vec3(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
