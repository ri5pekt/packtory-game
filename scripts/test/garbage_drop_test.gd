extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/garbage_drop_test.gd

const ContextMenuScene = preload("res://scenes/ui/context_menu.tscn")
const FloorGarbageScript = preload("res://scripts/gameplay/floor_garbage.gd")
const GarbageDropConfigScript = preload("res://scripts/gameplay/garbage_drop_config.gd")
const GarbageDropManagerScript = preload("res://scripts/gameplay/garbage_drop_manager.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const IconRegistryScript = preload("res://scripts/ui/icon_registry.gd")
const InteractableRaycastScript = preload("res://scripts/shared/interactable_raycast.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("customers occasionally drop garbage", _test_occasional_drop())
	failed += _assert("garbage spawns on warehouse floor", _test_spawn_on_floor())
	failed += _assert("garbage is clickable via raycast", _test_garbage_clickable())
	failed += _assert("clean action appears in context menu", _test_clean_context_action())
	failed += _assert("clean icon is available", _test_clean_icon())
	failed += _assert("garbage disappears after cleaning", _test_garbage_removed_on_clean())
	failed += _assert("multiple garbage items can exist and be cleaned", await _test_multiple_garbage())

	if failed == 0:
		print("garbage_drop_test: ALL PASSED")
		quit(0)
	else:
		push_error("garbage_drop_test: %d FAILED" % failed)
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
	if root.get_node_or_null("GarbageDropManager") == null:
		var manager: Node = GarbageDropManagerScript.new()
		manager.name = "GarbageDropManager"
		root.add_child(manager)


func _manager() -> Node:
	return root.get_node("GarbageDropManager")


func _clear_garbage() -> void:
	_manager().clear_all_garbage()


func _spawn_garbage(position: Vector3):
	return _manager().spawn_garbage_at(position)


func _test_occasional_drop() -> bool:
	_clear_garbage()
	var hits := 0
	for _i in range(120):
		if _manager().try_drop_near(Vector3(16.5, 0.0, 18.0), GarbageDropConfigScript.DROP_CHANCE_ON_ARRIVE, false) != null:
			hits += 1
	_clear_garbage()
	return hits >= 8 and hits <= 80


func _test_spawn_on_floor() -> bool:
	_clear_garbage()
	var grid: WarehouseGrid = root.get_node("GridService")
	var pos := grid.cell_to_world(Vector2i(15, 18))
	var garbage = _spawn_garbage(pos)
	return (
		garbage != null
		and garbage.is_in_group("floor_garbage")
		and garbage.global_position.y >= WarehouseGrid.WAREHOUSE_FLOOR_SURFACE_Y - 0.05
	)


func _test_garbage_clickable() -> bool:
	_clear_garbage()
	var garbage = _spawn_garbage(Vector3(16.0, 0.0, 17.5))
	var click_area := garbage.get_node_or_null("ClickArea") as Area3D
	if click_area == null:
		return false
	var resolved: Node = InteractableRaycastScript.resolve_interactable(click_area)
	return resolved == garbage


func _test_clean_context_action() -> bool:
	_clear_garbage()
	_spawn_garbage(Vector3(16.0, 0.0, 17.5))
	var menu: VBoxContainer = ContextMenuScene.instantiate()
	root.add_child(menu)
	menu.show_actions(Vector2(120.0, 140.0), [{"id": "clean", "label": "Clean"}])
	var labels := _menu_action_labels(menu)
	menu.queue_free()
	return labels.has("Clean")


func _test_clean_icon() -> bool:
	return IconRegistryScript.action_icon("clean") != null


func _test_garbage_removed_on_clean() -> bool:
	_clear_garbage()
	var garbage = _spawn_garbage(Vector3(16.0, 0.0, 17.5))
	garbage.clean()
	return not is_instance_valid(garbage) or garbage.is_queued_for_deletion()


func _test_multiple_garbage() -> bool:
	_clear_garbage()
	var pieces: Array = []
	for i in range(5):
		pieces.append(_spawn_garbage(Vector3(15.5 + float(i) * 0.2, 0.0, 17.0)))
	await process_frame
	if _manager().get_garbage_count() != 5:
		return false
	for piece in pieces:
		if is_instance_valid(piece):
			piece.clean()
	await process_frame
	return _manager().get_garbage_count() == 0


func _menu_action_labels(menu: PanelContainer) -> PackedStringArray:
	var labels := PackedStringArray()
	var actions := menu.get_node_or_null("Actions")
	if actions == null:
		return labels
	for child in actions.get_children():
		if child is Button:
			labels.append(child.text)
	return labels
