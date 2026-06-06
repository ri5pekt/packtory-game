extends Node

## Reusable end-of-day flow — pause, summarize, continue into the next morning.

signal summary_presented(summary: Dictionary)
signal next_day_begun(day_number: int)

const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")

var _summary_open := false
var _summary_ui: Control


func _ready() -> void:
	add_to_group("day_end_flow")
	call_deferred("_bind_summary_ui")


func is_summary_open() -> bool:
	return _summary_open


func reset_summary_state() -> void:
	_summary_open = false
	_close_summary()


func request_end_day(force: bool = false) -> Dictionary:
	var day_end := _get_day_end()
	if day_end == null:
		return {}
	if not force and day_end.has_method("can_end_day"):
		var state: Dictionary = day_end.can_end_day()
		if not bool(state.get("allowed", false)):
			return {}
	if _summary_open:
		return _get_day_end().get_last_summary() if day_end.has_method("get_last_summary") else {}
	_pause_gameplay()
	var payroll: Dictionary = day_end.end_day(force) if day_end.has_method("end_day") else {}
	var summary := _build_summary(payroll)
	_summary_open = true
	_present_summary(summary)
	summary_presented.emit(summary.duplicate(true))
	return summary.duplicate(true)


func continue_to_next_day() -> void:
	if not _summary_open:
		return
	var game_time := _get_game_time()
	var save := _get_save()
	var next_day := 1
	if game_time:
		next_day = game_time.get_day() + 1
	elif save and save.has_method("get_day"):
		next_day = int(save.get_day()) + 1
	if save and save.has_method("set_day"):
		save.set_day(next_day)
	if game_time:
		game_time.set_time(next_day, GameTimeConfigScript.DAY_START_MINUTES)
		game_time.set_running(false)
	var session := _get_session()
	if session and session.has_method("reset_for_new_day"):
		session.reset_for_new_day()
	var economy := _get_economy()
	if economy and economy.has_method("clear_day_expenses"):
		economy.clear_day_expenses()
	var day_end := _get_day_end()
	if day_end and day_end.has_method("reset_day_clock_for_new_day"):
		day_end.reset_day_clock_for_new_day()
	_close_summary()
	_summary_open = false
	_open_day_start_popup(next_day)
	next_day_begun.emit(next_day)


func _build_summary(payroll: Dictionary) -> Dictionary:
	var tracker := _get_stats_tracker()
	if tracker and tracker.has_method("build_summary"):
		return tracker.build_summary(payroll)
	return payroll.duplicate(true)


func _present_summary(summary: Dictionary) -> void:
	if _summary_ui and _summary_ui.has_method("show_summary"):
		_summary_ui.show_summary(summary)


func _close_summary() -> void:
	if _summary_ui and _summary_ui.has_method("close"):
		_summary_ui.close()


func _open_day_start_popup(day_number: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for popup in tree.get_nodes_in_group("day_start_popup"):
		if popup.has_method("open"):
			popup.open(day_number)
			return


func _pause_gameplay() -> void:
	var game_time := _get_game_time()
	if game_time:
		game_time.set_running(false)


func _bind_summary_ui() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("day_end_summary_ui"):
		_summary_ui = node as Control
		if _summary_ui.has_signal("continue_pressed"):
			if not _summary_ui.continue_pressed.is_connected(_on_summary_continue):
				_summary_ui.continue_pressed.connect(_on_summary_continue)
		return


func _on_summary_continue() -> void:
	continue_to_next_day()


func _get_day_end() -> Node:
	return get_node_or_null("/root/DayEndManager")


func _get_stats_tracker() -> Node:
	return get_node_or_null("/root/DayStatsTracker")


func _get_game_time() -> Node:
	return get_node_or_null("/root/GameTimeManager")


func _get_session() -> Node:
	return get_node_or_null("/root/GameSession")


func _get_save() -> Node:
	return get_node_or_null("/root/SaveManager")


func _get_economy() -> Node:
	return get_node_or_null("/root/EconomyManager")
