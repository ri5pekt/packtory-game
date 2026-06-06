extends VBoxContainer

## Reusable settings options list for action buttons and hint labels.

const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")

const DIM_TEXT := GameUIThemeScript.DIM_TEXT
const TEXT_COLOR := Color(0.92, 0.95, 0.98)

var _rows: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_row(option_id: String) -> Control:
	return _rows.get(option_id, null) as Control


func add_action_button(option_id: String, label_text: String) -> Button:
	var button := _make_button(label_text)
	button.name = "Option_%s" % option_id
	add_child(button)
	_rows[option_id] = button
	return button


func add_hint_label(option_id: String, label_text: String) -> Label:
	var label := Label.new()
	label.name = "Hint_%s" % option_id
	label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", DIM_TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_rows[option_id] = label
	return label


func set_hint_visible(option_id: String, visible: bool, text: String = "") -> void:
	var row: Control = get_row(option_id)
	if row == null or not row is Label:
		return
	var label := row as Label
	if text != "":
		label.text = text
	label.visible = visible


func set_action_enabled(option_id: String, enabled: bool) -> void:
	var row: Control = get_row(option_id)
	if row == null or not row is Button:
		return
	(row as Button).disabled = not enabled


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, GameUIThemeScript.BTN_MIN_HEIGHT_TOUCH)
	button.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.38, 0.58, 0.95)
	normal.border_color = Color(0.42, 0.72, 0.96, 0.95)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)
	button.add_theme_stylebox_override("normal", normal)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.14, 0.16, 0.20, 0.75)
	disabled.border_color = Color(0.24, 0.28, 0.34, 0.75)
	button.add_theme_stylebox_override("disabled", disabled)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.44, 0.66, 0.98)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", DIM_TEXT)
	button.add_theme_font_size_override("font_size", 15)
	return button
