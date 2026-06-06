extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/product_unlock_test.gd

const UnlockManagerScript = preload("res://scripts/gameplay/unlock_manager.gd")
const UnlockConfigScript = preload("res://scripts/gameplay/unlock_config.gd")
const ProgressionManagerScript = preload("res://scripts/gameplay/progression_manager.gd")
const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")
const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")
const ProductUnlockPopupScript = preload("res://scripts/ui/product_unlock_popup.gd")
const CustomerScript = preload("res://scripts/gameplay/customer.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("new game starts with starter products only", _test_starter_products())
	failed += _assert("smart watch not in order pool before level 1", _test_smart_watch_locked_initially())
	failed += _assert("reach level 1 queues unlock popup", _test_level_one_queues_popup())
	failed += _assert("popup shows level 1 and smart watch copy", _test_popup_copy())
	failed += _assert("smart watch unlocks only after popup closes", _test_unlock_after_popup())
	failed += _assert("new orders can include smart watch after unlock", _test_new_orders_include_smart_watch())
	failed += _assert("existing active orders remain unchanged", _test_existing_orders_unchanged())

	if failed == 0:
		print("product_unlock_test: ALL PASSED")
		quit(0)
	else:
		push_error("product_unlock_test: %d FAILED" % failed)
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
	if root.get_node_or_null("ProgressionManager") == null:
		var progression: Node = ProgressionManagerScript.new()
		progression.name = "ProgressionManager"
		root.add_child(progression)
	if root.get_node_or_null("UnlockManager") == null:
		var unlocks: Node = UnlockManagerScript.new()
		unlocks.name = "UnlockManager"
		root.add_child(unlocks)
	if root.get_node_or_null("SaveManager") == null:
		var save: Node = SaveManagerScript.new()
		save.name = "SaveManager"
		root.add_child(save)


func _unlocks() -> Node:
	return root.get_node("UnlockManager")


func _progression() -> Node:
	return root.get_node("ProgressionManager")


func _test_starter_products() -> bool:
	_save_prepare_new_game()
	var unlocked: Array = _unlocks().get_unlocked_products()
	return (
		unlocked.size() == UnlockConfigScript.starting_products().size()
		and unlocked.has("mouse")
		and unlocked.has("hair_dryer")
		and unlocked.has("headphones")
		and not unlocked.has("smart_watch")
	)


func _test_smart_watch_locked_initially() -> bool:
	_save_prepare_new_game()
	return not _unlocks().is_product_unlocked("smart_watch")


func _test_level_one_queues_popup() -> bool:
	_save_prepare_new_game()
	_unlocks().on_levels_gained(0, 1, 1)
	return _unlocks().get_pending_popup_count() >= 1


func _test_popup_copy() -> bool:
	var popup = ProductUnlockPopupScript.new()
	root.add_child(popup)
	popup.ensure_built()
	popup.show_unlock({"level": 1, "products": ["smart_watch"]})
	var ok: bool = (
		popup.is_open()
		and _label_contains(popup, "LEVEL 1 REACHED")
		and _label_contains(popup, "NEW PRODUCT AVAILABLE")
		and _label_contains(popup, "Smart Watch")
	)
	popup.queue_free()
	return ok


func _test_unlock_after_popup() -> bool:
	_save_prepare_new_game()
	_unlocks().on_levels_gained(0, 1, 1)
	if _unlocks().is_product_unlocked("smart_watch"):
		return false
	_unlocks().acknowledge_unlock_popup(1)
	return _unlocks().is_product_unlocked("smart_watch")


func _test_new_orders_include_smart_watch() -> bool:
	_save_prepare_new_game()
	_unlocks().on_levels_gained(0, 1, 1)
	_unlocks().acknowledge_unlock_popup(1)
	var pool: Array = _unlocks().get_orderable_product_ids()
	if not pool.has("smart_watch"):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for _i in range(120):
		var order: Dictionary = ProductCatalogScript.random_order(rng, pool)
		if order.has("smart_watch"):
			return true
	return false


func _test_existing_orders_unchanged() -> bool:
	_save_prepare_new_game()
	var existing_order := {"mouse": 2, "headphones": 1}
	var customer: Customer = CustomerScript.new()
	customer.order = existing_order.duplicate()
	var active_order := existing_order.duplicate()

	_unlocks().on_levels_gained(0, 1, 1)
	_unlocks().acknowledge_unlock_popup(1)

	return (
		ProductCatalogScript.orders_match(customer.order, existing_order)
		and ProductCatalogScript.orders_match(active_order, existing_order)
		and not existing_order.has("smart_watch")
	)


func _save_prepare_new_game() -> void:
	root.get_node("SaveManager").prepare_new_game()
	_unlocks().reset_for_new_game()
	_progression().reset_for_new_game()


func _label_contains(node: Node, fragment: String) -> bool:
	if node is Label and String(node.text).contains(fragment):
		return true
	for child in node.get_children():
		if _label_contains(child, fragment):
			return true
	return false
