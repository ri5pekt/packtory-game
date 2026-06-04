class_name ProductLabel3D
extends Node3D

## A reusable billboarded label: a rounded pill background with a product icon on
## the left and a count on the right. Used above delivery boxes and shelves.
##
##   var lbl := ProductLabel3D.new()
##   add_child(lbl)
##   lbl.set_product("mouse", 6)            # icon + "x6"
##   lbl.set_product("mouse", 4, "/10")     # icon + "4/10" style (suffix override)

const PIXEL_SIZE := 0.0052
const ICON_PIXEL_SIZE := 0.0034
const ICON_Y := -0.02
const TEXT_PIXEL_SIZE := 0.0050
const TEXT_FONT_SIZE := 48

# Pill texture geometry (canvas PILL_W × PILL_H). Taller so the icon fits inside.
const PILL_W := 210
const PILL_H := 130
const PILL_RADIUS := 60.0
const BORDER_W := 3.5
const FILL := Color(0.13, 0.15, 0.20, 0.96)
const BORDER := Color(0.42, 0.48, 0.58, 0.95)

# Local layout (in world units, relative to the pill centre).
const ICON_X := -0.26
const TEXT_X := 0.22

static var _pill_tex: Texture2D

var _bg: Sprite3D
var _icon: Sprite3D
var _label: Label3D


func _ready() -> void:
	_build()


func set_product(product_id: String, count: int, suffix: String = "") -> void:
	if _bg == null:
		_build()
	var icon_tex := IconRegistry.product_icon(product_id)
	_icon.texture = icon_tex
	_icon.visible = icon_tex != null
	if suffix == "":
		_label.text = "x%d" % count
	else:
		_label.text = "%d%s" % [count, suffix]
	# When no icon, centre the text and hide the icon slot.
	_label.position.x = TEXT_X if _icon.visible else 0.0


func set_empty(text: String = "Empty") -> void:
	if _bg == null:
		_build()
	_icon.visible = false
	_label.text = text
	_label.position.x = 0.0


func _build() -> void:
	if _bg != null:
		return
	var tex := _get_pill_texture()

	var shadow := Sprite3D.new()
	shadow.texture = tex
	shadow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shadow.no_depth_test = true
	shadow.pixel_size = PIXEL_SIZE
	shadow.modulate = Color(0, 0, 0, 0.20)
	shadow.position = Vector3(0.012, -0.014, -0.01)
	add_child(shadow)

	_bg = Sprite3D.new()
	_bg.texture = tex
	_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bg.no_depth_test = true
	_bg.pixel_size = PIXEL_SIZE
	add_child(_bg)

	_icon = Sprite3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.pixel_size = ICON_PIXEL_SIZE
	_icon.position = Vector3(ICON_X, ICON_Y, 0.01)
	_icon.render_priority = 1
	add_child(_icon)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	# World-scaled (not fixed_size) so the text scales together with the pill.
	_label.pixel_size = TEXT_PIXEL_SIZE
	_label.font_size = TEXT_FONT_SIZE
	_label.modulate = Color.WHITE
	_label.outline_modulate = Color(0, 0, 0, 0.7)
	_label.outline_size = 8
	_label.position = Vector3(TEXT_X, 0.0, 0.01)
	_label.render_priority = 2
	add_child(_label)


# ── procedural pill texture ───────────────────────────────────────────────────

static func _get_pill_texture() -> Texture2D:
	if _pill_tex != null:
		return _pill_tex
	var img := Image.create(PILL_W, PILL_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(PILL_W) * 0.5
	var cy := float(PILL_H) * 0.5
	var hx := cx
	var hy := cy
	for y in range(PILL_H):
		for x in range(PILL_W):
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			var outer := _pill_cov(px, py, cx, cy, hx, hy, 0.0)
			if outer <= 0.004:
				continue
			var inner := _pill_cov(px, py, cx, cy, hx, hy, BORDER_W)
			var rgb := BORDER.lerp(FILL, inner)
			var a := outer * lerpf(BORDER.a, FILL.a, inner)
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, a))
	_pill_tex = ImageTexture.create_from_image(img)
	return _pill_tex


static func _pill_cov(px: float, py: float, cx: float, cy: float,
		hx: float, hy: float, shrink: float) -> float:
	var ihx := hx - shrink
	var ihy := hy - shrink
	var r := minf(PILL_RADIUS, minf(ihx, ihy))
	var dx := absf(px - cx) - ihx + r
	var dy := absf(py - cy) - ihy + r
	var ax := maxf(dx, 0.0)
	var ay := maxf(dy, 0.0)
	var sdf := sqrt(ax * ax + ay * ay) + minf(maxf(dx, dy), 0.0) - r
	return clampf(0.5 - sdf, 0.0, 1.0)
