class_name SpeechBubble3D
extends Node3D

const BillboardScreenScaleScript = preload("res://scripts/shared/billboard_screen_scale.gd")
const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")

## A reusable billboarded speech bubble that holds a content icon. The bubble is a
## clean rounded-rect with a downward tail and a soft border + drop shadow, drawn
## procedurally once and cached. Drop in anywhere and call set_content(texture).
##
## Usage:
##   var b := SpeechBubble3D.new()
##   add_child(b)
##   b.set_content(IconRegistry.get_icon("order_list"))

const BUBBLE_PIXEL_SIZE := 0.0072
const CONTENT_PIXEL_SIZE := 0.0042
## Icon scale relative to the bubble body (1.0 = legacy sizing).
const CONTENT_VISUAL_SCALE := 1.65
## Normalise status icons to this texture size so 128px PNGs match 64px procedurals.
const CONTENT_TARGET_PX := 64.0
const ORDER_ICON_PX := 42
const ORDER_QTY_FONT := 20
const ORDER_ITEM_GAP := 4
const ORDER_ROW_GAP := 5
const ORDER_CONTENT_SCALE := 1.28
const ORDER_QTY_COLOR := Color(0.18, 0.34, 0.52)
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
var _shadow: Sprite3D
var _content: Sprite3D
var _order_viewport: SubViewport
var _order_list: VBoxContainer
var _order_sprite: Sprite3D
var _order_chip_size := Vector2i.ZERO
var _showing_order := false
var _applied_factor := -1.0
var _visual_scale := 1.0


func set_visual_scale(scale: float) -> void:
	_visual_scale = clampf(scale, 0.45, 1.25)
	_applied_factor = -1.0
	_sync_screen_scale()


func _ready() -> void:
	_build()
	set_process(true)


func _process(_delta: float) -> void:
	_sync_screen_scale()


func set_content(texture: Texture2D) -> void:
	if _content == null:
		_build()
	_showing_order = false
	if _order_sprite:
		_order_sprite.visible = false
	_content.texture = texture
	_content.visible = texture != null
	_applied_factor = -1.0
	_sync_screen_scale()


func set_order_content(order: Dictionary) -> void:
	_build()
	_build_order_chip()
	_showing_order = true
	_content.visible = false
	_rebuild_order_row(order)
	var has_items := _order_list.get_child_count() > 0
	if _order_sprite:
		_order_sprite.visible = has_items
	if has_items:
		call_deferred("_resize_order_viewport")
	_applied_factor = -1.0
	_sync_screen_scale()


func is_showing_order_content() -> bool:
	return _showing_order and _order_sprite != null and _order_sprite.visible


func _build() -> void:
	if _bg != null:
		return
	var tex := _get_bubble_texture()

	_shadow = Sprite3D.new()
	_shadow.texture = tex
	_shadow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_shadow.no_depth_test = true
	_shadow.pixel_size = BUBBLE_PIXEL_SIZE
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.18)
	_shadow.position = SHADOW_OFFSET
	add_child(_shadow)

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
	call_deferred("_sync_screen_scale")


func _sync_screen_scale() -> void:
	if _bg == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var factor := BillboardScreenScaleScript.get_factor(tree)
	if is_equal_approx(factor, _applied_factor):
		return
	_applied_factor = factor
	var bubble_scale := factor * _visual_scale
	if _shadow:
		_shadow.pixel_size = BUBBLE_PIXEL_SIZE * bubble_scale
		_shadow.position = SHADOW_OFFSET * bubble_scale
	_bg.pixel_size = BUBBLE_PIXEL_SIZE * bubble_scale
	if _content and _content.visible:
		_content.pixel_size = _content_pixel_size(bubble_scale, _content.texture)
		_content.position = CONTENT_OFFSET * bubble_scale
	if _showing_order and _order_sprite and _order_sprite.visible and _order_chip_size.x > 0:
		var px := _content_pixel_size(bubble_scale, null) * ORDER_CONTENT_SCALE
		_order_sprite.pixel_size = px
		_order_sprite.position = Vector3(
			0.0,
			CONTENT_OFFSET.y * bubble_scale + float(_order_chip_size.y) * px * 0.5,
			CONTENT_OFFSET.z * bubble_scale
		)


func _content_pixel_size(bubble_scale: float, texture: Texture2D) -> float:
	var px := CONTENT_PIXEL_SIZE * bubble_scale * CONTENT_VISUAL_SCALE
	if texture == null:
		return px
	var tex_px := maxf(float(texture.get_width()), float(texture.get_height()))
	if tex_px <= 0.0:
		return px
	return px * (CONTENT_TARGET_PX / tex_px)


func _build_order_chip() -> void:
	if _order_viewport != null:
		return
	_order_viewport = SubViewport.new()
	_order_viewport.transparent_bg = true
	_order_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_order_viewport)

	_order_list = VBoxContainer.new()
	_order_list.add_theme_constant_override("separation", ORDER_ITEM_GAP)
	_order_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_order_viewport.add_child(_order_list)

	_order_sprite = Sprite3D.new()
	_order_sprite.texture = _order_viewport.get_texture()
	_order_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_order_sprite.no_depth_test = true
	_order_sprite.render_priority = 1
	_order_sprite.visible = false
	add_child(_order_sprite)


func _rebuild_order_row(order: Dictionary) -> void:
	if _order_list == null:
		return
	for child in _order_list.get_children():
		child.queue_free()

	var entries: Array[Dictionary] = []
	for product_id in order:
		var pid := String(product_id)
		if ProductCatalogScript.is_package(pid):
			continue
		var count := int(order[product_id])
		if count <= 0:
			continue
		entries.append({"id": pid, "count": count})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)

	if entries.is_empty():
		_order_chip_size = Vector2i.ZERO
		return

	for entry in entries:
		_order_list.add_child(_make_order_item_row(String(entry.get("id", "")), int(entry.get("count", 0))))


func _resize_order_viewport() -> void:
	if _order_list == null or not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(_order_list):
		return
	var content := _order_list.get_combined_minimum_size()
	_order_chip_size = Vector2i(
		maxi(1, int(ceil(content.x))),
		maxi(1, int(ceil(content.y)))
	)
	_order_list.size = Vector2(_order_chip_size)
	_order_viewport.size = _order_chip_size
	_order_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_applied_factor = -1.0
	_sync_screen_scale()


func _make_order_item_row(product_id: String, count: int) -> Control:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", ORDER_ROW_GAP)
	item.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_tex := IconRegistry.product_icon(product_id)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(ORDER_ICON_PX, ORDER_ICON_PX)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item.add_child(icon)

	var qty := Label.new()
	qty.text = "×%d" % count
	qty.add_theme_font_size_override("font_size", ORDER_QTY_FONT)
	qty.add_theme_color_override("font_color", ORDER_QTY_COLOR)
	qty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.add_child(qty)
	return item


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
