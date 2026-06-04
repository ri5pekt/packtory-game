extends Control

## Top-right "Active Order" chip. Tapping it opens a small panel right under the
## chip (no full-screen dark backdrop) listing the products to fulfil, with Cancel.
## Tapping anywhere outside closes it.

const PANEL_W := 280.0
const ANIM_SEC := 0.18
const ACCENT := Color(0.35, 0.72, 0.95)

var _queue: CustomerQueue
var _order: Dictionary = {}

var _icon: Button
var _overlay: Control      # transparent click-catcher
var _panel: PanelContainer
var _list: VBoxContainer
var _open := false
var _tween: Tween


func _ready() -> void:
	z_index = 20
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_icon()
	_build_panel()
	_relayout()
	get_viewport().size_changed.connect(_relayout)
	call_deferred("_bind_queue")


func _relayout() -> void:
	var vp := get_viewport_rect().size
	_icon.position = Vector2(vp.x - _icon.size.x - 16.0, 16.0)
	_overlay.set_deferred("size", vp)
	_position_panel()


func _position_panel() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	var x := vp.x - PANEL_W - 16.0
	_panel.position = Vector2(maxf(8.0, x), _icon.position.y + _icon.size.y + 6.0)


func _bind_queue() -> void:
	_queue = get_tree().get_first_node_in_group("customer_queue") as CustomerQueue
	if _queue == null:
		call_deferred("_bind_queue")
		return
	if not _queue.active_order_changed.is_connected(_on_active_order_changed):
		_queue.active_order_changed.connect(_on_active_order_changed)


func _on_active_order_changed(order: Dictionary) -> void:
	_order = order
	_icon.visible = not order.is_empty()
	if order.is_empty():
		_close()


# ── chip ──────────────────────────────────────────────────────────────────────

func _build_icon() -> void:
	_icon = Button.new()
	_icon.text = "  Active Order"
	_icon.focus_mode = Control.FOCUS_NONE
	_icon.custom_minimum_size = Vector2(170, 40)
	_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_icon.add_theme_font_size_override("font_size", 15)
	var ot := IconRegistry.get_icon("take_order")
	if ot:
		_icon.icon = ot
		_icon.add_theme_constant_override("icon_max_width", 22)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.18, 0.24, 0.92)
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8)
	_icon.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.24, 0.32, 0.95)
	_icon.add_theme_stylebox_override("hover", hover)
	_icon.add_theme_stylebox_override("pressed", hover)

	_icon.visible = false
	_icon.pressed.connect(_toggle)
	add_child(_icon)


# ── panel ─────────────────────────────────────────────────────────────────────

func _build_panel() -> void:
	# Transparent overlay catches taps outside the panel.
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.16, 0.98)
	style.border_color = ACCENT.darkened(0.1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Active Order"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Products to fulfil:"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	vbox.add_child(sub)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_list)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var cancel := Button.new()
	cancel.text = "Cancel Order"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_on_cancel)
	vbox.add_child(cancel)


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close()


# ── open / close ──────────────────────────────────────────────────────────────

func _toggle() -> void:
	if _open:
		_close()
	else:
		_open_panel()


func _open_panel() -> void:
	_open = true
	for child in _list.get_children():
		child.queue_free()
	for id in _order:
		if ProductCatalog.is_package(String(id)):
			continue
		_list.add_child(_make_order_row(String(id), int(_order[id])))

	_overlay.visible = true
	_panel.visible = true
	_position_panel()
	# Subtle pop-in.
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


func _make_order_row(product_id: String, count: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var icon_tex := IconRegistry.product_icon(product_id)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(28, 28)
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
	qty.add_theme_color_override("font_color", ACCENT)
	qty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(qty)
	return row


func _on_cancel() -> void:
	_close()
	if _queue:
		_queue.cancel_order()
