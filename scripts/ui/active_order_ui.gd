extends Control

## Orders control panel — separate in-person and online active-order sections.

const HudProgressionPanelScript = preload("res://scripts/ui/hud_progression_panel.gd")
const PANEL_W := 300.0
const ANIM_SEC := 0.18
const EDGE_MARGIN := 16.0
const HUD_GAP := 8.0
const IN_PERSON_ACCENT := Color(0.35, 0.72, 0.95)
const ONLINE_ACCENT := Color(0.42, 0.78, 0.55)
const DIM_TEXT := Color(0.62, 0.70, 0.80)
const SOURCE_IN_PERSON := "in_person"
const SOURCE_ONLINE := "online"

var _queue: CustomerQueue
var _order: Dictionary = {}
var _order_source := ""

var _tray: VBoxContainer
var _toggle_btn: Button
var _in_person_tray: PanelContainer
var _online_tray: PanelContainer
var _in_person_tray_items: HBoxContainer
var _online_tray_items: HBoxContainer
var _in_person_tray_status: Label
var _online_tray_status: Label

var _overlay: Control
var _panel: PanelContainer
var _in_person_panel_list: VBoxContainer
var _online_panel_list: VBoxContainer
var _in_person_panel_status: Label
var _online_panel_status: Label
var _cancel_btn: Button
var _open := false
var _tween: Tween
var _outbound_van: Node
var _van_loaded_count := 0
var _van_capacity := 4
var _van_on_route := false
var _van_route_remaining := 0.0


func _ready() -> void:
	add_to_group("active_order_ui")
	z_index = 20
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_built()
	_refresh_all()
	_relayout()
	get_viewport().size_changed.connect(_relayout)
	call_deferred("_bind_queue")
	call_deferred("_bind_outbound_van")


## Y coordinate where gameplay alert toasts should begin (below this tray / panel).
func get_toast_anchor_top() -> float:
	if _tray == null:
		return _tray_top_y() + 38.0
	_tray.reset_size()
	var bottom := _tray.position.y
	if _tray.visible:
		bottom += maxf(_tray.size.y, _tray.get_combined_minimum_size().y)
	else:
		bottom = _tray_top_y() + 38.0
	if _open and _panel != null and _panel.visible:
		bottom = maxf(bottom, _panel.position.y + _panel.size.y)
	return bottom + 8.0


func _tray_top_y() -> float:
	return HudProgressionPanelScript.PANEL_HEIGHT + HUD_GAP


func _ensure_built() -> void:
	if _tray != null:
		return
	_build_tray()
	_build_panel()


func get_active_order_source() -> String:
	return _order_source


func get_section_status_text(section_source: String) -> String:
	if section_source == SOURCE_IN_PERSON and _in_person_tray_status:
		return _in_person_tray_status.text
	if section_source == SOURCE_ONLINE and _online_tray_status:
		return _online_tray_status.text
	return ""


func is_section_active(section_source: String) -> bool:
	return _order_source == section_source and not _order.is_empty()


func is_section_tray_visible(section_source: String) -> bool:
	if section_source == SOURCE_IN_PERSON:
		return _in_person_tray != null and _in_person_tray.visible
	if section_source == SOURCE_ONLINE:
		return _online_tray != null and _online_tray.visible
	return false


func _section_has_tray_content(section_source: String) -> bool:
	if section_source == SOURCE_IN_PERSON:
		return is_section_active(SOURCE_IN_PERSON)
	if section_source == SOURCE_ONLINE:
		return (
			is_section_active(SOURCE_ONLINE)
			or _van_on_route
			or _van_loaded_count > 0
		)
	return false


func bind_queue_for_test(queue: Node) -> void:
	_ensure_built()
	_queue = queue as CustomerQueue
	if _queue == null:
		return
	if not _queue.active_order_changed.is_connected(_on_active_order_changed):
		_queue.active_order_changed.connect(_on_active_order_changed)
	_on_active_order_changed(_queue.get_active_order())


func _relayout() -> void:
	var vp := get_viewport_rect().size
	_tray.reset_size()
	var tray_w := maxf(_tray.get_combined_minimum_size().x, _tray.size.x)
	_tray.position = Vector2(vp.x - tray_w - EDGE_MARGIN, _tray_top_y())
	_overlay.set_deferred("size", vp)
	_position_panel()
	_notify_alerts_relayout()


func _notify_alerts_relayout() -> void:
	var alerts := get_node_or_null("/root/AlertMessages")
	if alerts != null and alerts.has_method("relayout_toasts"):
		alerts.relayout_toasts()


func _position_panel() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	var x := vp.x - PANEL_W - EDGE_MARGIN
	_panel.position = Vector2(maxf(8.0, x), _tray.position.y + _tray.size.y + 6.0)


func _bind_queue() -> void:
	_queue = get_tree().get_first_node_in_group("customer_queue") as CustomerQueue
	if _queue == null:
		call_deferred("_bind_queue")
		return
	if not _queue.active_order_changed.is_connected(_on_active_order_changed):
		_queue.active_order_changed.connect(_on_active_order_changed)
	_on_active_order_changed(_queue.get_active_order())


func _bind_outbound_van() -> void:
	if _outbound_van != null and is_instance_valid(_outbound_van):
		return
	var van := get_tree().get_first_node_in_group("outbound_delivery_vehicles")
	if van == null:
		call_deferred("_bind_outbound_van")
		return
	_outbound_van = van
	if van.has_signal("cargo_changed") and not van.cargo_changed.is_connected(_on_van_cargo_changed):
		van.cargo_changed.connect(_on_van_cargo_changed)
	if van.has_signal("dispatch_started") and not van.dispatch_started.is_connected(_on_van_dispatch_started):
		van.dispatch_started.connect(_on_van_dispatch_started)
	if van.has_signal("route_progress_changed") \
			and not van.route_progress_changed.is_connected(_on_van_route_progress):
		van.route_progress_changed.connect(_on_van_route_progress)
	if van.has_signal("dispatch_completed") \
			and not van.dispatch_completed.is_connected(_on_van_dispatch_completed):
		van.dispatch_completed.connect(_on_van_dispatch_completed)
	_sync_van_state()


func _sync_van_state() -> void:
	if _outbound_van == null or not is_instance_valid(_outbound_van):
		return
	_van_loaded_count = int(_outbound_van.get_loaded_count())
	_van_capacity = int(_outbound_van.get_capacity())
	_van_on_route = bool(_outbound_van.is_on_route())
	if _van_on_route and _outbound_van.has_method("get_route_progress"):
		var progress: Dictionary = _outbound_van.get_route_progress()
		_van_route_remaining = float(progress.get("remaining_minutes", 0.0))
	else:
		_van_route_remaining = 0.0
	_refresh_all()


func _on_van_cargo_changed(loaded_count: int, capacity: int) -> void:
	_van_loaded_count = loaded_count
	_van_capacity = capacity
	_refresh_all()


func _on_van_dispatch_started(_package_count: int) -> void:
	_van_on_route = true
	_van_loaded_count = 0
	_refresh_all()


func _on_van_route_progress(remaining_minutes: float, _total_minutes: float) -> void:
	_van_on_route = true
	_van_route_remaining = remaining_minutes
	_refresh_all()


func _on_van_dispatch_completed(_package_count: int) -> void:
	_van_on_route = false
	_van_route_remaining = 0.0
	_van_loaded_count = 0
	_refresh_all()


func _on_active_order_changed(order: Dictionary) -> void:
	_order = order
	if _queue:
		_order_source = _queue.get_order_source()
	else:
		_order_source = ""
	if order.is_empty():
		_order_source = ""
		_close()
	_refresh_all()
	call_deferred("_relayout")


func _refresh_all() -> void:
	if _tray == null:
		return
	var has_active := not _order.is_empty() or _van_on_route or _van_loaded_count > 0
	_tray.visible = has_active
	if _toggle_btn:
		_toggle_btn.visible = has_active
	if _in_person_tray:
		_in_person_tray.visible = _section_has_tray_content(SOURCE_IN_PERSON)
	if _online_tray:
		_online_tray.visible = _section_has_tray_content(SOURCE_ONLINE)
	_refresh_section_tray(
		SOURCE_IN_PERSON,
		_in_person_tray,
		_in_person_tray_status,
		_in_person_tray_items,
		IN_PERSON_ACCENT
	)
	_refresh_section_tray(
		SOURCE_ONLINE,
		_online_tray,
		_online_tray_status,
		_online_tray_items,
		ONLINE_ACCENT
	)
	_refresh_panel_sections()
	if _cancel_btn:
		_cancel_btn.visible = has_active


func _refresh_section_tray(
	section_source: String,
	card: PanelContainer,
	status_label: Label,
	items_row: HBoxContainer,
	accent: Color
) -> void:
	if card == null or status_label == null or items_row == null:
		return
	var active := _order_source == section_source and not _order.is_empty()
	status_label.text = _section_status_label(section_source, active)
	_apply_section_card_style(card, accent, active)
	for child in items_row.get_children():
		child.queue_free()
	if active:
		for id in _order:
			if ProductCatalog.is_package(String(id)):
				continue
			items_row.add_child(_make_mini_item(String(id), int(_order[id]), accent))


func _section_status_label(section_source: String, active: bool) -> String:
	if section_source == SOURCE_ONLINE:
		if _van_on_route:
			if _van_route_remaining <= 0.5:
				return "Van returning — route complete"
			return "Van on route — %.0f min left" % ceil(_van_route_remaining)
		if _van_loaded_count > 0:
			return "Van loaded (%d/%d) — ready to dispatch" % [_van_loaded_count, _van_capacity]
	if not active:
		return "No active order"
	if section_source == SOURCE_ONLINE and _queue:
		return String(_queue.get_active_order_meta().get("label", "Online Order"))
	if section_source == SOURCE_IN_PERSON:
		return "Customer queue order"
	return "Active"


func _refresh_panel_sections() -> void:
	if _in_person_panel_status:
		var in_active := is_section_active(SOURCE_IN_PERSON)
		_in_person_panel_status.text = (
			_section_status_label(SOURCE_IN_PERSON, in_active)
			if in_active
			else "No in-person order is active."
		)
	if _online_panel_status:
		var on_active := is_section_active(SOURCE_ONLINE)
		if _van_on_route or _van_loaded_count > 0 or on_active:
			_online_panel_status.text = _section_status_label(SOURCE_ONLINE, on_active)
		else:
			_online_panel_status.text = "No online order is active."
	_rebuild_panel_list(_in_person_panel_list, SOURCE_IN_PERSON, IN_PERSON_ACCENT)
	_rebuild_panel_list(_online_panel_list, SOURCE_ONLINE, ONLINE_ACCENT)


func _rebuild_panel_list(list: VBoxContainer, section_source: String, accent: Color) -> void:
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()
	if not is_section_active(section_source):
		var empty := Label.new()
		empty.text = "—"
		empty.add_theme_color_override("font_color", DIM_TEXT)
		empty.add_theme_font_size_override("font_size", 14)
		list.add_child(empty)
		return
	for id in _order:
		if ProductCatalog.is_package(String(id)):
			continue
		list.add_child(_make_order_row(String(id), int(_order[id]), accent))


# ── tray ──────────────────────────────────────────────────────────────────────

func _build_tray() -> void:
	_tray = VBoxContainer.new()
	_tray.add_theme_constant_override("separation", 6)
	_tray.visible = false
	add_child(_tray)

	_toggle_btn = Button.new()
	_toggle_btn.text = "  Orders"
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.custom_minimum_size = Vector2(196.0, 38.0)
	_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_btn.add_theme_font_size_override("font_size", 15)
	var toggle_style := _section_stylebox(IN_PERSON_ACCENT, true)
	_toggle_btn.add_theme_stylebox_override("normal", toggle_style)
	var toggle_hover := toggle_style.duplicate() as StyleBoxFlat
	toggle_hover.bg_color = Color(0.18, 0.24, 0.32, 0.95)
	_toggle_btn.add_theme_stylebox_override("hover", toggle_hover)
	_toggle_btn.add_theme_stylebox_override("pressed", toggle_hover)
	_toggle_btn.pressed.connect(_toggle)
	_tray.add_child(_toggle_btn)

	var built_in_person := _build_section_tray_card(
		"In-Person",
		"take_order",
		IN_PERSON_ACCENT
	)
	_in_person_tray = built_in_person.card
	_in_person_tray_status = built_in_person.status
	_in_person_tray_items = built_in_person.items
	_tray.add_child(_in_person_tray)

	var built_online := _build_section_tray_card(
		"Online",
		"order_list",
		ONLINE_ACCENT
	)
	_online_tray = built_online.card
	_online_tray_status = built_online.status
	_online_tray_items = built_online.items
	_tray.add_child(_online_tray)


func _build_section_tray_card(
	title: String,
	icon_id: String,
	accent: Color
) -> Dictionary:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_section_card_style(card, accent, false)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)

	var icon_tex := IconRegistry.get_icon(icon_id)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(20.0, 20.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(icon)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", accent)
	header.add_child(title_lbl)

	var status := Label.new()
	status.text = "No active order"
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", DIM_TEXT)
	column.add_child(status)

	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 8)
	column.add_child(items)

	return {"card": card, "status": status, "items": items}


func _apply_section_card_style(card: PanelContainer, accent: Color, active: bool) -> void:
	var style := _section_stylebox(accent, active)
	card.add_theme_stylebox_override("panel", style)


func _section_stylebox(accent: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.18, 0.24, 0.92) if active else Color(0.10, 0.12, 0.16, 0.82)
	style.border_color = accent if active else accent.darkened(0.45)
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0)
	return style


# ── panel ─────────────────────────────────────────────────────────────────────

func _build_panel() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.z_index = 5
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_panel.size = Vector2(PANEL_W, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.12, 0.16, 0.98)
	panel_style.border_color = Color(0.30, 0.36, 0.46)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(14)
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Orders Control Panel"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "In-person and online orders are tracked separately."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", DIM_TEXT)
	vbox.add_child(hint)

	vbox.add_child(_build_panel_section(
		"In-Person Orders",
		"take_order",
		IN_PERSON_ACCENT,
		true
	))
	vbox.add_child(_build_panel_section(
		"Online Orders",
		"order_list",
		ONLINE_ACCENT,
		false
	))

	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel Active Order"
	_cancel_btn.focus_mode = Control.FOCUS_NONE
	_cancel_btn.custom_minimum_size = Vector2(0.0, 44.0)
	_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_btn.pressed.connect(_on_cancel)
	vbox.add_child(_cancel_btn)


func _build_panel_section(
	title: String,
	icon_id: String,
	accent: Color,
	is_in_person: bool
) -> PanelContainer:
	var block := PanelContainer.new()
	_apply_section_card_style(block, accent, false)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	block.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)

	var icon_tex := IconRegistry.get_icon(icon_id)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(22.0, 22.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(icon)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", accent)
	header.add_child(title_lbl)

	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", DIM_TEXT)
	column.add_child(status)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	column.add_child(list)

	if is_in_person:
		_in_person_panel_status = status
		_in_person_panel_list = list
	else:
		_online_panel_status = status
		_online_panel_list = list

	return block


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close()


func _toggle() -> void:
	if _open:
		_close()
	else:
		_open_panel()


func _open_panel() -> void:
	_open = true
	_refresh_panel_sections()
	_overlay.visible = true
	_panel.visible = true
	_position_panel()
	_panel.pivot_offset = Vector2(PANEL_W, 0)
	_panel.scale = Vector2(0.96, 0.9)
	_panel.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "scale", Vector2.ONE, ANIM_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, ANIM_SEC)


func _close() -> void:
	_open = false
	_overlay.visible = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 0.0, ANIM_SEC * 0.8)
	_tween.tween_callback(func() -> void: _panel.visible = false)


func _make_mini_item(product_id: String, count: int, accent: Color) -> Control:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 3)
	var icon_tex := IconRegistry.product_icon(product_id)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(20.0, 20.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item.add_child(icon)
	var qty := Label.new()
	qty.text = "×%d" % count
	qty.add_theme_font_size_override("font_size", 12)
	qty.add_theme_color_override("font_color", accent)
	qty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.add_child(qty)
	return item


func _make_order_row(product_id: String, count: int, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon_tex := IconRegistry.product_icon(product_id)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(28.0, 28.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = ProductCatalog.display_name(product_id)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)
	var qty := Label.new()
	qty.text = "×%d" % count
	qty.add_theme_font_size_override("font_size", 15)
	qty.add_theme_color_override("font_color", accent)
	qty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(qty)
	return row


func _on_cancel() -> void:
	_close()
	if _queue:
		_queue.cancel_order()
