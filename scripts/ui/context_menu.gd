extends VBoxContainer

## Floating context menu. Actions: {"id", "label"}; optional "quantity" picker.
## Icons load from assets/ui/icons/{id}.png via IconRegistry.

signal action_selected(id: String, quantity: int)

const ROW_HEIGHT := 44.0
const COMPACT_ROW_HEIGHT := 32.0
const ROW_GAP := 4.0
const BASE_WIDTH := 168.0
const COMPACT_WIDTH := 112.0
const QUANTITY_ROW_WIDTH := 260.0
const ICON_SIZE := 22
const COMPACT_ICON_SIZE := 18

var _quantity_values: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_actions(screen_position: Vector2, actions: Array) -> void:
	_quantity_values.clear()
	for child in get_children():
		child.queue_free()

	var compact := _is_compact_menu(actions)
	var row_height := COMPACT_ROW_HEIGHT if compact else ROW_HEIGHT
	var menu_width := COMPACT_WIDTH if compact else BASE_WIDTH
	for action in actions:
		if action.has("quantity"):
			compact = false
			row_height = ROW_HEIGHT
			menu_width = maxf(menu_width, QUANTITY_ROW_WIDTH)
		add_child(_build_action_row(action, row_height, compact, menu_width))

	var menu_height := actions.size() * row_height
	if actions.size() > 1:
		menu_height += (actions.size() - 1) * ROW_GAP

	custom_minimum_size = Vector2(menu_width, menu_height)
	size = custom_minimum_size

	var viewport_size := get_viewport().get_visible_rect().size
	global_position = Vector2(
		clampf(screen_position.x, 8.0, viewport_size.x - menu_width - 8.0),
		clampf(screen_position.y, 8.0, viewport_size.y - menu_height - 8.0)
	)
	show()


func _is_compact_menu(actions: Array) -> bool:
	if actions.size() != 1:
		return false
	var action: Variant = actions[0]
	return action is Dictionary and not action.has("quantity")


func hide_menu() -> void:
	hide()


func _build_action_row(
	action: Dictionary,
	row_height: float,
	compact: bool,
	menu_width: float
) -> Control:
	var id: String = action["id"]
	if not action.has("quantity"):
		return _build_plain_button(id, action["label"], row_height, compact, menu_width)

	var qty_cfg: Dictionary = action["quantity"]
	var min_q: int = maxi(1, int(qty_cfg.get("min", 1)))
	var max_q: int = maxi(min_q, int(qty_cfg.get("max", min_q)))
	var current: int = clampi(int(qty_cfg.get("default", 1)), min_q, max_q)
	_quantity_values[id] = current

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(menu_width, row_height)
	row.add_theme_constant_override("separation", 6)

	var button := _make_action_button(id, action["label"], row_height, compact, menu_width)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: action_selected.emit(id, _quantity_values[id]))
	row.add_child(button)
	row.add_child(_build_quantity_picker(id, min_q, max_q, current))
	return row


func _build_plain_button(
	id: String,
	label: String,
	row_height: float,
	compact: bool,
	menu_width: float
) -> Button:
	var button := _make_action_button(id, label, row_height, compact, menu_width)
	button.pressed.connect(func() -> void: action_selected.emit(id, 1))
	return button


func _make_action_button(
	id: String,
	label: String,
	row_height: float,
	compact: bool,
	menu_width: float
) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(menu_width, row_height)
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_color_override("font_color", Color(0.94, 0.96, 0.99))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.88, 0.92, 0.98))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.22, 0.30, 0.92)
	sb.border_color = Color(0.38, 0.44, 0.54, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	var margin_h := 6 if compact else 8
	var margin_v := 2 if compact else 4
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	button.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.26, 0.32, 0.42, 0.98)
	button.add_theme_stylebox_override("hover", hov)
	button.add_theme_stylebox_override("pressed", hov)
	button.add_theme_stylebox_override("focus", sb)
	var icon := IconRegistry.action_icon(id)
	if icon:
		button.icon = icon
		var icon_size := COMPACT_ICON_SIZE if compact else ICON_SIZE
		button.add_theme_constant_override("icon_max_width", icon_size)
		button.add_theme_constant_override("icon_max_height", icon_size)
	if compact:
		button.add_theme_font_size_override("font_size", 14)
	return button


func _build_quantity_picker(id: String, min_q: int, max_q: int, start: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(28, 28)
	minus.focus_mode = Control.FOCUS_NONE

	var value := Label.new()
	value.text = str(start)
	value.custom_minimum_size = Vector2(22, 28)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(28, 28)
	plus.focus_mode = Control.FOCUS_NONE

	minus.disabled = start <= min_q
	plus.disabled = start >= max_q

	minus.pressed.connect(func() -> void:
		_adjust_quantity(id, -1, min_q, max_q, value, minus, plus)
	)
	plus.pressed.connect(func() -> void:
		_adjust_quantity(id, 1, min_q, max_q, value, minus, plus)
	)

	box.add_child(minus)
	box.add_child(value)
	box.add_child(plus)
	return box


func _adjust_quantity(
	id: String,
	delta: int,
	min_q: int,
	max_q: int,
	value_label: Label,
	minus: Button,
	plus: Button
) -> void:
	var next := clampi(int(_quantity_values.get(id, 1)) + delta, min_q, max_q)
	_quantity_values[id] = next
	value_label.text = str(next)
	minus.disabled = next <= min_q
	plus.disabled = next >= max_q
