extends CanvasLayer

## Minimal dev hint for the character showcase scene.

const HINT := (
	"Character Showcase  •  Top: originals  •  Bottom: generated variations  •  "
	+ "Drag pan  •  Scroll zoom  •  F9 → Main game"
)


func _ready() -> void:
	layer = 90
	var label := Label.new()
	label.text = HINT
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_bottom = -10
	label.offset_top = -34
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
