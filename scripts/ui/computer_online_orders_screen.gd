extends VBoxContainer

## Online Orders list screen inside the computer terminal.

signal back_requested

const OnlineOrderCatalogScript = preload("res://scripts/gameplay/online_order_catalog.gd")
const ComputerOnlineOrderDetailScreenScript = preload(
	"res://scripts/ui/computer_online_order_detail_screen.gd"
)
const ComputerSectionScreenScript = preload("res://scripts/ui/computer_section_screen.gd")

const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := Color(0.62, 0.70, 0.80)
const ACCENT := Color(0.26, 0.62, 0.92)
const CARD_BG := Color(0.12, 0.15, 0.20, 1.0)
const CARD_BORDER := Color(0.28, 0.34, 0.44, 0.9)
const CARD_BORDER_ACTIVE := Color(0.26, 0.62, 0.92, 0.95)
const BTN_MIN_HEIGHT := 48.0

var _orders_list: VBoxContainer
var _detail_screen: VBoxContainer
var _list_host: VBoxContainer
var _showing_detail := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	ensure_ready()


func ensure_ready() -> void:
	if _list_host != null:
		return
	_build()


func is_showing_detail() -> bool:
	return _showing_detail


func get_order_card_count() -> int:
	ensure_ready()
	if _orders_list == null:
		return 0
	return _orders_list.get_child_count()


func get_order_titles() -> PackedStringArray:
	ensure_ready()
	var titles := PackedStringArray()
	if _orders_list == null:
		return titles
	for child in _orders_list.get_children():
		if child is PanelContainer:
			var body := child.get_node_or_null("Body") as VBoxContainer
			if body == null:
				continue
			for sub in body.get_children():
				if sub is Label and sub.name == "Title":
					titles.append((sub as Label).text)
	return titles


func get_first_order_items_text() -> String:
	ensure_ready()
	if _orders_list == null or _orders_list.get_child_count() == 0:
		return ""
	var card := _orders_list.get_child(0) as PanelContainer
	if card == null:
		return ""
	var items := card.get_node_or_null("Body/Items") as Label
	return items.text if items else ""


func show_order_detail(order: Dictionary) -> void:
	ensure_ready()
	_showing_detail = true
	_list_host.visible = false
	if _detail_screen:
		_detail_screen.queue_free()
	_detail_screen = ComputerOnlineOrderDetailScreenScript.new()
	_detail_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_screen.setup(order)
	_detail_screen.back_requested.connect(_show_list)
	_detail_screen.order_activated.connect(_on_order_activated)
	add_child(_detail_screen)


func _show_list() -> void:
	_showing_detail = false
	if _detail_screen and is_instance_valid(_detail_screen):
		_detail_screen.queue_free()
	_detail_screen = null
	if _list_host:
		_list_host.visible = true


func _on_order_activated(_order_number: int) -> void:
	pass


func _build() -> void:
	_list_host = VBoxContainer.new()
	_list_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_host.add_theme_constant_override("separation", 10)
	add_child(_list_host)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	_list_host.add_child(top)

	var back_btn := _make_button("Back")
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back_btn)

	var heading := Label.new()
	heading.text = "Online Orders"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", TEXT_COLOR)
	top.add_child(heading)

	var scroll_bundle := ComputerSectionScreenScript.make_scroll_area()
	_list_host.add_child(scroll_bundle.scroll)
	var body: VBoxContainer = scroll_bundle.content

	var hint := Label.new()
	hint.text = "Tap an order to view details and make it active."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", DIM_TEXT)
	body.add_child(hint)

	_orders_list = VBoxContainer.new()
	_orders_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orders_list.add_theme_constant_override("separation", 10)
	body.add_child(_orders_list)

	_refresh_order_cards()


func refresh() -> void:
	ensure_ready()
	_refresh_order_cards()


func _refresh_order_cards() -> void:
	if _orders_list == null:
		return
	for child in _orders_list.get_children():
		child.queue_free()
	var fulfilled: Array = _get_fulfilled_online_orders()
	var available: Array = OnlineOrderCatalogScript.get_available_orders(fulfilled)
	if available.is_empty():
		_orders_list.add_child(_build_empty_state_label())
		return
	for order in available:
		_orders_list.add_child(_build_order_card(order))


func _get_fulfilled_online_orders() -> Array:
	if not is_inside_tree():
		return []
	var tree := get_tree()
	if tree == null:
		return []
	var queue := tree.get_first_node_in_group("customer_queue")
	if queue and queue.has_method("get_fulfilled_online_orders"):
		return queue.get_fulfilled_online_orders()
	return []


func _build_empty_state_label() -> Label:
	var label := Label.new()
	label.text = "No open online orders right now."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", DIM_TEXT)
	return label


func _build_order_card(order: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 6)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)

	var title := Label.new()
	title.name = "Title"
	title.text = OnlineOrderCatalogScript.format_order_title(int(order.get("order_number", 0)))
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(title)

	var items := Label.new()
	items.name = "Items"
	items.text = OnlineOrderCatalogScript.format_items_block(order)
	items.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	items.add_theme_font_size_override("font_size", 15)
	items.add_theme_color_override("font_color", DIM_TEXT)
	items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(items)

	var tap_hint := Label.new()
	tap_hint.text = "Tap to open"
	tap_hint.add_theme_font_size_override("font_size", 13)
	tap_hint.add_theme_color_override("font_color", ACCENT)
	tap_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(tap_hint)

	card.gui_input.connect(func(event: InputEvent) -> void: _on_card_input(event, order, card, style))
	return card


func _on_card_input(
	event: InputEvent,
	order: Dictionary,
	card: PanelContainer,
	style: StyleBoxFlat
) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			style.border_color = CARD_BORDER_ACTIVE
			card.add_theme_stylebox_override("panel", style)
			show_order_detail(order)


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, BTN_MIN_HEIGHT)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT.darkened(0.15)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)
	return btn
