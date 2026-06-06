extends Node

## Tracks whether the player has acknowledged the day-start welcome popup.

signal day_started

var is_day_started := false


func reset_for_new_day() -> void:
	is_day_started = false


func acknowledge_day_start() -> void:
	if is_day_started:
		return
	is_day_started = true
	day_started.emit()


func is_gameplay_active() -> bool:
	return is_day_started


func restore_started_state() -> void:
	if is_day_started:
		return
	is_day_started = true
	day_started.emit()
