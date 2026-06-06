extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/hud_top_panel_test.gd

const HudScript = preload("res://scripts/ui/hud.gd")
const HudProgressionPanelScript = preload("res://scripts/ui/hud_progression_panel.gd")
const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")
const ProgressionManagerScript = preload("res://scripts/gameplay/progression_manager.gd")
const ReputationManagerScript = preload("res://scripts/gameplay/reputation_manager.gd")
const ReputationConfigScript = preload("res://scripts/gameplay/reputation_config.gd")
const ProgressionConfigScript = preload("res://scripts/gameplay/progression_config.gd")
const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")
const GAMEPLAY_SCENE := "res://scenes/main/main.tscn"


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_save_manager()
	var failed := 0
	failed += _assert("gameplay scene includes HUD node", _test_gameplay_scene_has_hud())
	failed += _assert("progression panel builds all stat widgets", _test_panel_widgets())
	failed += _assert("panel updates values from apply_values", _test_panel_value_updates())
	failed += _assert("hud exposes update_progression API", _test_hud_update_api())
	failed += _assert("save manager signal refreshes panel", _test_save_manager_sync())
	failed += _assert("reputation bar is compact in HUD row", _test_reputation_bar())
	failed += _assert("touch-friendly action button size", _test_touch_button_size())

	if failed == 0:
		print("hud_top_panel_test: ALL PASSED")
		quit(0)
	else:
		push_error("hud_top_panel_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_save_manager() -> Node:
	if root.get_node_or_null("GameTimeManager") == null:
		var game_time_script: Script = load("res://scripts/gameplay/game_time_manager.gd") as Script
		var game_time: Node = game_time_script.new()
		game_time.name = "GameTimeManager"
		root.add_child(game_time)
	if root.get_node_or_null("UnlockManager") == null:
		var unlock_script: Script = load("res://scripts/gameplay/unlock_manager.gd") as Script
		var unlocks: Node = unlock_script.new()
		unlocks.name = "UnlockManager"
		root.add_child(unlocks)
	if root.get_node_or_null("ProgressionManager") == null:
		var progression: Node = ProgressionManagerScript.new()
		progression.name = "ProgressionManager"
		root.add_child(progression)
	if root.get_node_or_null("ReputationManager") == null:
		var reputation: Node = ReputationManagerScript.new()
		reputation.name = "ReputationManager"
		root.add_child(reputation)
	var existing := root.get_node_or_null("SaveManager")
	if existing:
		return existing
	var save: Node = SaveManagerScript.new()
	save.name = "SaveManager"
	root.add_child(save)
	return save


func _test_gameplay_scene_has_hud() -> bool:
	if not ResourceLoader.exists(GAMEPLAY_SCENE):
		return false
	var scene_text := FileAccess.get_file_as_string(GAMEPLAY_SCENE)
	return (
		scene_text.contains('[node name="HUD"')
		and scene_text.contains("scripts/ui/hud.gd")
	)


func _test_panel_widgets() -> bool:
	var panel: Control = HudProgressionPanelScript.new()
	root.add_child(panel)
	panel.ensure_built()
	var ok := (
		panel.find_child("XpBar", true, false) != null
		and _find_label_with_text(panel, "$")
		and _find_label_with_text(panel, "Day")
	)
	panel.queue_free()
	return ok


func _test_panel_value_updates() -> bool:
	var panel: Control = HudProgressionPanelScript.new()
	root.add_child(panel)
	panel.ensure_built()
	panel.apply_values(9876, 4, 615, 3, 45)
	var values: Dictionary = panel.get_display_values()
	var expected_progress := float(45) / float(ProgressionConfigScript.xp_required_for_level(3))
	panel.queue_free()
	return (
		int(values.get("coins", 0)) == 9876
		and int(values.get("day", 0)) == 4
		and int(values.get("game_minutes", 0)) == 615
		and int(values.get("level", 0)) == 3
		and int(values.get("xp", 0)) == 45
		and absf(float(values.get("xp_progress", 0.0)) - expected_progress) < 0.02
	)


func _test_hud_update_api() -> bool:
	var hud: Object = HudScript.new()
	return hud.has_method("update_progression") and hud.has_method("sync_from_save_manager")


func _test_save_manager_sync() -> bool:
	var save := _ensure_save_manager()
	save.set_coins(3333)
	save.set_day(7)
	save.set_game_minutes(600)
	save.set_total_xp(ProgressionConfigScript.total_xp_for_level(5) + 25)
	save.set_game_minutes(600)
	var panel: Control = HudProgressionPanelScript.new()
	root.add_child(panel)
	panel.ensure_built()
	panel.bind_progression_sources()
	var values: Dictionary = panel.get_display_values()
	panel.queue_free()
	return (
		int(values.get("coins", 0)) == 3333
		and int(values.get("day", 0)) == 7
		and int(values.get("game_minutes", 0)) == 600
		and int(values.get("level", 0)) == 5
		and int(values.get("xp", 0)) == 25
	)


func _test_reputation_bar() -> bool:
	var panel = HudProgressionPanelScript.new()
	root.add_child(panel)
	panel.ensure_built()
	panel.bind_reputation_manager()
	var slot: Control = panel.get_reputation_slot() as Control
	var bar: Control = panel.get_reputation_bar() as Control
	var values: Dictionary = panel.get_display_values()
	panel.queue_free()
	return (
		slot != null
		and slot.name == "ReputationSlot"
		and slot.custom_minimum_size.x <= 96.0
		and slot.custom_minimum_size.y <= 12.0
		and bar != null
		and bar.name == "ReputationBar"
		and int(values.get("reputation", -1)) == ReputationConfigScript.STARTING_REPUTATION
	)


func _test_touch_button_size() -> bool:
	return GameUIThemeScript.BTN_MIN_HEIGHT_TOUCH >= 44.0


func _find_label_with_text(node: Node, fragment: String) -> bool:
	if node is Label and String(node.text).contains(fragment):
		return true
	for child in node.get_children():
		if _find_label_with_text(child, fragment):
			return true
	return false

