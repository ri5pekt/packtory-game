extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/reputation_test.gd

const HudProgressionPanelScript = preload("res://scripts/ui/hud_progression_panel.gd")
const ReputationBarDisplayScript = preload("res://scripts/ui/reputation_bar_display.gd")
const ReputationConfigScript = preload("res://scripts/gameplay/reputation_config.gd")
const ReputationManagerScript = preload("res://scripts/gameplay/reputation_manager.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_reputation_manager()
	var failed := 0
	failed += _assert("new game starts at configured reputation", _test_new_game_defaults())
	failed += _assert("reduce_reputation lowers value", _test_reduce_reputation())
	failed += _assert("add_reputation raises value", _test_add_reputation())
	failed += _assert("reputation clamps at bounds", _test_reputation_clamps())
	failed += _assert("reputation bar appears below XP row", _test_bar_appears())
	failed += _assert("panel updates when reputation changes", _test_panel_updates())
	failed += _assert("bar fill ratio matches reputation", _test_bar_ratio_updates())

	if failed == 0:
		print("reputation_test: ALL PASSED")
		quit(0)
	else:
		push_error("reputation_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_reputation_manager() -> Node:
	var existing := root.get_node_or_null("ReputationManager")
	if existing:
		return existing
	var reputation: Node = ReputationManagerScript.new()
	reputation.name = "ReputationManager"
	root.add_child(reputation)
	return reputation


func _reputation() -> Node:
	return root.get_node("ReputationManager")


func _test_new_game_defaults() -> bool:
	_reputation().reset_for_new_game()
	return _reputation().get_reputation() == ReputationConfigScript.STARTING_REPUTATION


func _test_reduce_reputation() -> bool:
	_reputation().reset_for_new_game()
	var changed: int = _reputation().reduce_reputation(15)
	return changed == -15 and _reputation().get_reputation() == 85


func _test_add_reputation() -> bool:
	_reputation().reset_for_new_game()
	_reputation().reduce_reputation(30)
	var changed: int = _reputation().add_reputation(10)
	return changed == 10 and _reputation().get_reputation() == 80


func _test_reputation_clamps() -> bool:
	_reputation().reset_for_new_game()
	_reputation().reduce_reputation(500)
	var low: bool = _reputation().get_reputation() == ReputationConfigScript.MIN_REPUTATION
	_reputation().add_reputation(500)
	var high: bool = _reputation().get_reputation() == ReputationConfigScript.MAX_REPUTATION
	return low and high


func _test_bar_appears() -> bool:
	var panel: Control = HudProgressionPanelScript.new()
	root.add_child(panel)
	panel.ensure_built()
	var slot: Control = panel.get_reputation_slot() as Control
	var bar: Control = panel.get_reputation_bar() as Control
	var ok := (
		slot != null
		and bar != null
		and bar.name == "ReputationBar"
		and bar.get_parent() == slot
		and bar.find_child("Track", true, false) != null
		and bar.find_child("Fill", true, false) != null
	)
	panel.queue_free()
	return ok


func _test_panel_updates() -> bool:
	_reputation().reset_for_new_game()
	var panel: Control = HudProgressionPanelScript.new()
	root.add_child(panel)
	panel.ensure_built()
	panel.bind_reputation_manager()
	_reputation().reduce_reputation(25)
	var values: Dictionary = panel.get_display_values()
	panel.queue_free()
	return int(values.get("reputation", -1)) == 75


func _test_bar_ratio_updates() -> bool:
	_reputation().reset_for_new_game()
	var bar: Control = ReputationBarDisplayScript.new()
	root.add_child(bar)
	bar.set_reputation(50)
	var ratio: float = bar.get_ratio()
	bar.queue_free()
	return absf(ratio - 0.5) < 0.02
