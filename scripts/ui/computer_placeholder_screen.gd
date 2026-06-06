extends VBoxContainer

## Placeholder screen for computer modules that are not implemented yet.

signal back_requested

const ComputerSectionScreenScript = preload("res://scripts/ui/computer_section_screen.gd")
const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")

const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const CARD_BG := Color(0.12, 0.15, 0.20, 1.0)
const CARD_BORDER := Color(0.28, 0.34, 0.44, 0.9)

var _section_screen: VBoxContainer


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func setup(section: Dictionary) -> void:
	_ensure_built()
	var title := String(section.get("label", "Module"))
	var description := String(section.get("description", ""))
	_section_screen.setup_section(title, description)
	_build_placeholder_body(title)


func get_section_title() -> String:
	_ensure_built()
	if _section_screen == null:
		return ""
	var title := _section_screen.get_node_or_null("TopBar/Title") as Label
	return title.text if title else ""


func _ensure_built() -> void:
	if _section_screen != null:
		return
	_build()


func _build() -> void:
	_section_screen = ComputerSectionScreenScript.new()
	_section_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_section_screen.back_requested.connect(func() -> void: back_requested.emit())
	add_child(_section_screen)


func _build_placeholder_body(title: String) -> void:
	var host: VBoxContainer = _section_screen.get_content_host()
	for child in host.get_children():
		child.queue_free()

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)
	host.add_child(card)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	card.add_child(body)

	var badge := Label.new()
	badge.text = "Coming soon"
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", GameUIThemeScript.ACCENT)
	body.add_child(badge)

	var message := Label.new()
	message.text = "%s will be available in a future update." % title
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", TEXT_COLOR)
	body.add_child(message)
