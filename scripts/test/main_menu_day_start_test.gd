extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/main_menu_day_start_test.gd

const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const DayStartPopupScript = preload("res://scripts/ui/day_start_popup.gd")
const MainMenuScript = preload("res://scripts/ui/main_menu.gd")
const GameSessionScript = preload("res://scripts/gameplay/game_session.gd")

const MAIN_MENU_SCENE := "res://scenes/main/main_menu.tscn"
const GAMEPLAY_SCENE := "res://scenes/main/main.tscn"


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_test_session()
	var failed := 0
	failed += _assert("project main scene is main menu", _test_main_scene_is_menu())
	failed += _assert("main menu scene file exists", ResourceLoader.exists(MAIN_MENU_SCENE))
	failed += _assert("gameplay scene file exists", ResourceLoader.exists(GAMEPLAY_SCENE))
	failed += _assert("main menu builds start button", _test_main_menu_button())
	failed += _assert("day start gates then enables customers", await _test_day_start_gates_spawning())
	failed += _assert("welcome popup opens and closes", _test_welcome_popup_flow())

	if failed == 0:
		print("main_menu_day_start_test: ALL PASSED")
		quit(0)
	else:
		push_error("main_menu_day_start_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _test_main_scene_is_menu() -> bool:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	return main_scene == MAIN_MENU_SCENE


func _test_main_menu_button() -> bool:
	var menu: Control = MainMenuScript.new()
	menu.ensure_built()
	var btn := menu.find_child("StartGameButton", true, false) as Button
	return btn != null and btn.text == "Start Game"


func _ensure_test_session() -> void:
	if root.get_node_or_null("GameSession") != null:
		return
	var session: Node = GameSessionScript.new()
	session.name = "GameSession"
	root.add_child(session)


func _session() -> Node:
	return root.get_node("GameSession")


func _make_queue() -> Node:
	var queue: Node = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	return queue


func _test_day_start_gates_spawning() -> bool:
	_session().reset_for_new_day()
	var queue := _make_queue()
	await process_frame
	if _session().is_gameplay_active() or queue.is_spawning_enabled():
		return false
	_session().acknowledge_day_start()
	await process_frame
	return _session().is_gameplay_active() and queue.is_spawning_enabled()


func _test_welcome_popup_flow() -> bool:
	_session().reset_for_new_day()
	var popup: Control = DayStartPopupScript.new()
	root.add_child(popup)
	popup.open(1)
	if not popup.is_open():
		return false
	_session().acknowledge_day_start()
	popup.close()
	return not popup.is_open() and _session().is_gameplay_active()
