extends Control

## Compact queued-action chips below the HUD — same look as bar icon buttons, no backdrop.

const HUD_TOP := 52.0
const BAR_HEIGHT := 40.0
const CHIP_SIZE := 36.0
const CHIP_GAP := 6.0
const PAD_H := 10.0
const ICON_INSET := 8.0

const CHIP_BG := Color(0.16, 0.19, 0.26, 0.85)
const CHIP_BORDER := Color(0.40, 0.46, 0.56, 0.7)
const CHIP_ACTIVE_BG := Color(0.23, 0.28, 0.36, 0.95)
const CHIP_ACTIVE_BORDER := Color(0.26, 0.62, 0.92, 0.95)
const BADGE_TEXT := Color(0.78, 0.83, 0.90)

var _action_queue: ActionQueue
var _scroll: ScrollContainer
var _row: HBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = HUD_TOP
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	_relayout()
	get_viewport().size_changed.connect(_relayout)
	call_deferred("_bind_queue")


func _build() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = PAD_H
	_scroll.offset_right = -PAD_H
	_scroll.offset_top = 2.0
	_scroll.offset_bottom = -2.0
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", CHIP_GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_row)


func _bind_queue() -> void:
	var input := get_tree().root.find_child("GameplayInput", true, false)
	if input == null:
		return
	_action_queue = input.get_node_or_null("ActionQueue") as ActionQueue
	if _action_queue == null:
		return
	if not _action_queue.queue_changed.is_connected(_on_queue_changed):
		_action_queue.queue_changed.connect(_on_queue_changed)
	_on_queue_changed(_action_queue.get_actions())


func _relayout() -> void:
	var vp := get_viewport_rect().size
	set_deferred("size", Vector2(vp.x, BAR_HEIGHT))


func _on_queue_changed(actions: Array) -> void:
	for child in _row.get_children():
		child.queue_free()
	if actions.is_empty():
		visible = false
		return
	visible = true
	var show_index := actions.size() > 1
	for i in actions.size():
		var action := actions[i] as QueuedAction
		if action == null:
			continue
		_row.add_child(_build_chip(action, i + 1, i == 0, show_index))


func _chip_stylebox(is_active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CHIP_ACTIVE_BG if is_active else CHIP_BG
	sb.border_color = CHIP_ACTIVE_BORDER if is_active else CHIP_BORDER
	sb.set_border_width_all(2 if is_active else 1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(ICON_INSET * 0.5)
	return sb


func _build_chip(action: QueuedAction, position: int, is_active: bool, show_index: bool) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(CHIP_SIZE, CHIP_SIZE)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.tooltip_text = "%d. %s" % [position, action.label]
	chip.add_theme_stylebox_override("panel", _chip_stylebox(is_active))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(center)

	var icon_tex := IconRegistry.action_icon(action.icon_id)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		var icon_px := CHIP_SIZE - ICON_INSET
		icon.custom_minimum_size = Vector2(icon_px, icon_px)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)
	else:
		var fallback := Label.new()
		fallback.text = "•"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 14)
		fallback.add_theme_color_override("font_color", BADGE_TEXT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(fallback)

	if show_index:
		var badge := Label.new()
		badge.text = str(position)
		badge.add_theme_font_size_override("font_size", 9)
		badge.add_theme_color_override("font_color", BADGE_TEXT)
		badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		badge.add_theme_constant_override("shadow_offset_x", 1)
		badge.add_theme_constant_override("shadow_offset_y", 1)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -14.0
		badge.offset_top = 2.0
		badge.offset_right = -3.0
		badge.offset_bottom = 12.0
		chip.add_child(badge)

	return chip
