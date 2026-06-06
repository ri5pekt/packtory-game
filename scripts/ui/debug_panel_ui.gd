extends Control

## Developer debug drawer — toggles visual overlays and tools.

signal closed

const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")

const PANEL_BG := Color(0.08, 0.10, 0.14, 0.98)
const ACCENT := GameUIThemeScript.ACCENT
const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := GameUIThemeScript.DIM_TEXT
const PANEL_WIDTH := 280.0
const PANEL_MARGIN := 14.0

var _open := false
var _built := false
var _overlay: ColorRect
var _panel: PanelContainer
var _display_tiles_btn: Button
var _tile_labels_btn: Button
var _tile_coords_btn: Button


func _ready() -> void:
	add_to_group("debug_panel")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ensure_built()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_relayout):
		viewport.size_changed.connect(_relayout)
	visible = false


func ensure_built() -> void:
	if _built:
		return
	_built = true
	_build()


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	ensure_built()
	_open = true
	visible = true
	_overlay.visible = true
	_panel.visible = true
	_sync_toggles()
	_relayout()


func close() -> void:
	ensure_built()
	if not _open:
		return
	_open = false
	visible = false
	_overlay.visible = false
	_panel.visible = false
	closed.emit()


func notify_world_tap(screen_position: Vector2) -> bool:
	if not _open:
		return false
	if _panel.get_global_rect().has_point(screen_position):
		return true
	close()
	return true


func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "DimOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.25)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = ACCENT.darkened(0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var root_col := VBoxContainer.new()
	root_col.add_theme_constant_override("separation", 12)
	margin.add_child(root_col)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_col.add_child(title_row)

	var title := Label.new()
	title.text = "Debug"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.tooltip_text = "Close"
	close_btn.custom_minimum_size = Vector2(40.0, 40.0)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(close)
	title_row.add_child(close_btn)

	var hint := Label.new()
	hint.text = "Visual overlays"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", DIM_TEXT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_col.add_child(hint)

	_display_tiles_btn = _make_toggle_button("Display tiles")
	_display_tiles_btn.toggled.connect(_on_display_tiles_toggled)
	root_col.add_child(_display_tiles_btn)

	_tile_labels_btn = _make_toggle_button("Label all tiles")
	_tile_labels_btn.toggled.connect(_on_tile_labels_toggled)
	root_col.add_child(_tile_labels_btn)

	_tile_coords_btn = _make_toggle_button("Show tile on hover")
	_tile_coords_btn.toggled.connect(_on_tile_coords_toggled)
	root_col.add_child(_tile_coords_btn)


func _sync_tile_hud() -> void:
	var hud := _get_tile_debug_hud()
	if hud == null:
		return
	var overlay := _get_tile_overlay()
	var active := overlay != null and overlay.is_coords_on_hover_enabled()
	if hud.has_method("set_active"):
		hud.call_deferred("set_active", active)


func _get_tile_debug_hud() -> CanvasLayer:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("grid_tile_debug_hud")
	if nodes.is_empty():
		return null
	return nodes[0] as CanvasLayer


func _make_toggle_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0.0, GameUIThemeScript.BTN_MIN_HEIGHT_COMPACT)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.17, 0.22, 1.0)
	normal.border_color = Color(0.28, 0.34, 0.42, 0.9)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = ACCENT.darkened(0.55)
	pressed.border_color = ACCENT
	pressed.set_border_width_all(2)
	btn.add_theme_stylebox_override("pressed", pressed)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.22, 0.28, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	return btn


func _sync_toggles() -> void:
	var overlay := _get_tile_overlay()
	if overlay == null:
		return
	if _display_tiles_btn != null:
		_display_tiles_btn.set_pressed_no_signal(overlay.is_display_enabled())
	if _tile_labels_btn != null:
		_tile_labels_btn.set_pressed_no_signal(overlay.is_tile_labels_enabled())
	if _tile_coords_btn != null:
		_tile_coords_btn.set_pressed_no_signal(overlay.is_coords_on_hover_enabled())
	_sync_tile_hud()


func _on_display_tiles_toggled(enabled: bool) -> void:
	var overlay := _get_tile_overlay()
	if overlay == null:
		_display_tiles_btn.set_pressed_no_signal(false)
		return
	overlay.set_display_enabled(enabled)


func _on_tile_labels_toggled(enabled: bool) -> void:
	var overlay := _get_tile_overlay()
	if overlay == null:
		_tile_labels_btn.set_pressed_no_signal(false)
		return
	overlay.set_tile_labels_enabled(enabled)


func _on_tile_coords_toggled(enabled: bool) -> void:
	var overlay := _get_tile_overlay()
	if overlay == null:
		_tile_coords_btn.set_pressed_no_signal(false)
		return
	overlay.set_coords_on_hover_enabled(enabled)
	_sync_tile_hud()


func _get_tile_overlay() -> GridTileDebugOverlay:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("grid_tile_debug_overlay")
	if nodes.is_empty():
		return null
	return nodes[0] as GridTileDebugOverlay


func _on_overlay_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			close()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			close()
			get_viewport().set_input_as_handled()


func _relayout() -> void:
	if not _built:
		return
	var vp := get_viewport_rect().size
	_overlay.set_deferred("size", vp)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	call_deferred("_position_panel", vp)


func _position_panel(vp: Vector2) -> void:
	var panel_h := _panel.get_combined_minimum_size().y
	_panel.size = Vector2(PANEL_WIDTH, panel_h)
	_panel.position = Vector2(PANEL_MARGIN, vp.y - panel_h - PANEL_MARGIN)
