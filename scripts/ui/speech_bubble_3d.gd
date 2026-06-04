class_name SpeechBubble3D
extends Node3D

## A reusable billboarded speech bubble that holds a content icon. The bubble is a
## clean rounded-rect with a downward tail and a soft border + drop shadow, drawn
## procedurally once and cached. Drop in anywhere and call set_content(texture).
##
## Usage:
##   var b := SpeechBubble3D.new()
##   add_child(b)
##   b.set_content(IconRegistry.get_icon("order_list"))

const BUBBLE_PIXEL_SIZE := 0.0062
const CONTENT_PIXEL_SIZE := 0.0036
# Content sits on the body (texture body centre is above canvas centre because of
# the tail), so nudge it up; tuned to the texture geometry below.
const CONTENT_OFFSET := Vector3(0.0, 0.066, 0.01)
const SHADOW_OFFSET := Vector3(0.022, -0.026, -0.01)

# Texture geometry (in a TEX×TEX canvas).
const TEX := 128
const CX := 64.0
const BODY_CY := 54.0
const BODY_HX := 50.0
const BODY_HY := 38.0
const RADIUS := 18.0
const TAIL_TOP := 84.0
const TAIL_APEX := 116.0
const TAIL_HW := 14.0
const BORDER_W := 3.5

const FILL := Color(1.0, 1.0, 1.0)
const BORDER := Color(0.42, 0.55, 0.74)

static var _bubble_tex: Texture2D

var _bg: Sprite3D
var _content: Sprite3D


func _ready() -> void:
	_build()


func set_content(texture: Texture2D) -> void:
	if _content == null:
		_build()
	_content.texture = texture
	_content.visible = texture != null


func _build() -> void:
	if _bg != null:
		return
	var tex := _get_bubble_texture()

	var shadow := Sprite3D.new()
	shadow.texture = tex
	shadow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shadow.no_depth_test = true
	shadow.pixel_size = BUBBLE_PIXEL_SIZE
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.18)
	shadow.position = SHADOW_OFFSET
	add_child(shadow)

	_bg = Sprite3D.new()
	_bg.texture = tex
	_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bg.no_depth_test = true
	_bg.pixel_size = BUBBLE_PIXEL_SIZE
	add_child(_bg)

	_content = Sprite3D.new()
	_content.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_content.no_depth_test = true
	_content.pixel_size = CONTENT_PIXEL_SIZE
	_content.position = CONTENT_OFFSET
	_content.render_priority = 1  # draw over the bubble bg
	add_child(_content)


# ── procedural texture ────────────────────────────────────────────────────────

static func _get_bubble_texture() -> Texture2D:
	if _bubble_tex != null:
		return _bubble_tex
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for y in range(TEX):
		for x in range(TEX):
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			var outer := _shape_coverage(px, py, 0.0)
			if outer <= 0.004:
				continue
			var inner := _shape_coverage(px, py, BORDER_W)
			var rgb := BORDER.lerp(FILL, inner)
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, outer))

	_bubble_tex = ImageTexture.create_from_image(img)
	return _bubble_tex


## Coverage (0..1, anti-aliased) of the bubble shape shrunk inward by `shrink` px.
static func _shape_coverage(px: float, py: float, shrink: float) -> float:
	return maxf(_body_cov(px, py, shrink), _tail_cov(px, py, shrink))


static func _body_cov(px: float, py: float, shrink: float) -> float:
	var hx := BODY_HX - shrink
	var hy := BODY_HY - shrink
	var r := minf(RADIUS, minf(hx, hy))
	var dx := absf(px - CX) - hx + r
	var dy := absf(py - BODY_CY) - hy + r
	var ax := maxf(dx, 0.0)
	var ay := maxf(dy, 0.0)
	var sdf := sqrt(ax * ax + ay * ay) + minf(maxf(dx, dy), 0.0) - r
	# Feather over ~1px for clean edges.
	return clampf(0.5 - sdf, 0.0, 1.0)


static func _tail_cov(px: float, py: float, shrink: float) -> float:
	var top := TAIL_TOP + shrink
	var apex := TAIL_APEX - shrink
	if py < top - 1.0 or py > apex + 1.0:
		return 0.0
	var t := clampf((py - top) / maxf(apex - top, 0.001), 0.0, 1.0)
	var hw := lerpf(TAIL_HW - shrink, 0.0, t)
	var dx := absf(px - CX) - hw
	var cov_x := clampf(0.5 - dx, 0.0, 1.0)
	var cov_apex := clampf(apex + 1.0 - py, 0.0, 1.0)
	return minf(cov_x, cov_apex)
