extends VBoxContainer

## Order Equipment screen inside the computer terminal.

signal back_requested
signal order_requested(item_id: String)

const EquipmentCatalogScript = preload("res://scripts/gameplay/equipment_catalog.gd")
const IncomingDeliveryManagerScript = preload(
	"res://scripts/gameplay/incoming_delivery_manager.gd"
)
const ComputerScreenFeedbackScript = preload("res://scripts/ui/computer_screen_feedback.gd")
const ComputerSectionScreenScript = preload("res://scripts/ui/computer_section_screen.gd")

const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := Color(0.62, 0.70, 0.80)
const ACCENT := Color(0.26, 0.62, 0.92)
const CARD_BG := Color(0.12, 0.15, 0.20, 1.0)
const CARD_BORDER := Color(0.28, 0.34, 0.44, 0.9)
const BTN_MIN_HEIGHT := 48.0

var _catalog_list: VBoxContainer
var _pending_list: VBoxContainer
var _balance_label: Label
var _status_label: Label
var _order_summary_label: Label
var _order_btn: Button
var _item_checkboxes: Dictionary = {}
var _built := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	ensure_ready()


func ensure_ready() -> void:
	if _built:
		return
	_build()
	_built = true


func get_catalog_card_count() -> int:
	ensure_ready()
	return _catalog_list.get_child_count() if _catalog_list else 0


func get_pending_card_count() -> int:
	ensure_ready()
	return _pending_list.get_child_count() if _pending_list else 0


func get_status_text() -> String:
	ensure_ready()
	return _status_label.text if _status_label else ""


func is_item_selected(item_id: String) -> bool:
	if _item_checkboxes.has(item_id):
		return bool(_item_checkboxes[item_id].button_pressed)
	return false


func refresh() -> void:
	ensure_ready()
	_refresh_balance()
	_refresh_pending()
	_update_order_footer()


func _build() -> void:
	add_theme_constant_override("separation", 10)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	add_child(top)

	var back_btn := _make_button("Back")
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back_btn)

	var heading := Label.new()
	heading.text = "Order Equipment"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", TEXT_COLOR)
	top.add_child(heading)

	var scroll_bundle := ComputerSectionScreenScript.make_scroll_area()
	add_child(scroll_bundle.scroll)
	var body: VBoxContainer = scroll_bundle.content

	_balance_label = Label.new()
	_balance_label.text = "Coins: 0"
	_balance_label.add_theme_font_size_override("font_size", 14)
	_balance_label.add_theme_color_override("font_color", DIM_TEXT)
	body.add_child(_balance_label)

	var hint := Label.new()
	hint.text = "Check equipment to order, then press Order. Deliveries arrive at the loading dock."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", DIM_TEXT)
	body.add_child(hint)

	_catalog_list = VBoxContainer.new()
	_catalog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_list.add_theme_constant_override("separation", 10)
	body.add_child(_catalog_list)

	for item in EquipmentCatalogScript.get_orderable_items():
		_catalog_list.add_child(_build_catalog_card(item))

	var pending_heading := Label.new()
	pending_heading.text = "Incoming deliveries"
	pending_heading.add_theme_font_size_override("font_size", 16)
	pending_heading.add_theme_color_override("font_color", TEXT_COLOR)
	body.add_child(pending_heading)

	_pending_list = VBoxContainer.new()
	_pending_list.add_theme_constant_override("separation", 8)
	body.add_child(_pending_list)

	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(footer)

	_order_summary_label = Label.new()
	_order_summary_label.text = "Select equipment to order."
	_order_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_order_summary_label.add_theme_font_size_override("font_size", 14)
	_order_summary_label.add_theme_color_override("font_color", ACCENT)
	footer.add_child(_order_summary_label)

	_order_btn = _make_button("Order")
	_order_btn.disabled = true
	_order_btn.pressed.connect(_submit_order)
	footer.add_child(_order_btn)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", DIM_TEXT)
	footer.add_child(_status_label)

	_bind_delivery_manager()
	_refresh_balance()
	_refresh_pending()
	_update_order_footer()


func _build_catalog_card(item: Dictionary) -> PanelContainer:
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

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)

	var item_id := String(item.get("id", ""))

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	body.add_child(title_row)

	var checkbox := CheckBox.new()
	checkbox.text = String(item.get("label", "Item"))
	checkbox.add_theme_font_size_override("font_size", 17)
	checkbox.add_theme_color_override("font_color", TEXT_COLOR)
	checkbox.toggled.connect(func(_pressed: bool) -> void: _update_order_footer())
	title_row.add_child(checkbox)
	_item_checkboxes[item_id] = checkbox

	var description := Label.new()
	description.text = String(item.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", DIM_TEXT)
	body.add_child(description)

	var cost := Label.new()
	cost.text = "%d coins" % int(item.get("cost", 0))
	cost.add_theme_font_size_override("font_size", 14)
	cost.add_theme_color_override("font_color", ACCENT)
	body.add_child(cost)

	return card


func _selected_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for item_id in _item_checkboxes:
		if is_item_selected(String(item_id)):
			ids.append(String(item_id))
	return ids


func _update_order_footer() -> void:
	if _order_summary_label == null or _order_btn == null:
		return
	var ids := _selected_item_ids()
	if ids.is_empty():
		_order_summary_label.text = "Select equipment to order."
		_order_btn.disabled = true
		return
	var total := EquipmentCatalogScript.batch_order_total(ids)
	var count := ids.size()
	var item_word := "item" if count == 1 else "items"
	_order_summary_label.text = "%d %s selected · Total: %d coins" % [count, item_word, total]
	_order_btn.disabled = false


func _submit_order() -> void:
	var ids := _selected_item_ids()
	if ids.is_empty():
		_notify_player("Select at least one item to order.", true)
		return
	var manager := _get_delivery_manager()
	if manager == null:
		_notify_player("Delivery service unavailable.", true)
		return
	if not manager.has_method("place_equipment_orders"):
		_notify_player("Delivery service unavailable.", true)
		return
	var result: Dictionary = manager.place_equipment_orders(ids)
	if bool(result.get("ok", false)):
		var created: Array = result.get("deliveries", [])
		if created.is_empty() and result.has("delivery"):
			created = [result.get("delivery")]
		if created.size() == 1:
			var delivery: Dictionary = created[0]
			_notify_player("Ordered %s. Delivery #%d is on the way." % [
				String(delivery.get("label", "equipment")),
				int(delivery.get("order_id", 0)),
			], false)
		else:
			_notify_player("Ordered %d deliveries. They are on the way." % created.size(), false)
		for item_id in ids:
			order_requested.emit(item_id)
		for checkbox_id in _item_checkboxes:
			var checkbox: CheckBox = _item_checkboxes[checkbox_id]
			checkbox.button_pressed = false
		_refresh_balance()
		_refresh_pending()
		_update_order_footer()
		return
	_notify_player(_reason_message(String(result.get("reason", ""))), true)


func _reason_message(reason: String) -> String:
	match reason:
		"insufficient_coins":
			var ids := _selected_item_ids()
			var total := EquipmentCatalogScript.batch_order_total(ids)
			var economy := get_node_or_null("/root/EconomyManager")
			var coins := int(economy.get_coins()) if economy else 0
			return "Not enough coins — need %d, you have %d." % [total, coins]
		"nothing_selected":
			return "Select at least one item to order."
		"unknown_item":
			return "One of those equipment items is not available."
		"no_economy":
			return "Coin balance unavailable."
		_:
			return "Could not place that order."


func _bind_delivery_manager() -> void:
	var manager := _get_delivery_manager()
	if manager == null:
		return
	if manager.has_signal("pending_deliveries_changed"):
		if not manager.pending_deliveries_changed.is_connected(_on_pending_changed):
			manager.pending_deliveries_changed.connect(_on_pending_changed)
	var economy := get_node_or_null("/root/EconomyManager")
	if economy != null and economy.has_signal("coins_changed"):
		if not economy.coins_changed.is_connected(_on_coins_changed):
			economy.coins_changed.connect(_on_coins_changed)


func _on_pending_changed(_pending: Array) -> void:
	_refresh_pending()


func _on_coins_changed(_balance: int, _delta: int) -> void:
	_refresh_balance()


func _refresh_balance() -> void:
	if _balance_label == null:
		return
	var economy := get_node_or_null("/root/EconomyManager")
	var coins := int(economy.get_coins()) if economy else 0
	_balance_label.text = "Coins: %d" % coins


func _refresh_pending() -> void:
	if _pending_list == null:
		return
	for child in _pending_list.get_children():
		child.queue_free()
	var manager := _get_delivery_manager()
	var pending: Array = []
	if manager != null and manager.has_method("get_pending_deliveries_of_kind"):
		pending = manager.get_pending_deliveries_of_kind(
			IncomingDeliveryManagerScript.DELIVERY_KIND_EQUIPMENT
		)
	if pending.is_empty():
		var empty := Label.new()
		empty.text = "No pending deliveries."
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", DIM_TEXT)
		_pending_list.add_child(empty)
		return
	for delivery in pending:
		if delivery is Dictionary:
			_pending_list.add_child(_build_pending_card(delivery))


func _build_pending_card(delivery: Dictionary) -> Label:
	var label := Label.new()
	var status := String(delivery.get("status", "ordered"))
	if status == "ordered":
		status = "in transit"
	elif status == "at_dock":
		status = "at dock"
	label.text = "#%d  %s  (%s)" % [
		int(delivery.get("order_id", 0)),
		String(delivery.get("label", "Equipment")),
		status,
	]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label


func _notify_player(message: String, warn: bool) -> void:
	ComputerScreenFeedbackScript.notify(message, _status_label, warn)


func _get_delivery_manager() -> Node:
	return get_node_or_null("/root/IncomingDeliveryManager")


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120.0, BTN_MIN_HEIGHT)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACCENT.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)
	return btn
