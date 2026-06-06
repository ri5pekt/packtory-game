extends Control

## Top-bar progression readout: coins, day, time, stacked XP + reputation bars.

const GameUIThemeScript = preload("res://scripts/shared/game_ui_theme.gd")
const XpBarDisplayScript = preload("res://scripts/ui/xp_bar_display.gd")
const ReputationBarDisplayScript = preload("res://scripts/ui/reputation_bar_display.gd")
const ProgressionConfigScript = preload("res://scripts/gameplay/progression_config.gd")
const ReputationConfigScript = preload("res://scripts/gameplay/reputation_config.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")

const ROW_HEIGHT := 44.0
const PANEL_HEIGHT := ROW_HEIGHT
const ITEM_GAP := 12.0
const COIN_ICON_SIZE := 22.0
const PROGRESS_BAR_WIDTH := 88.0
const PROGRESS_BAR_HEIGHT := 8.0
const PROGRESS_BAR_GAP := 4.0
const LEVEL_LABEL_WIDTH := 26.0
const SHOW_DEV_READOUT := true

const TEXT_COLOR := Color(1.0, 1.0, 1.0)
const DIM_TEXT := GameUIThemeScript.DIM_TEXT_LIGHT

var _built := false
var _coins := 0
var _day := 1
var _game_minutes := GameTimeConfigScript.DAY_START_MINUTES
var _level := 0
var _xp := 0
var _xp_progress := 0.0
var _reputation := ReputationConfigScript.STARTING_REPUTATION
var _reputation_ratio := 1.0

var _coin_label: Label
var _day_label: Label
var _time_label: Label
var _xp_slot: Control
var _xp_bar: Control
var _level_label: Label
var _reputation_slot: Control
var _reputation_bar: Control
var _dev_readout: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, PANEL_HEIGHT)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ensure_built()


func ensure_built() -> void:
	if _built:
		return
	_built = true
	_build()


func get_panel_height() -> float:
	return PANEL_HEIGHT


func set_coins(value: int) -> void:
	_coins = maxi(0, value)
	_refresh_coins()


func set_day(value: int) -> void:
	_day = maxi(1, value)
	_refresh_day()


func set_game_minutes(value: int) -> void:
	_game_minutes = clampi(value, 0, 24 * 60 - 1)
	_refresh_time()


func set_level(value: int) -> void:
	_level = maxi(0, value)
	_refresh_level_xp()


func set_xp(value: int) -> void:
	_xp = maxi(0, value)
	_refresh_level_xp()


func set_xp_progress(progress: float, animate: bool = true) -> void:
	_xp_progress = clampf(progress, 0.0, 1.0)
	if _xp_bar and _xp_bar.has_method("set_state"):
		_xp_bar.set_state(_level, _xp_progress, animate)


func apply_values(
	coins: int = -1,
	day: int = -1,
	game_minutes: int = -1,
	level: int = -1,
	xp: int = -1
) -> void:
	if coins >= 0:
		_coins = coins
	if day >= 0:
		_day = day
	if game_minutes >= 0:
		_game_minutes = game_minutes
	if level >= 0:
		_level = level
	if xp >= 0:
		_xp = xp
	refresh_all()


func refresh_all() -> void:
	_refresh_coins()
	_refresh_day()
	_refresh_time()
	_refresh_level_xp()
	_refresh_reputation()


func sync_from_save_manager() -> void:
	var save := get_node_or_null("/root/SaveManager")
	if save == null:
		return
	apply_values(
		-1,
		save.get_day() if save.has_method("get_day") else -1,
		-1,
		save.get_level() if save.has_method("get_level") else -1,
		save.get_xp() if save.has_method("get_xp") else -1
	)
	sync_from_economy()
	sync_from_game_time()


func sync_from_economy() -> void:
	var economy := get_node_or_null("/root/EconomyManager")
	if economy and economy.has_method("get_coins"):
		set_coins(economy.get_coins())


func bind_progression_sources() -> void:
	bind_economy()
	bind_game_time()
	bind_progression_manager()
	bind_reputation_manager()
	bind_save_manager()


func bind_economy() -> void:
	var economy := get_node_or_null("/root/EconomyManager")
	if economy == null:
		return
	sync_from_economy()
	if not economy.coins_changed.is_connected(_on_coins_changed):
		economy.coins_changed.connect(_on_coins_changed)


func bind_progression_manager() -> void:
	var progression := get_node_or_null("/root/ProgressionManager")
	if progression == null:
		return
	sync_from_progression_manager()
	if not progression.xp_changed.is_connected(_on_xp_changed):
		progression.xp_changed.connect(_on_xp_changed)
	if not progression.level_changed.is_connected(_on_level_changed):
		progression.level_changed.connect(_on_level_changed)


func sync_from_progression_manager() -> void:
	var progression := get_node_or_null("/root/ProgressionManager")
	if progression == null:
		return
	apply_xp_state(
		progression.get_level() if progression.has_method("get_level") else 0,
		progression.get_xp() if progression.has_method("get_xp") else 0,
		progression.get_progress() if progression.has_method("get_progress") else 0.0,
		false
	)


func apply_xp_state(level: int, xp: int, progress: float, animate: bool = true) -> void:
	_level = maxi(0, level)
	_xp = maxi(0, xp)
	set_xp_progress(progress, animate)


func bind_game_time() -> void:
	var game_time := get_node_or_null("/root/GameTimeManager")
	if game_time == null:
		return
	sync_from_game_time()
	if not game_time.time_changed.is_connected(_on_game_time_changed):
		game_time.time_changed.connect(_on_game_time_changed)


func sync_from_game_time() -> void:
	var game_time := get_node_or_null("/root/GameTimeManager")
	if game_time == null:
		return
	set_game_minutes(game_time.get_game_minutes())
	var save := get_node_or_null("/root/SaveManager")
	if save and save.has_method("get_day"):
		set_day(save.get_day())


func bind_save_manager() -> void:
	var save := get_node_or_null("/root/SaveManager")
	if save == null:
		return
	sync_from_save_manager()
	if not save.progression_changed.is_connected(_on_progression_changed):
		save.progression_changed.connect(_on_progression_changed)


func _on_coins_changed(new_balance: int, _delta: int) -> void:
	set_coins(new_balance)


func _on_game_time_changed(minutes: int, _day: int) -> void:
	set_game_minutes(minutes)


func get_display_values() -> Dictionary:
	var ring_progress := _xp_progress
	if _xp_bar and _xp_bar.has_method("get_progress"):
		ring_progress = _xp_bar.get_progress()
	var bar_ratio := _reputation_ratio
	if _reputation_bar and _reputation_bar.has_method("get_ratio"):
		bar_ratio = _reputation_bar.get_ratio()
	return {
		"coins": _coins,
		"day": _day,
		"game_minutes": _game_minutes,
		"level": _level,
		"xp": _xp,
		"xp_progress": ring_progress,
		"reputation": _reputation,
		"reputation_ratio": bar_ratio,
	}


func get_reputation_slot() -> Control:
	ensure_built()
	return _reputation_slot


func get_reputation_bar() -> Control:
	ensure_built()
	return _reputation_bar


func bind_reputation_manager() -> void:
	var reputation := get_node_or_null("/root/ReputationManager")
	if reputation == null:
		return
	sync_from_reputation_manager()
	if not reputation.reputation_changed.is_connected(_on_reputation_changed):
		reputation.reputation_changed.connect(_on_reputation_changed)


func sync_from_reputation_manager() -> void:
	var reputation := get_node_or_null("/root/ReputationManager")
	if reputation == null:
		return
	apply_reputation_state(
		reputation.get_reputation() if reputation.has_method("get_reputation") else _reputation,
		reputation.get_ratio() if reputation.has_method("get_ratio") else _reputation_ratio
	)


func apply_reputation_state(value: int, ratio: float = -1.0) -> void:
	_reputation = ReputationConfigScript.clamp_reputation(value)
	_reputation_ratio = ratio if ratio >= 0.0 else ReputationConfigScript.ratio_for_value(_reputation)
	_refresh_reputation()


func _on_progression_changed() -> void:
	sync_from_save_manager()


func _on_xp_changed(_total_xp: int, _delta: int, progress: float) -> void:
	sync_from_progression_manager()
	set_xp_progress(progress, true)


func _on_reputation_changed(new_value: int, _delta: int, ratio: float) -> void:
	apply_reputation_state(new_value, ratio)


func _on_level_changed(_new_level: int, _old_level: int) -> void:
	sync_from_progression_manager()
	if _xp_bar and _xp_bar.has_method("play_level_up_pulse"):
		_xp_bar.play_level_up_pulse()


func _build() -> void:
	var main_row := HBoxContainer.new()
	main_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	main_row.add_theme_constant_override("separation", 0)
	main_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	main_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_row)

	main_row.add_child(_coins_widget())
	main_row.add_child(_gap(ITEM_GAP))
	main_row.add_child(_datetime_widget())
	main_row.add_child(_gap(ITEM_GAP))
	main_row.add_child(_progress_bars_widget())

	if _should_show_dev_readout():
		main_row.add_child(_gap(6.0))
		_dev_readout = _label("", 9, false)
		_dev_readout.name = "DevProgressReadout"
		_dev_readout.add_theme_color_override("font_color", Color(0.78, 0.92, 0.72))
		main_row.add_child(_dev_readout)

	refresh_all()


func _progress_bars_widget() -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(
		LEVEL_LABEL_WIDTH + PROGRESS_BAR_WIDTH,
		PROGRESS_BAR_HEIGHT * 2.0 + PROGRESS_BAR_GAP
	)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", PROGRESS_BAR_GAP)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(stack)

	var xp_row := _bar_row()
	stack.add_child(xp_row)
	_level_label = _label("Lv0", 11, true)
	_level_label.custom_minimum_size = Vector2(LEVEL_LABEL_WIDTH, PROGRESS_BAR_HEIGHT)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	xp_row.add_child(_level_label)

	_xp_slot = _make_bar_slot("XpBarSlot")
	xp_row.add_child(_xp_slot)
	_xp_bar = XpBarDisplayScript.new()
	_xp_bar.name = "XpBar"
	_xp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_slot.add_child(_xp_bar)

	var rep_row := _bar_row()
	stack.add_child(rep_row)
	var icon_tex := IconRegistry.get_icon("happy")
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(LEVEL_LABEL_WIDTH, 14.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rep_row.add_child(icon)
	else:
		rep_row.add_child(_gap(LEVEL_LABEL_WIDTH))

	_reputation_slot = _make_bar_slot("ReputationSlot")
	rep_row.add_child(_reputation_slot)
	_reputation_bar = ReputationBarDisplayScript.new()
	_reputation_bar.name = "ReputationBar"
	_reputation_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reputation_slot.add_child(_reputation_bar)
	return cell


func _bar_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _make_bar_slot(slot_name: String) -> Control:
	var slot := Control.new()
	slot.name = slot_name
	slot.custom_minimum_size = Vector2(PROGRESS_BAR_WIDTH, PROGRESS_BAR_HEIGHT)
	slot.size = Vector2(PROGRESS_BAR_WIDTH, PROGRESS_BAR_HEIGHT)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot


func _should_show_dev_readout() -> bool:
	return SHOW_DEV_READOUT and OS.is_debug_build()


func _coins_widget() -> Control:
	var cell := _row_cell()
	var icon_tex := IconRegistry.get_icon("coin")
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(COIN_ICON_SIZE, COIN_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
	_coin_label = _label("$0", 15, true)
	cell.add_child(_coin_label)
	return cell


func _datetime_widget() -> Control:
	var cell := _row_cell()
	_day_label = _label("Day 1", 14, false)
	_day_label.add_theme_color_override("font_color", DIM_TEXT)
	cell.add_child(_day_label)
	var sep := _label(" · ", 14, false)
	sep.add_theme_color_override("font_color", DIM_TEXT)
	cell.add_child(sep)
	_time_label = _label("08:00", 15, true)
	cell.add_child(_time_label)
	return cell


func _refresh_coins() -> void:
	if _coin_label:
		_coin_label.text = "$%s" % _format_number(_coins)


func _refresh_day() -> void:
	if _day_label:
		_day_label.text = "Day %d" % _day


func _refresh_time() -> void:
	if _time_label == null:
		return
	var hour := _game_minutes / 60
	var minute := _game_minutes % 60
	_time_label.text = "%02d:%02d" % [hour, minute]


func _refresh_level_xp() -> void:
	var need := ProgressionConfigScript.xp_required_for_level(_level)
	if _level_label:
		_level_label.text = "Lv%d" % _level
	if _xp_bar and _xp_bar.has_method("set_state"):
		var progress := _xp_progress
		if progress <= 0.0 and need > 0:
			progress = clampf(float(_xp) / float(need), 0.0, 1.0)
		_xp_bar.set_state(_level, progress, false)
	if _xp_slot:
		_xp_slot.tooltip_text = "Level %d — XP %d / %d" % [_level, _xp, need]
	_refresh_dev_readout()


func _refresh_reputation() -> void:
	if _reputation_bar and _reputation_bar.has_method("set_reputation"):
		_reputation_bar.set_reputation(_reputation)
	if _reputation_slot:
		_reputation_slot.tooltip_text = "Reputation %d / %d" % [
			_reputation,
			ReputationConfigScript.MAX_REPUTATION,
		]
	_refresh_dev_readout()


func _refresh_dev_readout() -> void:
	if _dev_readout == null:
		return
	var need := ProgressionConfigScript.xp_required_for_level(_level)
	var xp_pct := int(round(_xp_progress * 100.0))
	if need > 0 and _xp_progress <= 0.0:
		xp_pct = int(round(float(_xp) / float(need) * 100.0))
	var rep_pct := int(round(_reputation_ratio * 100.0))
	_dev_readout.text = "XP %d/%d (%d%%) · REP %d/%d (%d%%)" % [
		_xp,
		need,
		xp_pct,
		_reputation,
		ReputationConfigScript.MAX_REPUTATION,
		rep_pct,
	]


func _row_cell() -> HBoxContainer:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 5)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cell


func _gap(width: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(width, 1.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _label(text: String, size: int, bold: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size if not bold else size + 1)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _format_number(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%d,%03d" % [value / 1000, value % 1000]
	return str(value)
