extends CanvasLayer

## Compact toast bubbles under the active-order tray (right side).

enum Kind { INFO, WARN }

const DISPLAY_SEC := 3.2
const FADE_SEC := 0.18
const POP_SEC := 0.2
const RIGHT_MARGIN := 16.0
const TOAST_MAX_WIDTH := 268.0
const TOAST_GAP := 6.0
const MAX_VISIBLE := 5
const PAD_H := 10.0
const PAD_V := 8.0
const FONT_SIZE := 13
const MIN_TOAST_HEIGHT := 34.0
const HUD_FALLBACK_TOP := 66.0

const STYLES := {
	Kind.INFO: {
		"bg": Color(0.12, 0.16, 0.22, 0.94),
		"border": Color(0.30, 0.55, 0.82, 0.95),
		"text": Color(0.92, 0.95, 0.99),
	},
	Kind.WARN: {
		"bg": Color(0.18, 0.12, 0.10, 0.96),
		"border": Color(0.90, 0.48, 0.28, 0.98),
		"text": Color(0.98, 0.94, 0.90),
	},
}

var _root: Control
var _stack: VBoxContainer


func _ready() -> void:
	layer = 25
	_build_ui()
	get_viewport().size_changed.connect(_relayout)


func warn(text: String) -> void:
	show_message(text, Kind.WARN)


func info(text: String) -> void:
	show_message(text, Kind.INFO)


func show_message(text: String, kind: Kind = Kind.WARN) -> void:
	if text.is_empty() or _stack == null:
		return
	_push_toast(text, kind)
	_trim_stack()
	_relayout()


func relayout_toasts() -> void:
	_relayout()


func get_toast_stack_top() -> float:
	return _resolve_anchor_top()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override("separation", int(TOAST_GAP))
	_root.add_child(_stack)


func _push_toast(text: String, kind: Kind) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(TOAST_MAX_WIDTH, 0.0)
	panel.position.x = 18.0

	var style_data: Dictionary = STYLES[kind]
	var sb := StyleBoxFlat.new()
	sb.bg_color = style_data["bg"]
	sb.border_color = style_data["border"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 3
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(PAD_H))
	margin.add_theme_constant_override("margin_right", int(PAD_H))
	margin.add_theme_constant_override("margin_top", int(PAD_V))
	margin.add_theme_constant_override("margin_bottom", int(PAD_V))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 3
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", style_data["text"])
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(label)

	_stack.add_child(panel)
	_stack.move_child(panel, 0)

	var content_width := TOAST_MAX_WIDTH - PAD_H * 2.0
	label.custom_minimum_size = Vector2(content_width, FONT_SIZE + 4)
	panel.custom_minimum_size = Vector2(TOAST_MAX_WIDTH, MIN_TOAST_HEIGHT)
	panel.size = panel.custom_minimum_size
	call_deferred("_fit_toast_label", panel, label, margin)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = DISPLAY_SEC
	timer.timeout.connect(func() -> void: _dismiss_toast(panel))
	panel.add_child(timer)
	timer.start()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, POP_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:x", 0.0, POP_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fit_toast_label(panel: PanelContainer, label: Label, margin: MarginContainer) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(label):
		return
	var content_width := TOAST_MAX_WIDTH - PAD_H * 2.0
	label.custom_minimum_size.x = content_width
	var text_height := maxf(float(FONT_SIZE + 4), label.get_minimum_size().y)
	label.custom_minimum_size.y = text_height
	var panel_height := maxf(MIN_TOAST_HEIGHT, margin.get_minimum_size().y)
	panel.custom_minimum_size = Vector2(TOAST_MAX_WIDTH, panel_height)
	panel.size = panel.custom_minimum_size


func _dismiss_toast(panel: PanelContainer) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_SEC)
	tween.tween_property(panel, "position:x", 14.0, FADE_SEC)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
	)


func _trim_stack() -> void:
	while _stack.get_child_count() > MAX_VISIBLE:
		var oldest := _stack.get_child(_stack.get_child_count() - 1)
		if oldest is PanelContainer:
			_dismiss_toast(oldest as PanelContainer)
		else:
			oldest.queue_free()


func _relayout() -> void:
	if _stack == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_stack.position = Vector2(
		vp.x - TOAST_MAX_WIDTH - RIGHT_MARGIN,
		_resolve_anchor_top()
	)
	_stack.custom_minimum_size.x = TOAST_MAX_WIDTH


func _resolve_anchor_top() -> float:
	var tree := get_tree()
	if tree:
		var order_ui := tree.get_first_node_in_group("active_order_ui")
		if order_ui != null and order_ui.has_method("get_toast_anchor_top"):
			return float(order_ui.get_toast_anchor_top())
	return HUD_FALLBACK_TOP
