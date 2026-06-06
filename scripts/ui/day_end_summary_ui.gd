extends Control

## End-of-day summary modal — stats review before the next morning.

signal continue_pressed

const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")

const PANEL_BG := Color(0.08, 0.10, 0.14, 0.98)
const ACCENT := GameUIThemeScript.ACCENT
const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := GameUIThemeScript.DIM_TEXT
const POSITIVE := Color(0.45, 0.82, 0.58)
const NEGATIVE := Color(0.92, 0.42, 0.36)
const BTN_MIN_HEIGHT := 52.0

var _open := false
var _built := false
var _overlay: ColorRect
var _panel: PanelContainer
var _stats_list: VBoxContainer
var _title_label: Label


func _ready() -> void:
	add_to_group("day_end_summary_ui")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 85
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


func show_summary(summary: Dictionary) -> void:
	ensure_built()
	_open = true
	visible = true
	_overlay.visible = true
	_panel.visible = true
	_populate_stats(summary)
	_relayout()


func close() -> void:
	ensure_built()
	if not _open:
		return
	_open = false
	visible = false
	_overlay.visible = false
	_panel.visible = false


func notify_world_tap(_screen_position: Vector2) -> bool:
	return _open


func get_stat_text(label: String) -> String:
	if _stats_list == null:
		return ""
	for row in _stats_list.get_children():
		if row is HBoxContainer and row.get_child_count() >= 2:
			var name_lbl := row.get_child(0) as Label
			var value_lbl := row.get_child(1) as Label
			if name_lbl and name_lbl.text == label and value_lbl:
				return value_lbl.text
	return ""


func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", TEXT_COLOR)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title_label)

	var subtitle := Label.new()
	subtitle.text = "Daily results"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", DIM_TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(subtitle)

	_stats_list = VBoxContainer.new()
	_stats_list.name = "StatsList"
	_stats_list.add_theme_constant_override("separation", 6)
	col.add_child(_stats_list)

	var continue_btn := Button.new()
	continue_btn.name = "ContinueButton"
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(0.0, BTN_MIN_HEIGHT)
	continue_btn.pressed.connect(_on_continue_pressed)
	_style_button(continue_btn)
	col.add_child(continue_btn)


func _populate_stats(summary: Dictionary) -> void:
	for child in _stats_list.get_children():
		child.queue_free()
	var day := int(summary.get("day", 1))
	if _title_label:
		_title_label.text = "Day %d Complete" % day
	_add_stat_row("In-person orders", str(int(summary.get("in_person_orders", 0))))
	_add_stat_row("Online orders", str(int(summary.get("online_orders", 0))))
	_add_stat_row("Total earnings", _money(int(summary.get("total_earnings", 0))), POSITIVE)
	_add_stat_row("Delivery expenses", _money(-int(summary.get("delivery_expenses", 0))), NEGATIVE)
	_add_stat_row("Worker salaries", _money(-int(summary.get("worker_salaries", 0))), NEGATIVE)
	_add_stat_row("Net profit", _money(int(summary.get("net_profit", 0))), _profit_color(int(summary.get("net_profit", 0))))
	if summary.has("reputation_delta"):
		var delta := int(summary.get("reputation_delta", 0))
		var rep_text := "%+d (%d → %d)" % [
			delta,
			int(summary.get("reputation_start", 0)),
			int(summary.get("reputation_end", 0)),
		]
		_add_stat_row("Reputation", rep_text, _profit_color(delta))
	_add_stat_row("Ending balance", _money(int(summary.get("ending_balance", 0))))


func _add_stat_row(label_text: String, value_text: String, value_color: Color = TEXT_COLOR) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", DIM_TEXT)
	row.add_child(name_lbl)
	var value_lbl := Label.new()
	value_lbl.text = value_text
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_lbl.add_theme_font_size_override("font_size", 14)
	value_lbl.add_theme_color_override("font_color", value_color)
	row.add_child(value_lbl)
	_stats_list.add_child(row)


func _money(amount: int) -> String:
	if amount < 0:
		return "-$%d" % absi(amount)
	return "$%d" % amount


func _profit_color(value: int) -> Color:
	if value > 0:
		return POSITIVE
	if value < 0:
		return NEGATIVE
	return TEXT_COLOR


func _on_continue_pressed() -> void:
	continue_pressed.emit()


func _style_button(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.55, 0.34, 0.95)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.64, 0.40, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 17)


func _relayout() -> void:
	if _panel == null or not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(mini(500.0, vp.x - 48.0), 0.0)
	_panel.position = Vector2(
		(vp.x - _panel.size.x) * 0.5,
		(vp.y - _panel.size.y) * 0.38
	)
