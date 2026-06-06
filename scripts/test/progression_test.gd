extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/progression_test.gd

const ProgressionManagerScript = preload("res://scripts/gameplay/progression_manager.gd")
const ProgressionConfigScript = preload("res://scripts/gameplay/progression_config.gd")
const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")
const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const CustomerScript = preload("res://scripts/gameplay/customer.gd")
const HudProgressionPanelScript = preload("res://scripts/ui/hud_progression_panel.gd")
const LevelUpPopupScript = preload("res://scripts/ui/level_up_popup.gd")
const WorkerScript = preload("res://scenes/worker/worker.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("new game starts at level 0 with 0 xp", _test_new_game_defaults())
	failed += _assert("fulfillment grants configurable xp", _test_fulfillment_xp())
	failed += _assert("customer queue registers with progression", await _test_queue_registers_with_progression())
	failed += _assert("xp increases on grant", _test_xp_increases())
	failed += _assert("level increases at threshold", _test_level_increases())
	failed += _assert("order fulfilled signal grants xp", await _test_deliver_grants_xp())
	failed += _assert("hud xp ring updates immediately", _test_hud_updates_immediately())
	failed += _assert("multiple level-ups queue popup steps", _test_multiple_level_ups())
	failed += _assert("progression persists through save", _test_progression_persist_in_save())

	if failed == 0:
		print("progression_test: ALL PASSED")
		quit(0)
	else:
		push_error("progression_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_autoloads() -> void:
	if root.get_node_or_null("EconomyManager") == null:
		var economy_script: Script = load("res://scripts/gameplay/economy_manager.gd") as Script
		var economy: Node = economy_script.new()
		economy.name = "EconomyManager"
		root.add_child(economy)
	if root.get_node_or_null("UnlockManager") == null:
		var unlock_script: Script = load("res://scripts/gameplay/unlock_manager.gd") as Script
		var unlock_mgr: Node = unlock_script.new()
		unlock_mgr.name = "UnlockManager"
		root.add_child(unlock_mgr)
	if root.get_node_or_null("ProgressionManager") == null:
		var progression: Node = ProgressionManagerScript.new()
		progression.name = "ProgressionManager"
		root.add_child(progression)
	if root.get_node_or_null("SaveManager") == null:
		var save: Node = SaveManagerScript.new()
		save.name = "SaveManager"
		root.add_child(save)


func _progression() -> Node:
	return root.get_node("ProgressionManager")


func _save() -> Node:
	return root.get_node("SaveManager")


func _test_new_game_defaults() -> bool:
	_save().prepare_new_game()
	return (
		_progression().get_level() == ProgressionConfigScript.STARTING_LEVEL
		and _progression().get_xp() == 0
		and _progression().get_total_xp() == ProgressionConfigScript.STARTING_TOTAL_XP
	)


func _test_fulfillment_xp() -> bool:
	_progression().reset_for_new_game()
	var granted: int = _progression().grant_fulfillment_xp({"source": "in_person", "order": {"mouse": 1}})
	return granted == ProgressionConfigScript.IN_PERSON_ORDER_XP


func _test_queue_registers_with_progression() -> bool:
	_progression().reset_for_new_game()
	var queue = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	await process_frame
	return _progression().is_customer_queue_connected(queue)


func _test_xp_increases() -> bool:
	_progression().reset_for_new_game()
	_progression().add_xp(20, "test")
	return _progression().get_total_xp() == 20


func _test_level_increases() -> bool:
	_progression().reset_for_new_game()
	var need := ProgressionConfigScript.xp_required_for_level(0)
	_progression().add_xp(need, "test")
	return _progression().get_level() == 1 and _progression().get_xp() == 0


func _test_deliver_grants_xp() -> bool:
	_progression().reset_for_new_game()
	var queue = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	await process_frame

	var customer: Customer = CustomerScript.new()
	customer.name = "Customer"
	root.add_child(customer)
	customer.order = {"mouse": 1}
	customer.state = Customer.State.WAITING_PICKUP
	queue._customers.append(customer)
	queue._delivery_customer = customer

	var worker: Worker = WorkerScript.instantiate()
	worker.name = "Worker"
	root.add_child(worker)
	await process_frame
	worker.add_product("package")

	var delivered: bool = queue.deliver_to_customer(customer, worker)
	queue.queue_free()
	worker.queue_free()
	customer.queue_free()
	return (
		delivered
		and _progression().get_total_xp() == ProgressionConfigScript.IN_PERSON_ORDER_XP
	)


func _test_hud_updates_immediately() -> bool:
	_progression().reset_for_new_game()
	var panel = HudProgressionPanelScript.new()
	root.add_child(panel)
	panel.ensure_built()
	panel.bind_progression_manager()
	_progression().add_xp(30, "test")
	var values: Dictionary = panel.get_display_values()
	panel.queue_free()
	return (
		int(values.get("level", -1)) == _progression().get_level()
		and int(values.get("xp", -1)) == _progression().get_xp()
		and float(values.get("xp_progress", -1.0)) > 0.0
	)


func _test_multiple_level_ups() -> bool:
	_progression().reset_for_new_game()
	_unlocks().reset_for_new_game()
	var popup = LevelUpPopupScript.new()
	root.add_child(popup)
	popup.ensure_built()
	_progression().levels_gained.connect(popup.enqueue_levels)
	_progression().levels_gained.connect(_unlocks().on_levels_gained)
	var jump := (
		ProgressionConfigScript.xp_required_for_level(0)
		+ ProgressionConfigScript.xp_required_for_level(1)
		+ ProgressionConfigScript.xp_required_for_level(2)
		+ 5
	)
	_progression().add_xp(jump, "test")
	var shown: int = 1 if popup.is_showing() else 0
	var ok: bool = (
		_progression().get_level() == 3
		and popup.get_pending_count() + shown >= 2
		and _unlocks().get_pending_popup_count() >= 1
	)
	popup.queue_free()
	return ok


func _unlocks() -> Node:
	return root.get_node("UnlockManager")


func _test_progression_persist_in_save() -> bool:
	_save().set_test_mode(true, "user://packtory_progression_test_save.json")
	_save().delete_save()
	_progression().reset_for_new_game()
	_progression().set_total_xp(250)
	if not _save().save_current_scene(self):
		return false
	_progression().reset_for_new_game()
	if _progression().get_total_xp() != 0:
		return false
	if not _save().load_save_file():
		return false
	_save()._apply_progression_from_dict(_save().get_pending_data().get("progression", {}))
	_save().delete_save()
	return _progression().get_total_xp() == 250 and _progression().get_level() == 3
