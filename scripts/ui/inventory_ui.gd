extends Control

## Bottom-centre inventory bar — product icons with stack counts.

const SLOTS := 4
const SLOT_SIZE := Vector2(76, 76)
const GAP := 10.0
const BOTTOM_MARGIN := 18.0
const ICON_INSET := 10.0

var _panels: Array[Panel] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(SLOTS):
		_build_slot()
	_layout()
	get_viewport().size_changed.connect(_layout)
	call_deferred("_bind_worker")


func _build_slot() -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = ICON_INSET
	icon.offset_top = ICON_INSET
	icon.offset_right = -ICON_INSET
	icon.offset_bottom = -ICON_INSET
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)

	var count := Label.new()
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -36.0
	count.offset_top = -22.0
	count.offset_right = -4.0
	count.offset_bottom = -2.0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override("font_size", 14)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(count)

	_panels.append(panel)
	_icons.append(icon)
	_counts.append(count)
	_style_slot(_panels.size() - 1, Color.TRANSPARENT, "", null, 0)


func _layout() -> void:
	var viewport := get_viewport_rect().size
	var total_width := SLOTS * SLOT_SIZE.x + (SLOTS - 1) * GAP
	var start_x := (viewport.x - total_width) * 0.5
	var y := viewport.y - SLOT_SIZE.y - BOTTOM_MARGIN
	for i in range(SLOTS):
		_panels[i].position = Vector2(start_x + i * (SLOT_SIZE.x + GAP), y)
		_panels[i].size = SLOT_SIZE


func set_stacks(stacks: Array) -> void:
	for i in range(SLOTS):
		if i < stacks.size():
			var entry: Dictionary = stacks[i]
			var id := String(entry.get("id", ""))
			var count := int(entry.get("count", 1))
			_style_slot(
				i,
				ProductCatalog.color_of(id),
				id,
				IconRegistry.product_icon(id),
				count
			)
		else:
			_style_slot(i, Color.TRANSPARENT, "", null, 0)


func _style_slot(
	index: int,
	accent: Color,
	product_id: String,
	texture: Texture2D,
	count: int
) -> void:
	var filled := product_id != ""
	var style := StyleBoxFlat.new()
	style.bg_color = accent.lerp(Color(0.1, 0.12, 0.15), 0.45) if filled else Color(0.12, 0.14, 0.18, 0.7)
	style.border_color = accent if filled else Color(0.3, 0.34, 0.4, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_panels[index].add_theme_stylebox_override("panel", style)
	_icons[index].texture = texture
	_icons[index].modulate = Color.WHITE if texture else Color(1, 1, 1, 0.0)
	if filled and count > 1:
		_counts[index].text = "x%d" % count
		_counts[index].modulate = Color.WHITE
	elif filled:
		_counts[index].text = ""
		_counts[index].modulate = Color.WHITE
	else:
		_counts[index].text = ""
		_counts[index].modulate = Color(1, 1, 1, 0.3)


func _bind_worker() -> void:
	var workers := get_tree().get_nodes_in_group("workers")
	if workers.is_empty():
		call_deferred("_bind_worker")
		return
	var worker := workers[0] as Worker
	if not worker.inventory_changed.is_connected(set_stacks):
		worker.inventory_changed.connect(set_stacks)
	set_stacks(worker.get_inventory_stacks())
