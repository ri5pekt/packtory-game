extends VBoxContainer

## Detail view for a single online order with activation.

signal back_requested
signal order_activated(order_number: int)

const OnlineOrderCatalogScript = preload("res://scripts/gameplay/online_order_catalog.gd")
const ComputerSectionScreenScript = preload("res://scripts/ui/computer_section_screen.gd")
const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := Color(0.62, 0.70, 0.80)
const ACCENT := Color(0.26, 0.62, 0.92)
const APPLY_BG := Color(0.18, 0.55, 0.34, 0.95)
const BTN_MIN_HEIGHT := 52.0

var _order: Dictionary = {}
var _heading: Label
var _summary: Label
var _items_list: VBoxContainer
var _status_label: Label


func setup(order: Dictionary) -> void:
	_order = order.duplicate(true)
	if _items_list != null:
		_refresh()


func get_order_number() -> int:
	return int(_order.get("order_number", 0))


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	_build()
	_refresh()


func _build() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	add_child(top)

	var back_btn := _make_button("Back", ACCENT.darkened(0.15))
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back_btn)

	_heading = Label.new()
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_heading.add_theme_font_size_override("font_size", 18)
	_heading.add_theme_color_override("font_color", TEXT_COLOR)
	top.add_child(_heading)

	var scroll_bundle := ComputerSectionScreenScript.make_scroll_area()
	add_child(scroll_bundle.scroll)
	var body: VBoxContainer = scroll_bundle.content

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 15)
	_summary.add_theme_color_override("font_color", DIM_TEXT)
	body.add_child(_summary)

	var required := Label.new()
	required.text = "Items required:"
	required.add_theme_font_size_override("font_size", 16)
	required.add_theme_color_override("font_color", TEXT_COLOR)
	body.add_child(required)

	_items_list = VBoxContainer.new()
	_items_list.add_theme_constant_override("separation", 6)
	body.add_child(_items_list)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", DIM_TEXT)
	body.add_child(_status_label)

	var activate_btn := _make_button("Make Active Order", APPLY_BG)
	activate_btn.pressed.connect(_on_make_active_pressed)
	body.add_child(activate_btn)


func _refresh() -> void:
	if _heading:
		_heading.text = OnlineOrderCatalogScript.format_order_title(get_order_number())
	if _summary:
		_summary.text = "Online store order — separate from in-person customers."
	for child in _items_list.get_children():
		child.queue_free()
	for item in _order.get("items", []):
		_items_list.add_child(_make_item_row(item))
	_status_label.text = ""


func _make_item_row(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var qty := Label.new()
	qty.text = "×%d" % maxi(1, int(item.get("quantity", 1)))
	qty.custom_minimum_size = Vector2(34.0, 0.0)
	qty.add_theme_font_size_override("font_size", 16)
	qty.add_theme_color_override("font_color", ACCENT)
	row.add_child(qty)
	var name := Label.new()
	name.text = OnlineOrderCatalogScript.display_item_name(item)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(name)
	return row


func _on_make_active_pressed() -> void:
	var queue := get_tree().get_first_node_in_group("customer_queue")
	if queue == null or not queue.has_method("activate_online_order"):
		_status_label.text = "Customer queue isn't available."
		return
	if queue.has_method("can_activate_online_order"):
		var blocked: String = queue.can_activate_online_order()
		if blocked != "":
			_status_label.text = blocked
			_show_toast(blocked, true)
			return
	if queue.activate_online_order(_order):
		_status_label.text = "This order is now your active order."
		_show_toast("Online order is now active.", false)
		order_activated.emit(get_order_number())
	else:
		_status_label.text = "This online order has no packable items."
		_show_toast("This online order has no packable items.", true)


func _show_toast(message: String, warn: bool) -> void:
	var alerts := get_node_or_null("/root/AlertMessages")
	if alerts == null:
		return
	if warn and alerts.has_method("warn"):
		alerts.warn(message)
	elif alerts.has_method("info"):
		alerts.info(message)


func _make_button(text: String, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, BTN_MIN_HEIGHT)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)
	return btn
