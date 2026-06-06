extends Node

## End-of-day processing — payroll and expense records for daily summaries.

signal day_ended(summary: Dictionary)

const PayrollServiceScript = preload("res://scripts/gameplay/payroll_service.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")
const SettingsMenuConfigScript = preload("res://scripts/gameplay/settings_menu_config.gd")

var _payroll_settled_day := -1
var _last_summary: Dictionary = {}
var _last_checked_minute := -1


func _ready() -> void:
	add_to_group("day_end_manager")
	call_deferred("_bind_game_time")


func reset_for_new_game() -> void:
	_payroll_settled_day = -1
	_last_summary = {}
	_last_checked_minute = -1
	var economy := _get_economy()
	if economy != null and economy.has_method("clear_day_expenses"):
		economy.clear_day_expenses()


func get_payroll_settled_day() -> int:
	return _payroll_settled_day


func get_last_summary() -> Dictionary:
	return _last_summary.duplicate(true)


func export_save_state() -> Dictionary:
	return {
		"payroll_settled_day": _payroll_settled_day,
		"last_checked_minute": _last_checked_minute,
		"last_summary": _last_summary.duplicate(true),
	}


func apply_save_state(data: Dictionary) -> void:
	_payroll_settled_day = int(data.get("payroll_settled_day", -1))
	_last_checked_minute = int(data.get("last_checked_minute", -1))
	_last_summary = data.get("last_summary", {}).duplicate(true)


func is_payroll_settled_for_day(day: int) -> bool:
	return _payroll_settled_day == day


func can_end_day() -> Dictionary:
	var session := _get_game_session()
	if session == null or not session.is_gameplay_active():
		return _end_day_state(
			false,
			SettingsMenuConfigScript.REASON_GAME_NOT_STARTED,
			false
		)
	var day := _get_game_day()
	if _payroll_settled_day == day:
		return _end_day_state(
			false,
			SettingsMenuConfigScript.REASON_ALREADY_ENDED,
			false
		)
	var minutes := _get_game_minutes()
	if minutes < SettingsMenuConfigScript.END_DAY_AVAILABLE_FROM_MINUTES:
		return _end_day_state(
			false,
			SettingsMenuConfigScript.REASON_TOO_EARLY,
			false
		)
	var show_reminder := (
		minutes >= SettingsMenuConfigScript.EVENING_REMINDER_FROM_MINUTES
		and minutes < float(GameTimeConfigScript.STORE_CLOSE_MINUTES)
	)
	return _end_day_state(true, "", show_reminder)


func end_day(force: bool = false) -> Dictionary:
	var day := _get_game_day()
	if not force and _payroll_settled_day == day:
		return _last_summary.duplicate(true)
	var summary := _process_payroll(day)
	_payroll_settled_day = day
	_last_summary = summary
	day_ended.emit(summary.duplicate(true))
	if bool(summary.get("went_negative", false)):
		_warn_insufficient_funds(int(summary.get("ending_balance", 0)))
	return summary.duplicate(true)


func _process_payroll(day: int) -> Dictionary:
	var economy := _get_economy()
	var tree := get_tree()
	var entries: Array = PayrollServiceScript.collect_payroll_entries(tree)
	var starting_balance := int(economy.get_coins()) if economy else 0
	var charged_entries: Array = []
	var total_charged := 0

	if economy != null:
		for entry in entries:
			if not entry is Dictionary:
				continue
			var worker_id := String(entry.get("worker_id", ""))
			var display_name := String(entry.get("display_name", "Worker"))
			var salary := int(entry.get("daily_salary", 0))
			if salary <= 0:
				continue
			var result: Dictionary = economy.charge_expense(
				salary,
				"salary:%s" % worker_id,
				economy.get_expense_category_salary(),
				{
					"worker_id": worker_id,
					"display_name": display_name,
					"day": day,
				}
			)
			var charged := int(result.get("charged", 0))
			total_charged += charged
			charged_entries.append({
				"worker_id": worker_id,
				"display_name": display_name,
				"daily_salary": salary,
				"charged": charged,
			})

	var ending_balance := int(economy.get_coins()) if economy else starting_balance - total_charged
	return {
		"day": day,
		"starting_balance": starting_balance,
		"total_salary": total_charged,
		"ending_balance": ending_balance,
		"went_negative": ending_balance < 0,
		"worker_entries": charged_entries,
		"expenses": economy.get_day_expenses() if economy else [],
	}


func _bind_game_time() -> void:
	var game_time := _get_game_time()
	if game_time == null:
		return
	if game_time.has_signal("minute_advanced"):
		if not game_time.minute_advanced.is_connected(_on_minute_advanced):
			game_time.minute_advanced.connect(_on_minute_advanced)


func _on_minute_advanced(minutes: int, day: int) -> void:
	if _payroll_settled_day == day:
		_last_checked_minute = minutes
		return
	if minutes >= GameTimeConfigScript.STORE_CLOSE_MINUTES \
			and _last_checked_minute < GameTimeConfigScript.STORE_CLOSE_MINUTES:
		_request_end_day_flow()
	_last_checked_minute = minutes


func reset_day_clock_for_new_day() -> void:
	_last_checked_minute = -1


func _request_end_day_flow() -> void:
	var flow := get_node_or_null("/root/DayEndFlow")
	if flow and flow.has_method("request_end_day"):
		flow.request_end_day(true)
		return
	end_day()


func _warn_insufficient_funds(balance: int) -> void:
	var alerts := get_node_or_null("/root/AlertMessages")
	if alerts != null and alerts.has_method("warn"):
		alerts.warn("Payroll pushed your balance negative (%d coins)." % balance)


func _get_game_day() -> int:
	var game_time := _get_game_time()
	return game_time.get_day() if game_time else 1


func _get_game_time() -> Node:
	return get_node_or_null("/root/GameTimeManager")


func _get_game_session() -> Node:
	return get_node_or_null("/root/GameSession")


func _get_game_minutes() -> float:
	var game_time := _get_game_time()
	if game_time == null:
		return float(GameTimeConfigScript.DAY_START_MINUTES)
	return game_time.get_precise_minutes()


func _end_day_state(allowed: bool, reason: String, show_evening_reminder: bool) -> Dictionary:
	return {
		"allowed": allowed,
		"reason": reason,
		"show_evening_reminder": show_evening_reminder,
	}


func _get_economy() -> Node:
	return get_node_or_null("/root/EconomyManager")
