extends Control

## Top HUD — transparent bar, all items left-aligned:
##   [ Coin icon  $1,250 ]  [ Day 1  21:45 ]  [ Player btn ]  [ Bag btn  badge ]
##
## Tapping the bag opens a slide-down inventory panel.
## Tapping outside the panel (or the bag again) closes it.

const HUD_HEIGHT := 52.0
const PAD_H := 10.0         # horizontal padding inside bar
const ITEM_GAP := 14.0      # gap between HUD groups
const COIN_ICON_SIZE := 22.0
const BTN_SIZE := 40.0
const BADGE_SIZE := 17.0
const PANEL_ANIM_SEC := 0.20
const TIME_UPDATE_SEC := 1.0

# Inventory slot grid.
const SLOT_COUNT := 8
const SLOT_COLUMNS := 4
const SLOT_SIZE := 64.0
const SLOT_GAP := 8

const ACCENT := Color(0.26, 0.62, 0.92)
const TEXT_COLOR := Color(1.0, 1.0, 1.0)       # white text reads on any bg
const DIM_TEXT := Color(0.78, 0.83, 0.90)
const PANEL_BG := Color(0.10, 0.12, 0.16, 0.96)
const BADGE_COLOR := Color(0.92, 0.36, 0.26)

var _coins: int = 1250
var _day: int = 1

var _coin_label: Label
var _time_label: Label
var _badge_bg: Panel
var _badge_label: Label
var _inv_panel: Control
var _inv_list: GridContainer
var _dim_overlay: ColorRect     # full-screen catch-tap-outside
var _panel_open := false
var _panel_tween: Tween
var _time_timer: Timer
var _worker: Worker


func _ready() -> void:
	# Stretch to top of screen, height = HUD_HEIGHT.
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, HUD_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_bar()
	call_deferred("_build_overlay_and_panel")
	call_deferred("_relayout")
	get_viewport().size_changed.connect(_relayout)
	call_deferred("_bind_worker")

	_time_timer = Timer.new()
	_time_timer.wait_time = TIME_UPDATE_SEC
	_time_timer.autostart = true
	_time_timer.timeout.connect(_update_time)
	add_child(_time_timer)
	_update_time()


func _relayout() -> void:
	var vp := get_viewport_rect().size
	set_deferred("size", Vector2(vp.x, HUD_HEIGHT))
	if _dim_overlay:
		_dim_overlay.set_deferred("size", vp)
	if _inv_panel:
		_inv_panel.set_deferred("size", Vector2(vp.x, _inv_panel.custom_minimum_size.y))
		if not _panel_open:
			_inv_panel.set_deferred("position", Vector2(0.0, HUD_HEIGHT))


# ── bar (transparent, left-aligned) ──────────────────────────────────────────

func _build_bar() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	row.offset_left = PAD_H
	row.offset_right = -PAD_H
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	row.add_child(_coins_widget())
	row.add_child(_gap(ITEM_GAP))
	row.add_child(_datetime_widget())
	row.add_child(_gap(ITEM_GAP))
	row.add_child(_player_button())
	row.add_child(_gap(4.0))
	row.add_child(_inventory_button())


func _coins_widget() -> Control:
	var c := _row_cell()
	var icon_tex := IconRegistry.get_icon("coin")
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(COIN_ICON_SIZE, COIN_ICON_SIZE)
		icon.size = Vector2(COIN_ICON_SIZE, COIN_ICON_SIZE)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(icon)
	_coin_label = _label("$%s" % _format_number(_coins), 15, true)
	c.add_child(_coin_label)
	return c


func _datetime_widget() -> Control:
	var c := _row_cell()
	var day_lbl := _label("Day %d" % _day, 14, false)
	day_lbl.add_theme_color_override("font_color", DIM_TEXT)
	c.add_child(day_lbl)
	var sep := _label(" · ", 14, false)
	sep.add_theme_color_override("font_color", DIM_TEXT)
	c.add_child(sep)
	_time_label = _label("--:--", 15, true)
	c.add_child(_time_label)
	return c


func _player_button() -> Control:
	var btn := _boxed_icon_button("avatar", "🧑")
	btn.pressed.connect(_on_player_pressed)
	return btn


func _inventory_button() -> Control:
	var btn := _boxed_icon_button("inventory", "🎒")
	btn.pressed.connect(_on_inventory_pressed)
	btn.clip_contents = false

	# Badge: rounded red pill over the button's top-right corner.
	_badge_bg = Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = BADGE_COLOR
	bs.set_corner_radius_all(int(BADGE_SIZE / 2.0))
	bs.border_color = Color(0.08, 0.10, 0.14)
	bs.set_border_width_all(2)
	_badge_bg.add_theme_stylebox_override("panel", bs)
	_badge_bg.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge_bg.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge_bg.position = Vector2(BTN_SIZE - BADGE_SIZE + 4.0, -5.0)
	_badge_bg.visible = false
	_badge_bg.z_index = 5
	_badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(_badge_bg)

	_badge_label = Label.new()
	_badge_label.add_theme_font_size_override("font_size", 11)
	_badge_label.add_theme_color_override("font_color", Color.WHITE)
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_bg.add_child(_badge_label)

	return btn


# ── dim overlay + inventory panel (added as siblings in the CanvasLayer) ──────

func _build_overlay_and_panel() -> void:
	var parent := get_parent()
	if parent == null:
		return

	# Full-screen invisible overlay that catches taps outside the panel.
	_dim_overlay = ColorRect.new()
	_dim_overlay.name = "InvDimOverlay"
	_dim_overlay.color = Color(0, 0, 0, 0)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim_overlay.visible = false
	_dim_overlay.gui_input.connect(_on_overlay_input)
	parent.add_child(_dim_overlay)
	_dim_overlay.set_deferred("size", get_viewport_rect().size)
	# Make sure it sits between bar and panel in Z order.
	parent.move_child(_dim_overlay, get_index() + 1)

	# Slide-down inventory panel.
	_inv_panel = Control.new()
	_inv_panel.name = "InventoryPanel"
	var rows := ceili(float(SLOT_COUNT) / float(SLOT_COLUMNS))
	var panel_h := 12.0 + 22.0 + 8.0 + rows * SLOT_SIZE + (rows - 1) * SLOT_GAP + 14.0
	_inv_panel.custom_minimum_size = Vector2(0, panel_h)
	_inv_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_inv_panel.visible = false
	parent.add_child(_inv_panel)
	_inv_panel.set_deferred("size", Vector2(get_viewport_rect().size.x,
		_inv_panel.custom_minimum_size.y))
	_inv_panel.set_deferred("position", Vector2(0.0, HUD_HEIGHT))

	var bg := ColorRect.new()
	bg.color = PANEL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_panel.add_child(bg)

	var bline := ColorRect.new()
	bline.color = ACCENT.darkened(0.3)
	bline.custom_minimum_size = Vector2(0, 1)
	bline.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bline.offset_top = -1.0
	bline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_panel.add_child(bline)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.78, 0.83, 0.90))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	_inv_list = GridContainer.new()
	_inv_list.columns = SLOT_COLUMNS
	_inv_list.add_theme_constant_override("h_separation", SLOT_GAP)
	_inv_list.add_theme_constant_override("v_separation", SLOT_GAP)
	_inv_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_inv_list)


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close_panel()


# ── open / close ──────────────────────────────────────────────────────────────

func _on_inventory_pressed() -> void:
	if _panel_open:
		_close_panel()
	else:
		_populate_inventory()
		_open_panel()


func _open_panel() -> void:
	_panel_open = true
	_inv_panel.visible = true
	_dim_overlay.visible = true
	# Start above: slide down.
	_inv_panel.position = Vector2(0.0, HUD_HEIGHT - _inv_panel.size.y)
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(_inv_panel, "position:y", HUD_HEIGHT, PANEL_ANIM_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_panel() -> void:
	_panel_open = false
	_dim_overlay.visible = false
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(
		_inv_panel, "position:y",
		HUD_HEIGHT - _inv_panel.size.y, PANEL_ANIM_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_panel_tween.tween_callback(func() -> void: _inv_panel.visible = false)


# ── inventory rows ────────────────────────────────────────────────────────────

func _populate_inventory() -> void:
	for child in _inv_list.get_children():
		child.queue_free()

	var stacks: Array = _worker.get_inventory_stacks() if _worker else []
	for i in range(SLOT_COUNT):
		if i < stacks.size():
			var st: Dictionary = stacks[i]
			_inv_list.add_child(_make_slot(String(st.get("id", "")), int(st.get("count", 0))))
		else:
			_inv_list.add_child(_make_slot("", 0))


func _make_slot(product_id: String, count: int) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var filled := product_id != "" and count > 0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.19, 0.25, 0.9) if filled else Color(0.12, 0.14, 0.18, 0.65)
	sb.border_color = ACCENT.lerp(Color(0.3, 0.34, 0.42), 0.4) if filled else Color(0.25, 0.29, 0.36, 0.8)
	sb.set_border_width_all(2 if filled else 1)
	sb.set_corner_radius_all(10)
	slot.add_theme_stylebox_override("panel", sb)

	if filled:
		var icon_tex := IconRegistry.product_icon(product_id)
		if icon_tex:
			var icon := TextureRect.new()
			icon.texture = icon_tex
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 6; icon.offset_top = 4
			icon.offset_right = -6; icon.offset_bottom = -12
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.clip_contents = true
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)
		# Count chip bottom-right.
		var qty := Label.new()
		qty.text = "×%d" % count
		qty.add_theme_font_size_override("font_size", 13)
		qty.add_theme_color_override("font_color", Color.WHITE)
		qty.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		qty.add_theme_constant_override("shadow_offset_x", 1)
		qty.add_theme_constant_override("shadow_offset_y", 1)
		qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty.set_anchors_preset(Control.PRESET_FULL_RECT)
		qty.offset_right = -5; qty.offset_bottom = -2
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(qty)

	return slot


# ── worker ────────────────────────────────────────────────────────────────────

func _bind_worker() -> void:
	var workers := get_tree().get_nodes_in_group("workers")
	if workers.is_empty():
		call_deferred("_bind_worker")
		return
	_worker = workers[0] as Worker
	if not _worker.inventory_changed.is_connected(_on_inventory_changed):
		_worker.inventory_changed.connect(_on_inventory_changed)
	_on_inventory_changed(_worker.get_inventory_stacks())


func _on_inventory_changed(stacks: Array) -> void:
	var total := 0
	for stack in stacks:
		total += int(stack.get("count", 0))
	_badge_label.text = str(total)
	_badge_bg.visible = total > 0
	if _panel_open:
		_populate_inventory()


# ── player focus ──────────────────────────────────────────────────────────────

func _on_player_pressed() -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("reset_view"):
		rig.reset_view()


# ── time ──────────────────────────────────────────────────────────────────────

func _update_time() -> void:
	var t := Time.get_time_dict_from_system()
	_time_label.text = "%02d:%02d" % [int(t.get("hour", 0)), int(t.get("minute", 0))]


# ── helpers ───────────────────────────────────────────────────────────────────

func _row_cell() -> HBoxContainer:
	var c := HBoxContainer.new()
	c.add_theme_constant_override("separation", 5)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A square button with a rounded "box" background and an icon (or emoji fallback).
func _boxed_icon_button(icon_id: String, fallback_emoji: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	btn.size = Vector2(BTN_SIZE, BTN_SIZE)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	var tex := IconRegistry.get_icon(icon_id)
	if tex:
		btn.icon = tex
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", int(BTN_SIZE - 12))
	else:
		btn.text = fallback_emoji
		btn.add_theme_font_size_override("font_size", 22)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.19, 0.26, 0.85)
	sb.border_color = Color(0.40, 0.46, 0.56, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(11)
	sb.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.23, 0.28, 0.36, 0.95)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("focus", sb)
	return btn


func _gap(width: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(width, 1)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _label(text: String, size: int, bold: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size if not bold else size + 1)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	# Subtle drop shadow so text reads over any game background.
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _format_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (float(n) / 1000000.0)
	if n >= 1000:
		return "%d,%03d" % [n / 1000, n % 1000]
	return str(n)
