extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/economy_test.gd

const EconomyManagerScript = preload("res://scripts/gameplay/economy_manager.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")
const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")
const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const CustomerScript = preload("res://scripts/gameplay/customer.gd")
const HudProgressionPanelScript = preload("res://scripts/ui/hud_progression_panel.gd")
const WorkerScript = preload("res://scenes/worker/worker.tscn")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("new game starts with configured coins", _test_new_game_starting_coins())
	failed += _assert("fulfillment grants configurable reward", _test_fulfillment_reward())
	failed += _assert("customer queue registers with economy", await _test_queue_registers_with_economy())
	failed += _assert("order fulfilled signal grants coins", await _test_deliver_grants_coins())
	failed += _assert("hud updates immediately on coin change", _test_hud_updates_immediately())
	failed += _assert("coins persist through save gameplay", _test_coins_persist_in_save())

	if failed == 0:
		print("economy_test: ALL PASSED")
		quit(0)
	else:
		push_error("economy_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_autoloads() -> void:
	if root.get_node_or_null("EconomyManager") == null:
		var economy: Node = EconomyManagerScript.new()
		economy.name = "EconomyManager"
		root.add_child(economy)
	if root.get_node_or_null("UnlockManager") == null:
		var unlock_script: Script = load("res://scripts/gameplay/unlock_manager.gd") as Script
		var unlocks: Node = unlock_script.new()
		unlocks.name = "UnlockManager"
		root.add_child(unlocks)
	if root.get_node_or_null("ProgressionManager") == null:
		var progression_script: Script = load("res://scripts/gameplay/progression_manager.gd") as Script
		var progression: Node = progression_script.new()
		progression.name = "ProgressionManager"
		root.add_child(progression)
	if root.get_node_or_null("SaveManager") == null:
		var save: Node = SaveManagerScript.new()
		save.name = "SaveManager"
		root.add_child(save)


func _economy() -> Node:
	return root.get_node("EconomyManager")


func _save() -> Node:
	return root.get_node("SaveManager")


func _test_new_game_starting_coins() -> bool:
	_save().prepare_new_game()
	return _economy().get_coins() == EconomyConfigScript.STARTING_COINS


func _test_fulfillment_reward() -> bool:
	_economy().reset_for_new_game()
	var granted: int = _economy().grant_fulfillment_reward({"source": "in_person", "order": {"mouse": 1}})
	return (
		granted == EconomyConfigScript.IN_PERSON_ORDER_REWARD
		and _economy().get_coins()
			== EconomyConfigScript.STARTING_COINS + EconomyConfigScript.IN_PERSON_ORDER_REWARD
	)


func _test_queue_registers_with_economy() -> bool:
	_economy().reset_for_new_game()
	var queue = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	await process_frame
	return _economy().is_customer_queue_connected(queue)


func _test_deliver_grants_coins() -> bool:
	_economy().reset_for_new_game()
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
		and _economy().get_coins()
			== EconomyConfigScript.STARTING_COINS + EconomyConfigScript.IN_PERSON_ORDER_REWARD
	)


func _test_hud_updates_immediately() -> bool:
	_economy().reset_for_new_game()
	var panel = HudProgressionPanelScript.new()
	root.add_child(panel)
	panel.ensure_built()
	panel.bind_economy()
	_economy().add_coins(EconomyConfigScript.IN_PERSON_ORDER_REWARD, "test")
	var values: Dictionary = panel.get_display_values()
	panel.queue_free()
	return (
		int(values.get("coins", -1))
		== EconomyConfigScript.STARTING_COINS + EconomyConfigScript.IN_PERSON_ORDER_REWARD
	)


func _test_coins_persist_in_save() -> bool:
	_save().set_test_mode(true, "user://packtory_economy_test_save.json")
	_save().delete_save()
	_economy().reset_for_new_game()
	_economy().add_coins(42, "test_persist")
	if not _save().save_current_scene(self):
		return false
	_economy().reset_for_new_game()
	if _economy().get_coins() != 0:
		return false
	if not _save().load_save_file():
		return false
	_save()._apply_progression_from_dict(_save().get_pending_data().get("progression", {}))
	_save().delete_save()
	return _economy().get_coins() == 42
