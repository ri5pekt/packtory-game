extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/game_time_test.gd

const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")
const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")
const HudProgressionPanelScript = preload("res://scripts/ui/hud_progression_panel.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("new game starts at 08:00", _test_new_game_start_time())
	failed += _assert("time does not advance while paused", _test_paused_no_advance())
	failed += _assert("time advances when running", _test_time_advances())
	failed += _assert("default scale is 1 game minute per real second", _test_default_scale())
	failed += _assert("time scale is configurable", _test_configurable_scale())
	failed += _assert("conversion helpers match scale", _test_conversion_helpers())
	failed += _assert("hud updates immediately on time change", _test_hud_updates_immediately())
	failed += _assert("game time persists through save", _test_time_persist_in_save())

	if failed == 0:
		print("game_time_test: ALL PASSED")
		quit(0)
	else:
		push_error("game_time_test: %d FAILED" % failed)
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
	if root.get_node_or_null("SaveManager") == null:
		var save: Node = SaveManagerScript.new()
		save.name = "SaveManager"
		root.add_child(save)


func _game_time() -> Node:
	return root.get_node("GameTimeManager")


func _save() -> Node:
	return root.get_node("SaveManager")


func _test_new_game_start_time() -> bool:
	_save().prepare_new_game()
	return (
		_game_time().get_game_minutes() == GameTimeConfigScript.DAY_START_MINUTES
		and _game_time().format_time() == "08:00"
	)


func _test_paused_no_advance() -> bool:
	_game_time().reset_for_new_game()
	_game_time().set_running(false)
	var before: int = _game_time().get_game_minutes()
	_game_time().tick_real_seconds(5.0)
	return _game_time().get_game_minutes() == before


func _test_time_advances() -> bool:
	_game_time().reset_for_new_game()
	_game_time().set_running(true)
	var before: int = _game_time().get_game_minutes()
	_game_time().advance_by_real_seconds(3.0)
	return _game_time().get_game_minutes() == before + 3


func _test_default_scale() -> bool:
	_game_time().reset_for_new_game()
	return is_equal_approx(
		_game_time().get_time_scale(),
		GameTimeConfigScript.DEFAULT_GAME_MINUTES_PER_REAL_SECOND
	)


func _test_configurable_scale() -> bool:
	_game_time().reset_for_new_game()
	_game_time().set_time_scale(4.0)
	_game_time().set_running(true)
	var before: int = _game_time().get_game_minutes()
	_game_time().advance_by_real_seconds(2.5)
	return _game_time().get_game_minutes() == before + 10


func _test_conversion_helpers() -> bool:
	_game_time().reset_for_new_game()
	_game_time().set_time_scale(2.0)
	return (
		is_equal_approx(_game_time().game_minutes_for_real_seconds(3.0), 6.0)
		and is_equal_approx(_game_time().real_seconds_for_game_minutes(6.0), 3.0)
	)


func _test_hud_updates_immediately() -> bool:
	_game_time().reset_for_new_game()
	var panel = HudProgressionPanelScript.new()
	root.add_child(panel)
	panel.ensure_built()
	panel.bind_game_time()
	_game_time().set_running(true)
	_game_time().advance_by_real_seconds(12.0)
	var values: Dictionary = panel.get_display_values()
	panel.queue_free()
	return int(values.get("game_minutes", -1)) == GameTimeConfigScript.DAY_START_MINUTES + 12


func _test_time_persist_in_save() -> bool:
	_save().set_test_mode(true, "user://packtory_game_time_test_save.json")
	_save().delete_save()
	_game_time().reset_for_new_game()
	_game_time().set_time(2, 615)
	if not _save().save_current_scene(self):
		return false
	_game_time().reset_for_new_game()
	if _game_time().get_game_minutes() != GameTimeConfigScript.DAY_START_MINUTES:
		return false
	if not _save().load_save_file():
		return false
	_save()._apply_progression_from_dict(_save().get_pending_data().get("progression", {}))
	_save().delete_save()
	return _game_time().get_day() == 2 and _game_time().get_game_minutes() == 615
