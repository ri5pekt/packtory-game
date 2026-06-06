extends VBoxContainer

## Reusable base layout for computer terminal feature screens.

signal back_requested

const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")

const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const BTN_MIN_HEIGHT := GameUIThemeScript.BTN_MIN_HEIGHT_COMPACT

var _content_host: VBoxContainer
var _title_label: Label


static func make_scroll_area() -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# SHRINK_BEGIN is critical: content grows to fit its children but does NOT
	# expand to fill the scroll rect, so the scroll bar triggers when content
	# is taller than the visible area.
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	return {"scroll": scroll, "content": content}


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)


func setup_section(title: String, subtitle: String = "") -> void:
	_ensure_built()
	_title_label.text = title
	var subtitle_label := get_node_or_null("ScrollBody/Content/Subtitle") as Label
	if subtitle_label:
		subtitle_label.text = subtitle
		subtitle_label.visible = not subtitle.is_empty()


func get_content_host() -> VBoxContainer:
	_ensure_built()
	return _content_host


func _ensure_built() -> void:
	if _content_host != null:
		return
	_build()


func _build() -> void:
	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.add_theme_constant_override("separation", 8)
	add_child(top)

	var back_btn := _make_button("Back")
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back_btn)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", TEXT_COLOR)
	top.add_child(_title_label)

	var body := VBoxContainer.new()
	body.name = "ScrollBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	add_child(body)

	var scroll_bundle := make_scroll_area()
	scroll_bundle.scroll.name = "Scroll"
	body.add_child(scroll_bundle.scroll)
	_content_host = scroll_bundle.content
	_content_host.name = "Content"

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", GameUIThemeScript.DIM_TEXT)
	_content_host.add_child(subtitle)


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120.0, BTN_MIN_HEIGHT)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = GameUIThemeScript.ACCENT
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = GameUIThemeScript.ACCENT.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)
	return btn
