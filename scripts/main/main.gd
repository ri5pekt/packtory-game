extends Node

@onready var touch_input: Node = $TouchInput
@onready var camera_rig: Node3D = $IsoCameraRig
@onready var _day_start_popup: Control = $UI/DayStartPopup
@onready var _level_up_popup: Control = $UI/LevelUpPopup
@onready var _product_unlock_popup: Control = $UI/ProductUnlockPopup


func _ready() -> void:
	touch_input.pan_drag.connect(camera_rig.pan_screen_delta)
	touch_input.zoom.connect(camera_rig.zoom_by)
	touch_input.reset_view_requested.connect(camera_rig.reset_view)
	var save := get_node_or_null("/root/SaveManager")
	if save and save.has_method("is_loading_save") and save.is_loading_save():
		call_deferred("_apply_loaded_game")
	else:
		_begin_new_day()
	call_deferred("_bind_progression_popups")


func _begin_new_day() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session and session.has_method("reset_for_new_day"):
		session.reset_for_new_day()
	var day_number := 1
	var save := get_node_or_null("/root/SaveManager")
	if save and save.has_method("get_day"):
		day_number = save.get_day()
	if _day_start_popup and _day_start_popup.has_method("open"):
		_day_start_popup.open(day_number)


func _apply_loaded_game() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var save := get_node_or_null("/root/SaveManager")
	if save and save.has_method("apply_to_scene"):
		save.apply_to_scene(get_tree())
	var session := get_node_or_null("/root/GameSession")
	if session and session.has_method("is_gameplay_active") and session.is_gameplay_active():
		var game_time := get_node_or_null("/root/GameTimeManager")
		var pending: Dictionary = save.get_pending_data() if save else {}
		var session_data: Dictionary = pending.get("session", {})
		if game_time and bool(session_data.get("time_running", false)):
			game_time.set_running(true)
		return
	var day_number := 1
	if save and save.has_method("get_day"):
		day_number = save.get_day()
	if _day_start_popup and _day_start_popup.has_method("open"):
		_day_start_popup.open(day_number)


func _bind_progression_popups() -> void:
	var progression := get_node_or_null("/root/ProgressionManager")
	if progression and _level_up_popup:
		if not progression.levels_gained.is_connected(_level_up_popup.enqueue_levels):
			progression.levels_gained.connect(_level_up_popup.enqueue_levels)
	var unlocks := get_node_or_null("/root/UnlockManager")
	if unlocks and _product_unlock_popup:
		if not unlocks.unlock_popup_requested.is_connected(_product_unlock_popup.show_unlock):
			unlocks.unlock_popup_requested.connect(_product_unlock_popup.show_unlock)
		if unlocks.has_method("sync_unlock_popups_for_level"):
			var level := 0
			if progression and progression.has_method("get_level"):
				level = progression.get_level()
			unlocks.sync_unlock_popups_for_level(level)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST and what != NOTIFICATION_APPLICATION_PAUSED:
		return
	var save := get_node_or_null("/root/SaveManager")
	if save and save.has_method("save_current_scene"):
		save.save_current_scene(get_tree())
