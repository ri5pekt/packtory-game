extends Control

## Compact delivery-tracking bar that appears below the main HUD whenever there are
## pending incoming deliveries. Each chip shows the delivery label, an icon, and a
## live countdown to arrival. Tapping a chip opens the computer terminal's Reorder
## Products screen for details.

const CHIP_HEIGHT := 32.0
const CHIP_PAD_H := 10.0
const CHIP_GAP := 6.0
const CHIP_ANIM_SEC := 0.18

const CHIP_BG_TRANSIT := Color(0.14, 0.20, 0.30, 0.92)
const CHIP_BG_ARRIVED := Color(0.12, 0.28, 0.18, 0.95)
const CHIP_BORDER_TRANSIT := Color(0.26, 0.50, 0.85, 0.80)
const CHIP_BORDER_ARRIVED := Color(0.30, 0.82, 0.48, 0.90)
const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := Color(0.62, 0.70, 0.80)
const TIME_COLOR := Color(1.0, 0.82, 0.36)
const ARRIVED_COLOR := Color(0.40, 0.95, 0.56)

var _row: HBoxContainer
var _tween: Tween
var _tick_timer: Timer
var _visible_state := false


func _ready() -> void:
	# Full-width strip just below the HUD; chips are right-aligned so they don't
	# overlap with the action-queue chips that appear on the left/centre.
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = CHIP_PAD_H
	scroll.offset_right = -CHIP_PAD_H
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scroll)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", CHIP_GAP)
	_row.alignment = BoxContainer.ALIGNMENT_END  # align chips to the right
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_row)

	_tick_timer = Timer.new()
	_tick_timer.wait_time = 5.0
	_tick_timer.autostart = false
	_tick_timer.timeout.connect(_refresh)
	add_child(_tick_timer)

	call_deferred("_bind_delivery_manager")


func set_bar_top(y: float) -> void:
	offset_top = y
	offset_bottom = y + CHIP_HEIGHT
	custom_minimum_size = Vector2(0.0, CHIP_HEIGHT)


## Called by hud.gd after relayout so we stay pinned just below the HUD bar.
func reposition(vp_w: float, hud_bottom_y: float) -> void:
	offset_top = hud_bottom_y
	offset_bottom = hud_bottom_y + CHIP_HEIGHT
	set_deferred("size", Vector2(vp_w, CHIP_HEIGHT))


func _bind_delivery_manager() -> void:
	var manager := get_node_or_null("/root/IncomingDeliveryManager")
	if manager == null:
		return
	if manager.has_signal("pending_deliveries_changed"):
		if not manager.pending_deliveries_changed.is_connected(_on_pending_changed):
			manager.pending_deliveries_changed.connect(_on_pending_changed)
	_refresh()


func _on_pending_changed(_pending: Array) -> void:
	_refresh()


func _refresh() -> void:
	for child in _row.get_children():
		child.queue_free()

	var manager := get_node_or_null("/root/IncomingDeliveryManager")
	var pending: Array = []
	if manager != null and manager.has_method("get_pending_deliveries"):
		pending = manager.get_pending_deliveries()

	if pending.is_empty():
		_set_visible_animated(false)
		_tick_timer.stop()
		return

	for delivery in pending:
		if delivery is Dictionary:
			_row.add_child(_build_chip(delivery))

	_set_visible_animated(true)
	if not _tick_timer.is_stopped():
		return
	_tick_timer.start()


func _build_chip(delivery: Dictionary) -> PanelContainer:
	var status := String(delivery.get("status", "ordered"))
	var arrived := status == "at_dock"

	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(0.0, CHIP_HEIGHT)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = CHIP_BG_ARRIVED if arrived else CHIP_BG_TRANSIT
	sb.border_color = CHIP_BORDER_ARRIVED if arrived else CHIP_BORDER_TRANSIT
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)

	# Truck icon (procedural) when in transit; package when at dock
	var icon_tex: Texture2D
	if arrived:
		icon_tex = IconRegistry.product_icon("package")
	else:
		icon_tex = IconRegistry.truck_icon()
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(20.0, 20.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	# Timer only
	var time_lbl := Label.new()
	time_lbl.add_theme_font_size_override("font_size", 13)
	if arrived:
		time_lbl.text = "✓"
		time_lbl.add_theme_color_override("font_color", ARRIVED_COLOR)
	else:
		var mins := _minutes_remaining(delivery)
		time_lbl.text = "%d min" % maxi(1, mins)
		time_lbl.add_theme_color_override("font_color", TIME_COLOR)
	time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(time_lbl)

	chip.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_chip_tapped()
	)

	return chip


func _minutes_remaining(delivery: Dictionary) -> int:
	var game_time := get_node_or_null("/root/GameTimeManager")
	if game_time == null:
		return 0
	var now: float = game_time.get_precise_minutes() if game_time.has_method("get_precise_minutes") else 0.0
	var arrive_at := float(delivery.get("deliver_at_minutes", 0.0))
	return maxi(0, int(ceil(arrive_at - now)))


func _on_chip_tapped() -> void:
	var terminal := get_tree().get_first_node_in_group("computer_terminal_ui")
	if terminal != null and terminal.has_method("open"):
		terminal.open()
	if terminal != null and terminal.has_method("navigate_to"):
		terminal.navigate_to("reorder_products")


func _set_visible_animated(show: bool) -> void:
	if show == _visible_state:
		return
	_visible_state = show
	if _tween:
		_tween.kill()
	if show:
		visible = true
		modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, CHIP_ANIM_SEC)
	else:
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, CHIP_ANIM_SEC)
		_tween.tween_callback(func() -> void: visible = false)
