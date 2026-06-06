extends Control

## Full-screen computer terminal modal with navigable feature screens.

signal closed

const ComputerSectionsConfigScript = preload("res://scripts/gameplay/computer_sections_config.gd")
const ComputerOnlineOrdersScreenScript = preload(
	"res://scripts/ui/computer_online_orders_screen.gd"
)
const ComputerPlaceholderScreenScript = preload(
	"res://scripts/ui/computer_placeholder_screen.gd"
)
const ComputerOrderEquipmentScreenScript = preload(
	"res://scripts/ui/computer_order_equipment_screen.gd"
)
const ComputerReorderProductsScreenScript = preload(
	"res://scripts/ui/computer_reorder_products_screen.gd"
)
const ComputerHireWorkersScreenScript = preload(
	"res://scripts/ui/computer_hire_workers_screen.gd"
)

const PANEL_BG := Color(0.08, 0.10, 0.14, 0.98)
const ACCENT := Color(0.26, 0.62, 0.92)
const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := Color(0.62, 0.70, 0.80)
const BTN_MIN_HEIGHT := 52.0

const SCREEN_HOME := "home"

var _open := false
var _overlay: ColorRect
var _panel: PanelContainer
var _body_scroll: ScrollContainer
var _content_host: VBoxContainer
var _close_btn: Button
var _active_screen := SCREEN_HOME
var _online_orders_screen: VBoxContainer
var _placeholder_screen: VBoxContainer
var _order_equipment_screen: VBoxContainer
var _reorder_products_screen: VBoxContainer
var _hire_workers_screen: VBoxContainer


func _ready() -> void:
	add_to_group("computer_terminal_ui")
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


func get_active_screen() -> String:
	return _active_screen


func get_content_host() -> VBoxContainer:
	return _content_host


func get_online_orders_screen() -> VBoxContainer:
	return _online_orders_screen


func get_placeholder_screen() -> VBoxContainer:
	return _placeholder_screen


func get_order_equipment_screen() -> VBoxContainer:
	return _order_equipment_screen


func get_reorder_products_screen() -> VBoxContainer:
	return _reorder_products_screen


func get_hire_workers_screen() -> VBoxContainer:
	return _hire_workers_screen


func get_home_section_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for section in ComputerSectionsConfigScript.get_sections():
		labels.append(String(section.get("label", "")))
	return labels


func open() -> void:
	_ensure_built()
	if _open:
		return
	_show_screen(SCREEN_HOME)
	_open = true
	visible = true
	_overlay.visible = true
	_panel.visible = true
	_relayout()


func close() -> void:
	if not _open:
		return
	_open = false
	_show_screen(SCREEN_HOME)
	visible = false
	_overlay.visible = false
	_panel.visible = false
	closed.emit()


func notify_world_tap(screen_position: Vector2) -> bool:
	_ensure_built()
	if not _open:
		return false
	if _panel.get_global_rect().has_point(screen_position):
		return true
	close()
	return true


func navigate_to(screen_id: String) -> void:
	_show_screen(screen_id)


func _ensure_built() -> void:
	if _panel != null:
		return
	_build()


func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "DimOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.name = "ComputerPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
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
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	var title := Label.new()
	title.text = "Packtory Computer"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	header.add_child(title)

	_close_btn = _make_button("Close")
	_close_btn.pressed.connect(close)
	header.add_child(_close_btn)

	var subtitle := Label.new()
	subtitle.text = "Warehouse management terminal"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", DIM_TEXT)
	column.add_child(subtitle)

	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "BodyScroll"
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(_body_scroll)

	_content_host = VBoxContainer.new()
	_content_host.name = "ContentHost"
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content_host.add_theme_constant_override("separation", 10)
	_body_scroll.add_child(_content_host)

	_show_screen(SCREEN_HOME)


func _show_screen(screen_id: String) -> void:
	_ensure_built()
	_clear_content_host()
	if screen_id == SCREEN_HOME:
		_active_screen = SCREEN_HOME
		_show_home_screen()
		return

	var section := ComputerSectionsConfigScript.get_section(screen_id)
	if section.is_empty():
		_active_screen = SCREEN_HOME
		_show_home_screen()
		return

	_active_screen = screen_id
	if bool(section.get("placeholder", false)):
		_show_placeholder_screen(section)
	elif screen_id == ComputerSectionsConfigScript.SECTION_ONLINE_ORDERS:
		_show_online_orders_screen()
	elif screen_id == ComputerSectionsConfigScript.SECTION_ORDER_EQUIPMENT:
		_show_order_equipment_screen()
	elif screen_id == ComputerSectionsConfigScript.SECTION_REORDER_PRODUCTS:
		_show_reorder_products_screen()
	elif screen_id == ComputerSectionsConfigScript.SECTION_HIRE_WORKERS:
		_show_hire_workers_screen()
	else:
		_active_screen = SCREEN_HOME
		_show_home_screen()


func _clear_content_host() -> void:
	if _content_host == null:
		return
	for child in _content_host.get_children():
		child.queue_free()
	_online_orders_screen = null
	_placeholder_screen = null
	_order_equipment_screen = null
	_reorder_products_screen = null
	_hire_workers_screen = null


func _prepare_home_screen_host() -> void:
	_content_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _prepare_feature_screen_host() -> void:
	# Feature screens use an inner ScrollContainer with EXPAND_FILL; the host must
	# fill the panel body or that scroll area collapses to zero height.
	_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _show_home_screen() -> void:
	_prepare_home_screen_host()
	var menu_panel := PanelContainer.new()
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.12, 0.15, 0.20, 1.0)
	box_style.border_color = Color(0.28, 0.34, 0.44, 0.9)
	box_style.set_border_width_all(1)
	box_style.set_corner_radius_all(10)
	box_style.content_margin_left = 14
	box_style.content_margin_right = 14
	box_style.content_margin_top = 14
	box_style.content_margin_bottom = 14
	menu_panel.add_theme_stylebox_override("panel", box_style)
	menu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content_host.add_child(menu_panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	menu_panel.add_child(body)

	var welcome := Label.new()
	welcome.text = "Select a module"
	welcome.add_theme_font_size_override("font_size", 16)
	welcome.add_theme_color_override("font_color", TEXT_COLOR)
	body.add_child(welcome)

	var hint := Label.new()
	hint.text = "Manage online orders, equipment, inventory, and staffing from this terminal."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", DIM_TEXT)
	body.add_child(hint)

	for section in ComputerSectionsConfigScript.get_sections():
		var label := String(section.get("label", "Module"))
		if bool(section.get("placeholder", false)):
			label += " (Coming soon)"
		var section_id := String(section.get("id", ""))
		var btn := _make_menu_button(label)
		btn.pressed.connect(func() -> void: _show_screen(section_id))
		body.add_child(btn)


func _show_placeholder_screen(section: Dictionary) -> void:
	_prepare_feature_screen_host()
	_placeholder_screen = ComputerPlaceholderScreenScript.new()
	_placeholder_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placeholder_screen.setup(section)
	_placeholder_screen.back_requested.connect(func() -> void: _show_screen(SCREEN_HOME))
	_content_host.add_child(_placeholder_screen)


func _show_hire_workers_screen() -> void:
	_prepare_feature_screen_host()
	_hire_workers_screen = ComputerHireWorkersScreenScript.new()
	_hire_workers_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hire_workers_screen.back_requested.connect(func() -> void: _show_screen(SCREEN_HOME))
	_content_host.add_child(_hire_workers_screen)
	if _hire_workers_screen.has_method("ensure_ready"):
		_hire_workers_screen.ensure_ready()
	if _hire_workers_screen.has_method("refresh"):
		_hire_workers_screen.refresh()


func _show_reorder_products_screen() -> void:
	_prepare_feature_screen_host()
	_reorder_products_screen = ComputerReorderProductsScreenScript.new()
	_reorder_products_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reorder_products_screen.back_requested.connect(func() -> void: _show_screen(SCREEN_HOME))
	_content_host.add_child(_reorder_products_screen)
	if _reorder_products_screen.has_method("ensure_ready"):
		_reorder_products_screen.ensure_ready()
	if _reorder_products_screen.has_method("refresh"):
		_reorder_products_screen.refresh()


func _show_order_equipment_screen() -> void:
	_prepare_feature_screen_host()
	_order_equipment_screen = ComputerOrderEquipmentScreenScript.new()
	_order_equipment_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_order_equipment_screen.back_requested.connect(func() -> void: _show_screen(SCREEN_HOME))
	_content_host.add_child(_order_equipment_screen)
	if _order_equipment_screen.has_method("ensure_ready"):
		_order_equipment_screen.ensure_ready()
	if _order_equipment_screen.has_method("refresh"):
		_order_equipment_screen.refresh()


func _show_online_orders_screen() -> void:
	_prepare_feature_screen_host()
	_online_orders_screen = ComputerOnlineOrdersScreenScript.new()
	_online_orders_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_online_orders_screen.back_requested.connect(func() -> void: _show_screen(SCREEN_HOME))
	_content_host.add_child(_online_orders_screen)
	if _online_orders_screen.has_method("ensure_ready"):
		_online_orders_screen.ensure_ready()
	if _online_orders_screen.has_method("refresh"):
		_online_orders_screen.refresh()


func _make_menu_button(text: String) -> Button:
	var btn := _make_button(text)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return btn


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120.0, BTN_MIN_HEIGHT)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_font_size_override("font_size", 17)
	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACCENT.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)
	return btn


func _relayout() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		vp = size if size.x > 1.0 and size.y > 1.0 else Vector2(640.0, 480.0)
	size = vp
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)

	var margin_h := maxf(16.0, vp.x * 0.04)
	var margin_v := maxf(16.0, vp.y * 0.04)
	var available_w := maxf(280.0, vp.x - margin_h * 2.0)
	var available_h := maxf(220.0, vp.y - margin_v * 2.0)
	var panel_w := minf(720.0, available_w)
	var panel_h := available_h

	var px := clampf((vp.x - panel_w) * 0.5, margin_h, vp.x - panel_w - margin_h)
	var py := clampf((vp.y - panel_h) * 0.5, margin_v, vp.y - panel_h - margin_v)

	_panel.custom_minimum_size = Vector2.ZERO
	_panel.size = Vector2(panel_w, panel_h)
	_panel.position = Vector2(px, py)
