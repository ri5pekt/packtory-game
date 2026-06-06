extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/settings_menu_test.gd

const DayEndManagerScript = preload("res://scripts/gameplay/day_end_manager.gd")
const GameSessionScript = preload("res://scripts/gameplay/game_session.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const SettingsMenuConfigScript = preload("res://scripts/gameplay/settings_menu_config.gd")
const SettingsMenuUIScript = preload("res://scripts/ui/settings_menu_ui.gd")
const SettingsOptionsAreaScript = preload("res://scripts/ui/settings_options_area.gd")
const GAMEPLAY_SCENE := "res://scenes/main/main.tscn"


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	var failed := 0
	failed += _assert("gameplay scene includes settings menu", _test_scene_has_settings_menu())
	failed += _assert("settings menu opens and closes", await _test_open_close())
	failed += _assert("end day disabled before gameplay starts", _test_end_day_before_day_start())
	failed += _assert("end day disabled before evening", _test_end_day_before_evening())
	failed += _assert("end day enabled during evening", _test_end_day_evening_available())
	failed += _assert("end day disabled after payroll settled", _test_end_day_after_settled())
	failed += _assert("evening reminder appears when appropriate", await _test_evening_reminder())
	failed += _assert("overlay tap closes menu", await _test_overlay_closes())
	failed += _assert("options area has no placeholder rows", await _test_no_placeholders())

	if failed == 0:
		print("settings_menu_test: ALL PASSED")
		quit(0)
	else:
		push_error("settings_menu_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_autoloads() -> void:
	if root.get_node_or_null("GameSession") == null:
		var session: Node = GameSessionScript.new()
		session.name = "GameSession"
		root.add_child(session)
	if root.get_node_or_null("GameTimeManager") == null:
		var game_time: Node = GameTimeManagerScript.new()
		game_time.name = "GameTimeManager"
		root.add_child(game_time)
	if root.get_node_or_null("DayEndManager") == null:
		var day_end: Node = DayEndManagerScript.new()
		day_end.name = "DayEndManager"
		root.add_child(day_end)


func _session() -> Node:
	return root.get_node("GameSession")


func _game_time() -> Node:
	return root.get_node("GameTimeManager")


func _day_end() -> Node:
	return root.get_node("DayEndManager")


func _make_settings_menu() -> Control:
	var menu: Control = SettingsMenuUIScript.new()
	menu.set_size(Vector2(1280.0, 720.0))
	root.add_child(menu)
	menu.ensure_built()
	return menu


func _test_scene_has_settings_menu() -> bool:
	if not ResourceLoader.exists(GAMEPLAY_SCENE):
		return false
	var scene_text := FileAccess.get_file_as_string(GAMEPLAY_SCENE)
	return (
		scene_text.contains('[node name="SettingsMenuUI"')
		and scene_text.contains("scripts/ui/settings_menu_ui.gd")
	)


func _test_open_close() -> bool:
	var menu := _make_settings_menu()
	if menu.is_open():
		return false
	menu.open()
	await process_frame
	var opened: bool = menu.is_open()
	menu.close()
	await process_frame
	var closed: bool = not menu.is_open()
	menu.queue_free()
	return opened and closed


func _reset_day_flow() -> void:
	_session().reset_for_new_day()
	_game_time().reset_for_new_game()
	_day_end().reset_for_new_game()


func _test_end_day_before_day_start() -> bool:
	_reset_day_flow()
	_game_time().set_time(1, 1100)
	var state: Dictionary = _day_end().can_end_day()
	return (
		not bool(state.get("allowed", true))
		and String(state.get("reason", "")) == SettingsMenuConfigScript.REASON_GAME_NOT_STARTED
	)


func _test_end_day_before_evening() -> bool:
	_reset_day_flow()
	_session().acknowledge_day_start()
	_game_time().set_time(1, 900)
	var state: Dictionary = _day_end().can_end_day()
	return (
		not bool(state.get("allowed", true))
		and String(state.get("reason", "")) == SettingsMenuConfigScript.REASON_TOO_EARLY
	)


func _test_end_day_evening_available() -> bool:
	_reset_day_flow()
	_session().acknowledge_day_start()
	_game_time().set_time(1, 1100)
	var state: Dictionary = _day_end().can_end_day()
	return bool(state.get("allowed", false))


func _test_end_day_after_settled() -> bool:
	_reset_day_flow()
	_session().acknowledge_day_start()
	_game_time().set_time(1, 1100)
	_day_end().end_day(true)
	var state: Dictionary = _day_end().can_end_day()
	return (
		not bool(state.get("allowed", true))
		and String(state.get("reason", "")) == SettingsMenuConfigScript.REASON_ALREADY_ENDED
	)


func _test_evening_reminder() -> bool:
	_reset_day_flow()
	_session().acknowledge_day_start()
	_game_time().set_time(1, 1100)
	var state: Dictionary = _day_end().can_end_day()
	var menu := _make_settings_menu()
	menu.open()
	await process_frame
	var ok: bool = (
		bool(state.get("show_evening_reminder", false))
		and bool(menu.call("is_evening_reminder_visible"))
	)
	menu.queue_free()
	return ok


func _test_overlay_closes() -> bool:
	var menu := _make_settings_menu()
	menu.open()
	await process_frame
	if not menu.is_open():
		menu.queue_free()
		return false
	menu._on_overlay_input(_mouse_click(Vector2(40.0, 200.0)))
	await process_frame
	await process_frame
	var closed: bool = not menu.is_open()
	menu.queue_free()
	return closed


func _mouse_click(pos: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = pos
	return event


func _test_no_placeholders() -> bool:
	var area: VBoxContainer = SettingsOptionsAreaScript.new()
	root.add_child(area)
	await process_frame
	var clean: bool = (
		area.get_row("audio") == null
		and area.get_row("developer_tools") == null
		and area.get_child_count() == 0
	)
	area.queue_free()
	return clean
