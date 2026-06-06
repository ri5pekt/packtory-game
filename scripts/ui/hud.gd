extends Control

## Top HUD shell — icon buttons on the left, progression stats to their right.
## Inventory bag opens a slide-down panel below the bag button.

const HudProgressionPanelScript = preload("res://scripts/ui/hud_progression_panel.gd")
const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")
const WorkerScript = preload("res://scripts/worker/worker.gd")
const DeliveryTrackerHudScript = preload("res://scripts/ui/delivery_tracker_hud.gd")

const HUD_HEIGHT := HudProgressionPanelScript.PANEL_HEIGHT
const PAD_H := 10.0
const ITEM_GAP := 10.0
const BTN_SIZE := GameUIThemeScript.BTN_MIN_HEIGHT_TOUCH
const BADGE_SIZE := 17.0
const PANEL_ANIM_SEC := 0.20
const TIME_UPDATE_SEC := 5.0

const SLOT_COUNT := WorkerScript.MAX_CARRIED_ENTRIES
const SLOT_COLUMNS := 3
const SLOT_SIZE := 72.0
const SLOT_GAP := 8
const SLOT_LABEL_PAD := 4.0
const SLOT_LABEL_TOP := 3.0
const SLOT_LABEL_HEIGHT := 20.0
const SLOT_ICON_TOP := 22.0
const SLOT_ICON_MAX := 34.0
const PANEL_PAD_H := 14.0
const PANEL_PAD_V := 12.0
const PANEL_TITLE_HEIGHT := 20.0
const PANEL_TITLE_GAP := 8.0

const ACCENT := GameUIThemeScript.ACCENT
const TEXT_COLOR := Color(1.0, 1.0, 1.0)
const DIM_TEXT := GameUIThemeScript.DIM_TEXT_LIGHT
const PANEL_BG := Color(0.10, 0.12, 0.16, 1.0)
const DIM_OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const BADGE_COLOR := Color(0.92, 0.36, 0.26)

var _progression_panel: Control
var _badge_bg: Panel
var _badge_label: Label
var _inv_btn: Button
var _edit_layout_btn: Button
var _inv_panel: PanelContainer
var _inv_list: GridContainer
var _dim_overlay: ColorRect
var _panel_open := false
var _panel_tween: Tween
var _time_timer: Timer
var _worker: Worker
var _worker_bind_attempts := 0
var _delivery_tracker: Control
const MAX_WORKER_BIND_ATTEMPTS := 60


func _ready() -> void:
	add_to_group("hud")
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0.0, HUD_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_bar()
	call_deferred("_build_overlay_and_panel")
	call_deferred("_build_delivery_tracker")
	call_deferred("_relayout")
	get_viewport().size_changed.connect(_relayout)
	call_deferred("_bind_worker")

	_time_timer = Timer.new()
	_time_timer.wait_time = TIME_UPDATE_SEC
	_time_timer.autostart = true
	_time_timer.timeout.connect(_on_time_tick)
	add_child(_time_timer)


func get_progression_panel() -> Control:
	return _progression_panel


func update_progression(
	coins: int = -1,
	day: int = -1,
	game_minutes: int = -1,
	level: int = -1,
	xp: int = -1
) -> void:
	if _progression_panel and _progression_panel.has_method("apply_values"):
		_progression_panel.apply_values(coins, day, game_minutes, level, xp)


func sync_from_save_manager() -> void:
	sync_from_progression_sources()


func sync_from_progression_sources() -> void:
	if _progression_panel and _progression_panel.has_method("bind_progression_sources"):
		_progression_panel.bind_progression_sources()
	elif _progression_panel and _progression_panel.has_method("sync_from_save_manager"):
		_progression_panel.sync_from_save_manager()


func _build_delivery_tracker() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_delivery_tracker = DeliveryTrackerHudScript.new()
	_delivery_tracker.name = "DeliveryTrackerHud"
	_delivery_tracker.z_index = 30
	parent.add_child(_delivery_tracker)
	_delivery_tracker.set_bar_top(HUD_HEIGHT)


func _relayout() -> void:
	var vp := get_viewport_rect().size
	set_deferred("size", Vector2(vp.x, HUD_HEIGHT))
	if _dim_overlay:
		_dim_overlay.set_deferred("size", vp)
	if _inv_panel:
		_sync_inventory_panel_size()
		_position_inv_panel(not _panel_open)
	if _delivery_tracker and _delivery_tracker.has_method("reposition"):
		_delivery_tracker.reposition(vp.x, HUD_HEIGHT)


func _build_bar() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	row.offset_left = PAD_H
	row.offset_right = -PAD_H
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	row.add_child(_player_button())
	row.add_child(_gap(4.0))
	row.add_child(_inventory_button())
	row.add_child(_gap(4.0))
	row.add_child(_edit_layout_button())
	row.add_child(_gap(4.0))
	row.add_child(_settings_button())
	row.add_child(_gap(4.0))
	row.add_child(_debug_button())
	row.add_child(_gap(ITEM_GAP))

	_progression_panel = HudProgressionPanelScript.new()
	_progression_panel.name = "ProgressionPanel"
	_progression_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_progression_panel)
	_progression_panel.ensure_built()
	_progression_panel.bind_progression_sources()


func _player_button() -> Control:
	var btn := _boxed_icon_button("avatar", "🧑")
	btn.pressed.connect(_on_player_pressed)
	return btn


func _edit_layout_button() -> Control:
	var btn := _boxed_icon_button("edit_layout", "▦")
	btn.tooltip_text = "Edit Layout"
	_edit_layout_btn = btn
	btn.pressed.connect(_on_edit_layout_pressed)
	return btn


func _settings_button() -> Control:
	var btn := _boxed_icon_button("settings", "⚙")
	btn.pressed.connect(_on_settings_pressed)
	return btn


func _debug_button() -> Control:
	var btn := _boxed_icon_button("debug", "🐛")
	btn.tooltip_text = "Debug"
	btn.pressed.connect(_on_debug_pressed)
	return btn


func set_edit_layout_visible(visible: bool) -> void:
	if _edit_layout_btn:
		_edit_layout_btn.visible = visible


func get_edit_layout_button() -> Button:
	return _edit_layout_btn


func _inventory_button() -> Control:
	var btn := _boxed_icon_button("inventory", "🎒")
	_inv_btn = btn
	btn.pressed.connect(_on_inventory_pressed)
	btn.clip_contents = false

	_badge_bg = Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = BADGE_COLOR
	bs.set_corner_radius_all(int(BADGE_SIZE / 2.0))
	bs.border_color = Color(0.08, 0.10, 0.14)
	bs.set_border_width_all(2)
	_badge_bg.add_theme_stylebox_override("panel", bs)
	_badge_bg.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge_bg.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge_bg.position = Vector2(
		(BTN_SIZE - BADGE_SIZE) * 0.5,
		BTN_SIZE - BADGE_SIZE + 2.0
	)
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


func _build_overlay_and_panel() -> void:
	var parent := get_parent()
	if parent == null:
		return

	_dim_overlay = ColorRect.new()
	_dim_overlay.name = "InvDimOverlay"
	_dim_overlay.color = DIM_OVERLAY_COLOR
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_overlay.visible = false
	_dim_overlay.z_index = 40
	parent.add_child(_dim_overlay)
	_dim_overlay.set_deferred("size", get_viewport_rect().size)
	parent.move_child(_dim_overlay, get_index() + 1)

	_inv_panel = PanelContainer.new()
	_inv_panel.name = "InventoryPanel"
	_inv_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_inv_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_inv_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_inv_panel.z_index = 50
	_inv_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = ACCENT.darkened(0.25)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 6
	_inv_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(_inv_panel)
	_sync_inventory_panel_size()
	_position_inv_panel(true)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_theme_constant_override("margin_left", int(PANEL_PAD_H))
	margin.add_theme_constant_override("margin_right", int(PANEL_PAD_H))
	margin.add_theme_constant_override("margin_top", int(PANEL_PAD_V))
	margin.add_theme_constant_override("margin_bottom", int(PANEL_PAD_V))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", PANEL_TITLE_GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", DIM_TEXT)
	title.custom_minimum_size.y = PANEL_TITLE_HEIGHT
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	_inv_list = GridContainer.new()
	_inv_list.columns = SLOT_COLUMNS
	_inv_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_inv_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_inv_list.add_theme_constant_override("h_separation", SLOT_GAP)
	_inv_list.add_theme_constant_override("v_separation", SLOT_GAP)
	_inv_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_inv_list)


func notify_world_tap(screen_position: Vector2) -> bool:
	if not _panel_open or _inv_panel == null:
		return false
	if _inv_panel.get_global_rect().has_point(screen_position):
		return true
	_close_panel()
	return false


func _on_inventory_pressed() -> void:
	if _panel_open:
		_close_panel()
	else:
		_populate_inventory()
		_open_panel()


func _inventory_panel_size() -> Vector2:
	var slot_count := _slot_count()
	var columns := mini(SLOT_COLUMNS, maxi(1, slot_count))
	var rows := ceili(float(slot_count) / float(columns))
	var grid_w := columns * SLOT_SIZE + (columns - 1) * SLOT_GAP
	var grid_h := rows * SLOT_SIZE + (rows - 1) * SLOT_GAP
	var inner_w := grid_w
	var inner_h := PANEL_TITLE_HEIGHT + PANEL_TITLE_GAP + grid_h
	var w := inner_w + PANEL_PAD_H * 2.0
	var h := inner_h + PANEL_PAD_V * 2.0
	return Vector2(w, h)


func _slot_count() -> int:
	return SLOT_COUNT


func _sync_inventory_panel_size() -> void:
	if _inv_panel == null:
		return
	var panel_size := _inventory_panel_size()
	_inv_panel.custom_minimum_size = panel_size
	_inv_panel.size = panel_size


func _panel_anchor_x() -> float:
	var w := _inventory_panel_size().x
	var x := PAD_H
	if _inv_btn:
		x = _inv_btn.global_position.x + (_inv_btn.size.x - w) * 0.5
	var vp_w := get_viewport_rect().size.x
	return clampf(x, 8.0, vp_w - w - 8.0)


func _position_inv_panel(hidden_above: bool) -> void:
	if _inv_panel == null:
		return
	var y := HUD_HEIGHT - _inv_panel.size.y if hidden_above else HUD_HEIGHT
	_inv_panel.position = Vector2(_panel_anchor_x(), y)


func _open_panel() -> void:
	_panel_open = true
	_sync_inventory_panel_size()
	_inv_panel.visible = true
	_dim_overlay.visible = true
	_dim_overlay.z_index = 40
	_position_inv_panel(true)
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
	var hidden_y := HUD_HEIGHT - _inv_panel.size.y
	_panel_tween = create_tween()
	_panel_tween.tween_property(_inv_panel, "position:y", hidden_y, PANEL_ANIM_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_panel_tween.tween_callback(func() -> void: _inv_panel.visible = false)


func _populate_inventory() -> void:
	for child in _inv_list.get_children():
		child.queue_free()

	var stacks: Array = _worker.get_inventory_stacks() if _worker else []
	var slot_count := _slot_count()
	for i in range(slot_count):
		if i < stacks.size():
			_inv_list.add_child(_make_slot(stacks[i]))
		else:
			_inv_list.add_child(_make_slot({}))
	_sync_inventory_panel_size()
	if _panel_open:
		_position_inv_panel(false)


func _make_slot(stack: Dictionary) -> Control:
	var product_id := String(stack.get("id", ""))
	var count := int(stack.get("count", 0))
	var is_box := bool(stack.get("is_box", false))
	var is_placeable_box := bool(stack.get("is_placeable_box", false))

	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.clip_contents = true
	slot.mouse_filter = Control.MOUSE_FILTER_STOP if is_placeable_box else Control.MOUSE_FILTER_IGNORE

	var filled := product_id != "" and count > 0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.19, 0.25, 1.0) if filled else Color(0.12, 0.14, 0.18, 1.0)
	sb.border_color = ACCENT.lerp(Color(0.3, 0.34, 0.42), 0.4) if filled else Color(0.25, 0.29, 0.36, 0.9)
	sb.set_border_width_all(2 if filled else 1)
	sb.set_corner_radius_all(10)
	slot.add_theme_stylebox_override("panel", sb)

	if filled:
		if is_placeable_box:
			slot.add_child(
				_make_slot_name(
					"Place\n%s" % String(stack.get("label", "Shelf")),
					Color(0.72, 0.92, 0.78),
					8
				)
			)
			_add_slot_icon(slot, IconRegistry.get_icon("pickup"), SLOT_ICON_MAX - 4, Color(0.72, 0.92, 0.78))
			slot.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_on_placeable_box_pressed(stack)
			)
		elif is_box:
			slot.add_child(_make_slot_name("Box", Color(0.95, 0.88, 0.65), 9))
			_add_slot_icon(slot, IconRegistry.product_icon(product_id), SLOT_ICON_MAX - 4)
			_add_slot_icon(
				slot,
				IconRegistry.get_icon("pickup"),
				16.0,
				Color(0.92, 0.78, 0.52),
				Vector2(4.0 - (SLOT_SIZE - 16.0) * 0.5, SLOT_SIZE - 20.0 - SLOT_ICON_TOP)
			)
			if count > 0:
				slot.tooltip_text = "Sealed box — %d %s inside" % [
					count,
					ProductCatalog.display_name(product_id),
				]
		else:
			slot.add_child(_make_slot_name(ProductCatalog.display_name(product_id)))
			_add_slot_icon(slot, IconRegistry.product_icon(product_id), SLOT_ICON_MAX)
			slot.add_child(_make_slot_qty_badge(count, 11))

	return slot


func _make_slot_name(text: String, color: Color = DIM_TEXT, font_size: int = 8) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.max_lines_visible = 2
	lbl.clip_text = true
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl.offset_left = SLOT_LABEL_PAD
	lbl.offset_right = -SLOT_LABEL_PAD
	lbl.offset_top = SLOT_LABEL_TOP
	lbl.custom_minimum_size.y = SLOT_LABEL_HEIGHT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _make_slot_qty_badge(count: int, font_size: int = 11) -> Control:
	var text := "×%d" % count
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.88)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(2)
	badge.add_theme_stylebox_override("panel", style)
	var qty := Label.new()
	qty.text = text
	qty.add_theme_font_size_override("font_size", font_size)
	qty.add_theme_color_override("font_color", Color.WHITE)
	qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(qty)
	var badge_h := float(font_size + 6)
	var badge_w := 12.0 + float(text.length()) * (float(font_size) * 0.58)
	badge.custom_minimum_size = Vector2(badge_w, badge_h)
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -badge_w - 4.0
	badge.offset_top = -badge_h - 3.0
	badge.offset_right = -4.0
	badge.offset_bottom = -3.0
	return badge


func _add_slot_icon(
	parent: Control,
	tex: Texture2D,
	size_px: float,
	tint: Color = Color.WHITE,
	offset: Vector2 = Vector2.ZERO
) -> void:
	if tex == null:
		return
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(size_px, size_px)
	frame.size = Vector2(size_px, size_px)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = Vector2(
		(SLOT_SIZE - size_px) * 0.5 + offset.x,
		SLOT_ICON_TOP + offset.y
	)
	parent.add_child(frame)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)


func _bind_worker() -> void:
	if _worker != null or not is_inside_tree():
		return
	_worker_bind_attempts += 1
	var tree := get_tree()
	if tree == null:
		return
	var workers := tree.get_nodes_in_group("workers")
	if workers.is_empty():
		if _worker_bind_attempts < MAX_WORKER_BIND_ATTEMPTS:
			call_deferred("_bind_worker")
		return
	_worker = workers[0] as Worker
	if not _worker.inventory_changed.is_connected(_on_inventory_changed):
		_worker.inventory_changed.connect(_on_inventory_changed)
	_on_inventory_changed(_worker.get_inventory_stacks())


func _on_inventory_changed(stacks: Array) -> void:
	var total := _count_inventory_items(stacks)
	_badge_label.text = str(total)
	_badge_bg.visible = total > 0
	if _panel_open:
		_populate_inventory()


func _count_inventory_items(stacks: Array) -> int:
	var total := 0
	for stack in stacks:
		if bool(stack.get("is_box", false)) or bool(stack.get("is_placeable_box", false)):
			total += 1
		else:
			total += int(stack.get("count", 0))
	return total


func _on_placeable_box_pressed(stack: Dictionary) -> void:
	_close_panel()
	var placement := get_tree().get_first_node_in_group("warehouse_placement_mode")
	if placement != null and placement.has_method("begin_placement"):
		placement.begin_placement(stack)


func _on_settings_pressed() -> void:
	if _panel_open:
		_close_panel()
	var debug := get_tree().get_first_node_in_group("debug_panel")
	if debug != null and debug.has_method("is_open") and debug.is_open():
		debug.close()
	var settings := get_tree().get_first_node_in_group("settings_menu")
	if settings != null and settings.has_method("toggle"):
		settings.toggle()


func _on_debug_pressed() -> void:
	if _panel_open:
		_close_panel()
	var settings := get_tree().get_first_node_in_group("settings_menu")
	if settings != null and settings.has_method("is_open") and settings.is_open():
		settings.close()
	var debug := get_tree().get_first_node_in_group("debug_panel")
	if debug != null and debug.has_method("toggle"):
		debug.toggle()


func _on_edit_layout_pressed() -> void:
	if _panel_open:
		_close_panel()
	var edit_mode := get_node_or_null("../../WarehouseEditMode")
	if edit_mode != null and edit_mode.has_method("enter_mode"):
		edit_mode.enter_mode()


func _on_player_pressed() -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("reset_view"):
		rig.reset_view()


func _on_time_tick() -> void:
	if _progression_panel and _progression_panel.has_method("sync_from_save_manager"):
		_progression_panel.sync_from_save_manager()


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
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(width, 1.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
