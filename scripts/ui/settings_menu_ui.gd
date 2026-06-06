extends Control

## Slide-in settings panel with reusable options and End Day action.

signal closed
signal end_day_requested

const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")
const SettingsMenuConfigScript = preload("res://scripts/gameplay/settings_menu_config.gd")
const SettingsOptionsAreaScript = preload("res://scripts/ui/settings_options_area.gd")

const PANEL_BG := Color(0.08, 0.10, 0.14, 0.98)
const ACCENT := GameUIThemeScript.ACCENT
const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := GameUIThemeScript.DIM_TEXT
const PANEL_WIDTH := 300.0
const SLIDE_SEC := 0.22

var _open := false
var _built := false
var _overlay: ColorRect
var _panel: PanelContainer
var _options_area: VBoxContainer
var _end_day_button: Button
var _status_label: Label
var _slide_tween: Tween


func _ready() -> void:
	add_to_group("settings_menu")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ensure_built()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_relayout):
		viewport.size_changed.connect(_relayout)
	visible = false


func ensure_built() -> void:
	if _built:
		return
	_built = true
	_build()


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	ensure_built()
	_open = true
	visible = true
	_overlay.visible = true
	_panel.visible = true
	_refresh_end_day_state()
	_relayout()
	_animate_open()


func close() -> void:
	ensure_built()
	if not _open:
		return
	_open = false
	if _slide_tween:
		_slide_tween.kill()
	var hidden_x := _panel_hidden_x()
	_slide_tween = create_tween()
	_slide_tween.tween_property(_panel, "position:x", hidden_x, SLIDE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_slide_tween.tween_callback(_finish_close)


func notify_world_tap(screen_position: Vector2) -> bool:
	if not _open:
		return false
	if _panel.get_global_rect().has_point(screen_position):
		return true
	close()
	return true


func refresh_end_day_state() -> void:
	_refresh_end_day_state()


func is_end_day_enabled() -> bool:
	return _end_day_button != null and not _end_day_button.disabled


func is_evening_reminder_visible() -> bool:
	var hint: Control = _options_area.get_row("evening_reminder") if _options_area else null
	return hint is Label and (hint as Label).visible


func _finish_close() -> void:
	visible = false
	_overlay.visible = false
	_panel.visible = false
	closed.emit()


func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "DimOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.35)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.name = "SettingsPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = ACCENT.darkened(0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", 14)
	margin.add_child(root_col)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_col.add_child(title_row)

	var title := Label.new()
	title.text = "Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.tooltip_text = "Close"
	close_btn.custom_minimum_size = Vector2(40.0, 40.0)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(close)
	title_row.add_child(close_btn)

	_options_area = SettingsOptionsAreaScript.new()
	_options_area.name = "OptionsArea"
	root_col.add_child(_options_area)

	_end_day_button = _options_area.add_action_button("end_day", "End Day")
	_end_day_button.pressed.connect(_on_end_day_pressed)

	_status_label = _options_area.add_hint_label("end_day_status", "")
	_status_label.visible = false

	var evening_hint = _options_area.add_hint_label(
		"evening_reminder",
		SettingsMenuConfigScript.EVENING_REMINDER_TEXT
	)
	if evening_hint:
		evening_hint.visible = false


func _on_overlay_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			close()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			close()
			get_viewport().set_input_as_handled()


func _on_end_day_pressed() -> void:
	var flow := get_node_or_null("/root/DayEndFlow")
	if flow != null and flow.has_method("request_end_day"):
		flow.request_end_day()
	end_day_requested.emit()
	close()


func _refresh_end_day_state() -> void:
	var day_end := get_node_or_null("/root/DayEndManager")
	var state := {"allowed": false, "reason": "", "show_evening_reminder": false}
	if day_end != null and day_end.has_method("can_end_day"):
		state = day_end.can_end_day()
	var allowed: bool = bool(state.get("allowed", false))
	var reason := String(state.get("reason", ""))
	var show_reminder: bool = bool(state.get("show_evening_reminder", false))
	_options_area.set_action_enabled("end_day", allowed)
	_options_area.set_hint_visible("end_day_status", not allowed and reason != "", reason)
	_options_area.set_hint_visible(
		"evening_reminder",
		show_reminder,
		SettingsMenuConfigScript.EVENING_REMINDER_TEXT
	)


func _animate_open() -> void:
	if _slide_tween:
		_slide_tween.kill()
	_position_panel_hidden()
	_slide_tween = create_tween()
	_slide_tween.tween_property(_panel, "position:x", _panel_open_x(), SLIDE_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _relayout() -> void:
	if _overlay:
		_overlay.set_size(get_viewport_rect().size)
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, vp.y)
	_panel.size = Vector2(PANEL_WIDTH, vp.y)
	_panel.position = Vector2(
		_panel_open_x() if _open else _panel_hidden_x(),
		0.0
	)


func _panel_open_x() -> float:
	return maxf(0.0, get_viewport_rect().size.x - PANEL_WIDTH)


func _panel_hidden_x() -> float:
	return get_viewport_rect().size.x


func _position_panel_hidden() -> void:
	_panel.position = Vector2(_panel_hidden_x(), 0.0)
