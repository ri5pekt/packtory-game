extends Node

## Accelerated in-game clock — future systems (spawns, deliveries, salaries, lighting) should read time here.

signal time_changed(game_minutes: int, day: int)
signal minute_advanced(game_minutes: int, day: int)

const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")

var _day := GameTimeConfigScript.STARTING_DAY
var _minutes_precise: float = GameTimeConfigScript.DAY_START_MINUTES
var _game_minutes_per_real_second := GameTimeConfigScript.DEFAULT_GAME_MINUTES_PER_REAL_SECOND
var _running := false
var _last_emitted_minute := -1


func _ready() -> void:
	call_deferred("_bind_game_session")


func _process(delta: float) -> void:
	tick_real_seconds(delta)


func tick_real_seconds(real_seconds: float) -> int:
	if not _running or real_seconds <= 0.0:
		return 0
	return advance_by_real_seconds(real_seconds)


func reset_for_new_game() -> void:
	_day = GameTimeConfigScript.STARTING_DAY
	_minutes_precise = float(GameTimeConfigScript.DAY_START_MINUTES)
	_game_minutes_per_real_second = GameTimeConfigScript.DEFAULT_GAME_MINUTES_PER_REAL_SECOND
	_running = false
	_last_emitted_minute = get_game_minutes()
	time_changed.emit(get_game_minutes(), _day)


func get_day() -> int:
	return _day


func set_day(value: int) -> void:
	_day = maxi(1, value)
	_emit_time()


func get_game_minutes() -> int:
	return GameTimeConfigScript.clamp_minutes_int(int(floor(_minutes_precise)))


func get_precise_minutes() -> float:
	return _minutes_precise


func set_game_minutes(value: int) -> void:
	_minutes_precise = GameTimeConfigScript.clamp_minutes(float(value))
	_emit_time()


func set_time(day: int, minutes: int) -> void:
	_day = maxi(1, day)
	_minutes_precise = GameTimeConfigScript.clamp_minutes(float(minutes))
	_emit_time()


func get_time_scale() -> float:
	return _game_minutes_per_real_second


func set_time_scale(game_minutes_per_real_second: float) -> void:
	_game_minutes_per_real_second = maxf(0.0, game_minutes_per_real_second)


func is_running() -> bool:
	return _running


func set_running(running: bool) -> void:
	_running = running


func format_time() -> String:
	return GameTimeConfigScript.format_clock(get_game_minutes())


func real_seconds_for_game_minutes(game_minutes: float) -> float:
	if _game_minutes_per_real_second <= 0.0:
		return 0.0
	return game_minutes / _game_minutes_per_real_second


func game_minutes_for_real_seconds(real_seconds: float) -> float:
	return real_seconds * _game_minutes_per_real_second


func advance_by_real_seconds(real_seconds: float) -> int:
	if real_seconds <= 0.0 or _game_minutes_per_real_second <= 0.0:
		return 0
	var before := get_game_minutes()
	_minutes_precise = GameTimeConfigScript.clamp_minutes(
		_minutes_precise + game_minutes_for_real_seconds(real_seconds)
	)
	_emit_time()
	return get_game_minutes() - before


func advance_by_game_minutes(game_minutes: float) -> int:
	return advance_by_real_seconds(real_seconds_for_game_minutes(game_minutes))


func _emit_time() -> void:
	var minute := get_game_minutes()
	time_changed.emit(minute, _day)
	if minute != _last_emitted_minute:
		_last_emitted_minute = minute
		minute_advanced.emit(minute, _day)


func _bind_game_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	if session.is_gameplay_active():
		_running = true
	elif session.has_signal("day_started"):
		session.day_started.connect(_on_day_started)


func _on_day_started() -> void:
	_running = true
