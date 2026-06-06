extends VBoxContainer

## Reorder Products screen inside the computer terminal.

signal back_requested
signal reorder_requested(product_id: String, quantity: int)

const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")
const ProductReorderConfigScript = preload("res://scripts/gameplay/product_reorder_config.gd")
const IncomingDeliveryManagerScript = preload(
	"res://scripts/gameplay/incoming_delivery_manager.gd"
)
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
var _product_checkboxes: Dictionary = {}
var _quantity_spinners: Dictionary = {}
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


func get_quantity_for_product(product_id: String) -> int:
	if _quantity_spinners.has(product_id):
		return int(_quantity_spinners[product_id].value)
	return ProductReorderConfigScript.DEFAULT_QUANTITY


func is_product_selected(product_id: String) -> bool:
	if _product_checkboxes.has(product_id):
		return bool(_product_checkboxes[product_id].button_pressed)
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
	heading.text = "Reorder Products"
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
	hint.text = (
		"Check products, set quantities, then press Order. "
		+ "Delivery costs 1 coin per order."
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", DIM_TEXT)
	body.add_child(hint)

	_catalog_list = VBoxContainer.new()
	_catalog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_list.add_theme_constant_override("separation", 10)
	body.add_child(_catalog_list)

	for product_id in _reorderable_product_ids():
		_catalog_list.add_child(_build_catalog_card(product_id))

	var pending_heading := Label.new()
	pending_heading.text = "Incoming deliveries"
	pending_heading.add_theme_font_size_override("font_size", 16)
	pending_heading.add_theme_color_override("font_color", TEXT_COLOR)
	body.add_child(pending_heading)

	_pending_list = VBoxContainer.new()
	_pending_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pending_list.add_theme_constant_override("separation", 8)
	body.add_child(_pending_list)

	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(footer)

	_order_summary_label = Label.new()
	_order_summary_label.text = "Select products to order."
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


func _reorderable_product_ids() -> Array[String]:
	var unlocks := get_node_or_null("/root/UnlockManager")
	if unlocks != null and unlocks.has_method("get_orderable_product_ids"):
		return unlocks.get_orderable_product_ids()
	var ids: Array[String] = []
	for product_id in ProductCatalogScript.orderable_product_ids():
		ids.append(String(product_id))
	return ids


func _build_catalog_card(product_id: String) -> PanelContainer:
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

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	body.add_child(title_row)

	var checkbox := CheckBox.new()
	checkbox.text = ProductCatalogScript.display_name(product_id)
	checkbox.add_theme_font_size_override("font_size", 17)
	checkbox.add_theme_color_override("font_color", TEXT_COLOR)
	checkbox.toggled.connect(func(_pressed: bool) -> void: _on_product_selection_changed(product_id))
	title_row.add_child(checkbox)
	_product_checkboxes[product_id] = checkbox

	var qty_row := HBoxContainer.new()
	qty_row.add_theme_constant_override("separation", 8)
	body.add_child(qty_row)

	var qty_label := Label.new()
	qty_label.text = "Quantity"
	qty_label.add_theme_font_size_override("font_size", 14)
	qty_label.add_theme_color_override("font_color", DIM_TEXT)
	qty_row.add_child(qty_label)

	var spinner := SpinBox.new()
	spinner.min_value = ProductReorderConfigScript.MIN_QUANTITY
	spinner.max_value = ProductReorderConfigScript.MAX_QUANTITY
	spinner.value = ProductReorderConfigScript.DEFAULT_QUANTITY
	spinner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spinner.editable = false
	spinner.value_changed.connect(func(_value: float) -> void: _update_order_footer())
	qty_row.add_child(spinner)
	_quantity_spinners[product_id] = spinner

	return card


func _on_product_selection_changed(product_id: String) -> void:
	if _quantity_spinners.has(product_id):
		var spinner: SpinBox = _quantity_spinners[product_id]
		spinner.editable = is_product_selected(product_id)
	_update_order_footer()


func _selected_order_lines() -> Array:
	var lines: Array = []
	for product_id in _product_checkboxes:
		if not is_product_selected(String(product_id)):
			continue
		lines.append({
			"product_id": String(product_id),
			"quantity": get_quantity_for_product(String(product_id)),
		})
	return lines


func _update_order_footer() -> void:
	if _order_summary_label == null or _order_btn == null:
		return
	var lines := _selected_order_lines()
	if lines.is_empty():
		_order_summary_label.text = "Select products to order."
		_order_btn.disabled = true
		return
	var total := ProductReorderConfigScript.batch_order_total(lines)
	var count := lines.size()
	var item_word := "product" if count == 1 else "products"
	_order_summary_label.text = "%d %s selected · Total: %d coin%s" % [
		count,
		item_word,
		total,
		"" if total == 1 else "s",
	]
	_order_btn.disabled = false


func _submit_order() -> void:
	var lines := _selected_order_lines()
	if lines.is_empty():
		_set_status("Select at least one product to order.")
		return
	var manager := _get_delivery_manager()
	if manager == null:
		_set_status("Delivery service unavailable.")
		return
	if not manager.has_method("place_product_orders"):
		_set_status("Delivery service unavailable.")
		return
	var result: Dictionary = manager.place_product_orders(lines)
	if bool(result.get("ok", false)):
		var created: Array = result.get("deliveries", [])
		if created.is_empty() and result.has("delivery"):
			created = [result.get("delivery")]
		if created.size() == 1:
			var delivery: Dictionary = created[0]
			_set_status("Ordered %s. Delivery #%d is on the way." % [
				String(delivery.get("label", "products")),
				int(delivery.get("order_id", 0)),
			])
		else:
			_set_status("Ordered %d deliveries. They are on the way." % created.size())
		for line in lines:
			reorder_requested.emit(String(line.get("product_id", "")), int(line.get("quantity", 0)))
		for product_id in _product_checkboxes:
			var checkbox: CheckBox = _product_checkboxes[product_id]
			checkbox.button_pressed = false
			_on_product_selection_changed(String(product_id))
		_refresh_balance()
		_refresh_pending()
		_update_order_footer()
		return
	_set_status(_reason_message(String(result.get("reason", ""))))


func _reason_message(reason: String) -> String:
	match reason:
		"insufficient_coins":
			var lines := _selected_order_lines()
			var total := ProductReorderConfigScript.batch_order_total(lines)
			var economy := get_node_or_null("/root/EconomyManager")
			var coins := int(economy.get_coins()) if economy else 0
			return "Not enough coins — need %d, you have %d." % [total, coins]
		"nothing_selected":
			return "Select at least one product to order."
		"unknown_product":
			return "One of those products is not available to reorder."
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
			IncomingDeliveryManagerScript.DELIVERY_KIND_PRODUCT
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


func _build_pending_card(delivery: Dictionary) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var name_label := Label.new()
	name_label.text = "#%d  %s" % [
		int(delivery.get("order_id", 0)),
		String(delivery.get("label", "Products")),
	]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(name_label)

	var status_label := Label.new()
	var raw_status := String(delivery.get("status", "ordered"))
	if raw_status == "at_dock":
		status_label.text = "✓ AT DOCK"
		status_label.add_theme_color_override("font_color", Color(0.40, 0.95, 0.56))
	else:
		var mins := _minutes_remaining(delivery)
		if mins > 0:
			status_label.text = "~%d min" % mins
			status_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
		else:
			status_label.text = "Arriving…"
			status_label.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	status_label.add_theme_font_size_override("font_size", 13)
	row.add_child(status_label)

	return card


func _minutes_remaining(delivery: Dictionary) -> int:
	var game_time := get_node_or_null("/root/GameTimeManager")
	if game_time == null:
		return 0
	var now: float = game_time.get_precise_minutes() if game_time.has_method("get_precise_minutes") else 0.0
	var arrive_at := float(delivery.get("deliver_at_minutes", 0.0))
	return maxi(0, int(ceil(arrive_at - now)))


func _set_status(message: String) -> void:
	if _status_label:
		_status_label.text = message


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
