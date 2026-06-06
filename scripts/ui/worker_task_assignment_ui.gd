extends Control

## Modal UI for toggling worker task categories after the manager reaches them.

signal closed

const WorkerTaskConfigScript = preload("res://scripts/gameplay/worker_task_config.gd")

const PANEL_BG := Color(0.08, 0.10, 0.14, 0.98)
const ACCENT := Color(0.26, 0.62, 0.92)
const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := Color(0.52, 0.58, 0.68)
const ENABLED_BG := Color(0.18, 0.38, 0.58, 0.95)
const DISABLED_BG := Color(0.12, 0.14, 0.18, 0.82)
const BORDER_ENABLED := Color(0.42, 0.72, 0.96, 0.95)
const BORDER_DISABLED := Color(0.22, 0.26, 0.32, 0.75)
const BTN_MIN_HEIGHT := 52.0

var _open := false
var _worker = null
var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _toggle_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	var viewport := get_viewport()
	if viewport:
		viewport.size_changed.connect(_relayout)
	_relayout()


func is_open() -> bool:
	return _open


func get_target_worker() -> Worker:
	return _worker


func get_toggle_button(category_id: String) -> Button:
	return _toggle_buttons.get(category_id, null) as Button


func is_category_highlighted(category_id: String) -> bool:
	var button: Button = get_toggle_button(category_id)
	return button != null and button.button_pressed


func open_for_worker(worker) -> void:
	if worker == null:
		return
	_worker = worker
	_refresh_title()
	_sync_toggles_from_worker()
	_open = true
	visible = true
	_overlay.visible = true
	_panel.visible = true
	_relayout()


func close() -> void:
	if not _open:
		return
	_open = false
	_worker = null
	visible = false
	_overlay.visible = false
	_panel.visible = false
	closed.emit()


func notify_world_tap(screen_position: Vector2) -> bool:
	if not _open:
		return false
	if _panel.get_global_rect().has_point(screen_position):
		return true
	close()
	return true


func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "DimOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.name = "AssignmentPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = ACCENT.darkened(0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	panel_style.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Assign Worker Tasks"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", TEXT_COLOR)
	header.add_child(_title_label)

	var close_btn := _make_button("Close")
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var hint := Label.new()
	hint.text = "Storage and cleaning run automatically when enabled. Fulfillment is manual for now."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", DIM_TEXT)
	column.add_child(hint)

	for entry in WorkerTaskConfigScript.categories():
		var category_id := String(entry.get("id", ""))
		var label := String(entry.get("label", category_id))
		var toggle := _make_task_toggle(category_id, label)
		_toggle_buttons[category_id] = toggle
		column.add_child(toggle)


func _make_task_toggle(category_id: String, label: String) -> Button:
	var button := Button.new()
	button.name = "TaskToggle_%s" % category_id
	button.toggle_mode = true
	button.text = label
	button.custom_minimum_size = Vector2(0.0, BTN_MIN_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggled.connect(func(enabled: bool) -> void:
		if _worker != null and _worker.has_method("set_task_enabled"):
			_worker.set_task_enabled(category_id, enabled)
		_style_toggle(button, enabled)
	)
	_style_toggle(button, false)
	return button


func _style_toggle(button: Button, enabled: bool) -> void:
	var bg := ENABLED_BG if enabled else DISABLED_BG
	var border := BORDER_ENABLED if enabled else BORDER_DISABLED
	var font := TEXT_COLOR if enabled else DIM_TEXT
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", sb)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.lightened(0.08)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("focus", sb)
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_pressed_color", font)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96.0, 40.0)
	button.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.20, 0.28, 0.95)
	sb.border_color = ACCENT.darkened(0.15)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	button.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.28, 0.38, 0.98)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	return button


func _refresh_title() -> void:
	if _title_label == null:
		return
	var worker_name := "Worker"
	if _worker != null and _worker.has_method("get_display_name"):
		worker_name = String(_worker.get_display_name())
	_title_label.text = "Assign tasks — %s" % worker_name


func _sync_toggles_from_worker() -> void:
	if _worker == null:
		return
	var tasks: Dictionary = _worker.get_task_assignments() if _worker.has_method("get_task_assignments") else {}
	for category_id in _toggle_buttons:
		var button: Button = _toggle_buttons[category_id]
		var enabled := bool(tasks.get(category_id, false))
		button.set_block_signals(true)
		button.button_pressed = enabled
		button.set_block_signals(false)
		_style_toggle(button, enabled)


func _relayout() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport_rect().size
	_overlay.set_size(viewport_size)
	var panel_width := clampf(viewport_size.x * 0.42, 320.0, 460.0)
	var panel_height := clampf(viewport_size.y * 0.55, 300.0, 420.0)
	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_panel.position = (viewport_size - _panel.custom_minimum_size) * 0.5
