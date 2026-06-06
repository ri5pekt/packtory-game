extends Node

## Reusable reputation tracking — display now; future customer volume, fees, specials.

signal reputation_changed(new_value: int, delta: int, ratio: float)

const ReputationConfigScript = preload("res://scripts/gameplay/reputation_config.gd")

var _reputation := ReputationConfigScript.STARTING_REPUTATION


func reset_for_new_game() -> void:
	_reputation = ReputationConfigScript.STARTING_REPUTATION
	_emit(0)


func get_reputation() -> int:
	return _reputation


func get_ratio() -> float:
	return ReputationConfigScript.ratio_for_value(_reputation)


func set_reputation(value: int) -> void:
	var next := ReputationConfigScript.clamp_reputation(value)
	var delta := next - _reputation
	_reputation = next
	if delta != 0:
		_emit(delta)


func add_reputation(amount: int) -> int:
	if amount <= 0:
		return 0
	return change_reputation(amount)


func reduce_reputation(amount: int) -> int:
	if amount <= 0:
		return 0
	return change_reputation(-amount)


func change_reputation(delta: int) -> int:
	if delta == 0:
		return 0
	var before := _reputation
	set_reputation(_reputation + delta)
	return _reputation - before


func _emit(delta: int) -> void:
	reputation_changed.emit(_reputation, delta, get_ratio())
