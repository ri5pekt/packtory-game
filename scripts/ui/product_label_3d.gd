class_name ProductLabel3D
extends Node3D

## Billboard chip: icon + quantity rendered in a SubViewport so 2D layout stays
## aligned (Label3D + Sprite3D mix was hard to centre in the pill).

const BillboardScreenScaleScript = preload("res://scripts/shared/billboard_screen_scale.gd")

const BASE_PIXEL_SIZE := 0.0032 * BillboardScreenScaleScript.WORLD_LABEL_READABILITY
const ICON_PX := 38
const PAD := 7
const FONT_SIZE := 24
const ROW_SEP := 6
const CORNER_RADIUS := 11
const BASE_SPRITE_OFFSET_Z := 0.01

var _viewport: SubViewport
var _panel: PanelContainer
var _icon: TextureRect
var _text: Label
var _sprite: Sprite3D
var _built := false
var _applied_factor := -1.0
var _chip_size := Vector2(48.0, 32.0)


func _ready() -> void:
	_build()
	set_process(true)


func _process(_delta: float) -> void:
	_sync_screen_scale()


func set_product(product_id: String, count: int, suffix: String = "") -> void:
	_ensure_built()
	_icon.texture = IconRegistry.product_icon(product_id)
	_icon.visible = _icon.texture != null
	if suffix == "":
		_text.text = "×%d" % count
	else:
		_text.text = "%d%s" % [count, suffix]
	_refresh_chip()


func set_empty(text: String = "Empty") -> void:
	_ensure_built()
	_icon.visible = false
	_text.text = text
	_refresh_chip()


func _ensure_built() -> void:
	if not _built:
		_build()


func _refresh_chip() -> void:
	if _viewport == null:
		return
	call_deferred("_resize_to_content")


func _sync_screen_scale() -> void:
	if _sprite == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var factor := BillboardScreenScaleScript.get_factor(tree)
	if is_equal_approx(factor, _applied_factor):
		return
	_applied_factor = factor
	_update_sprite_transform(BASE_PIXEL_SIZE * factor)


func _update_sprite_transform(pixel_size: float) -> void:
	if _sprite == null:
		return
	_sprite.pixel_size = pixel_size
	_sprite.position = Vector3(
		0.0,
		float(_chip_size.y) * pixel_size * 0.5,
		BASE_SPRITE_OFFSET_Z
	)


func _resize_to_content() -> void:
	if _panel == null or not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(_panel):
		return
	var content := _panel.get_combined_minimum_size()
	_chip_size = Vector2(maxi(1, int(ceil(content.x))), maxi(1, int(ceil(content.y))))
	_panel.size = _chip_size
	_viewport.size = Vector2i(int(_chip_size.x), int(_chip_size.y))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var factor := _applied_factor if _applied_factor > 0.0 else 1.0
	_update_sprite_transform(BASE_PIXEL_SIZE * factor)


func _build() -> void:
	if _built:
		return
	_built = true

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(_chip_size.x), int(_chip_size.y))
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.15, 0.20, 0.96)
	style.border_color = Color(0.42, 0.48, 0.58, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_content_margin_all(PAD)
	_panel.add_theme_stylebox_override("panel", style)
	_viewport.add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(row)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.visible = false
	row.add_child(_icon)

	_text = Label.new()
	_text.add_theme_font_size_override("font_size", FONT_SIZE)
	_text.add_theme_color_override("font_color", Color.WHITE)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_text)

	_sprite = Sprite3D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.no_depth_test = true
	_sprite.pixel_size = BASE_PIXEL_SIZE
	_sprite.render_priority = 2
	_update_sprite_transform(BASE_PIXEL_SIZE)
	add_child(_sprite)

	call_deferred("_refresh_chip")
	call_deferred("_sync_screen_scale")
