extends PanelContainer

## Floating context menu. Actions: {"id", "label"}; optional "quantity" picker.
## Icons load from assets/ui/icons/{id}.png via IconRegistry.

signal action_selected(id: String, quantity: int)

const ROW_HEIGHT := 36.0
const ROW_GAP := 4.0
const PANEL_PADDING := 12.0
const BASE_WIDTH := 168.0
const QUANTITY_ROW_WIDTH := 260.0
const ICON_SIZE := 22

var _quantity_values: Dictionary = {}

@onready var _actions: VBoxContainer = $Actions


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_actions(screen_position: Vector2, actions: Array) -> void:
	_quantity_values.clear()
	for child in _actions.get_children():
		child.queue_free()

	var menu_width := BASE_WIDTH
	for action in actions:
		if action.has("quantity"):
			menu_width = maxf(menu_width, QUANTITY_ROW_WIDTH)
		_actions.add_child(_build_action_row(action))

	custom_minimum_size.x = menu_width
	var menu_height := PANEL_PADDING + actions.size() * ROW_HEIGHT
	if actions.size() > 1:
		menu_height += (actions.size() - 1) * ROW_GAP

	var viewport_size := get_viewport().get_visible_rect().size
	global_position = Vector2(
		clampf(screen_position.x, 8.0, viewport_size.x - menu_width - 8.0),
		clampf(screen_position.y, 8.0, viewport_size.y - menu_height - 8.0)
	)
	show()


func hide_menu() -> void:
	hide()


func _build_action_row(action: Dictionary) -> Control:
	var id: String = action["id"]
	if not action.has("quantity"):
		return _build_plain_button(id, action["label"])

	var qty_cfg: Dictionary = action["quantity"]
	var min_q: int = maxi(1, int(qty_cfg.get("min", 1)))
	var max_q: int = maxi(min_q, int(qty_cfg.get("max", min_q)))
	var current: int = clampi(int(qty_cfg.get("default", 1)), min_q, max_q)
	_quantity_values[id] = current

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var button := _make_action_button(id, action["label"])
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: action_selected.emit(id, _quantity_values[id]))
	row.add_child(button)
	row.add_child(_build_quantity_picker(id, min_q, max_q, current))
	return row


func _build_plain_button(id: String, label: String) -> Button:
	var button := _make_action_button(id, label)
	button.pressed.connect(func() -> void: action_selected.emit(id, 1))
	return button


func _make_action_button(id: String, label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var icon := IconRegistry.action_icon(id)
	if icon:
		button.icon = icon
		button.add_theme_constant_override("icon_max_width", ICON_SIZE)
		button.add_theme_constant_override("icon_max_height", ICON_SIZE)
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
