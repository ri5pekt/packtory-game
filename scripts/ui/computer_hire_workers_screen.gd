extends VBoxContainer

## Hire Workers screen inside the computer terminal.

signal back_requested
signal hire_requested(worker_id: String)

const WorkerHireConfigScript = preload("res://scripts/gameplay/worker_hire_config.gd")
const ComputerScreenFeedbackScript = preload("res://scripts/ui/computer_screen_feedback.gd")
const ComputerSectionScreenScript = preload("res://scripts/ui/computer_section_screen.gd")

const TEXT_COLOR := Color(0.92, 0.95, 0.98)
const DIM_TEXT := Color(0.62, 0.70, 0.80)
const ACCENT := Color(0.26, 0.62, 0.92)
const CARD_BG := Color(0.12, 0.15, 0.20, 1.0)
const CARD_BORDER := Color(0.28, 0.34, 0.44, 0.9)
const BTN_MIN_HEIGHT := 48.0

var _catalog_list: VBoxContainer
var _roster_list: VBoxContainer
var _balance_label: Label
var _status_label: Label
var _built := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	ensure_ready()


func ensure_ready() -> void:
	if _built:
		return
	_build()
	_built = true


func get_catalog_card_count() -> int:
	ensure_ready()
	return _catalog_list.get_child_count() if _catalog_list else 0


func get_roster_card_count() -> int:
	ensure_ready()
	return _roster_list.get_child_count() if _roster_list else 0


func get_status_text() -> String:
	ensure_ready()
	return _status_label.text if _status_label else ""


func refresh() -> void:
	ensure_ready()
	_refresh_balance()
	_refresh_roster()
	_refresh_catalog()


func _build() -> void:
	add_theme_constant_override("separation", 10)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	add_child(top)

	var back_btn := _make_button("Back")
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back_btn)

	var heading := Label.new()
	heading.text = "Hire Workers"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", TEXT_COLOR)
	top.add_child(heading)

	var scroll_bundle := ComputerSectionScreenScript.make_scroll_area()
	add_child(scroll_bundle.scroll)
	var body: VBoxContainer = scroll_bundle.content

	_balance_label = Label.new()
	_balance_label.text = "Coins: 0"
	_balance_label.add_theme_font_size_override("font_size", 14)
	_balance_label.add_theme_color_override("font_color", DIM_TEXT)
	body.add_child(_balance_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", TEXT_COLOR)
	body.add_child(_status_label)

	var hint := Label.new()
	hint.text = (
		"Hire generic helpers to expand your warehouse team. "
		+ "Daily salaries are deducted automatically at the end of each day."
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", DIM_TEXT)
	body.add_child(hint)

	var roster_heading := Label.new()
	roster_heading.text = "Current team"
	roster_heading.add_theme_font_size_override("font_size", 16)
	roster_heading.add_theme_color_override("font_color", TEXT_COLOR)
	body.add_child(roster_heading)

	_roster_list = VBoxContainer.new()
	_roster_list.add_theme_constant_override("separation", 6)
	body.add_child(_roster_list)

	var catalog_heading := Label.new()
	catalog_heading.text = "Available to hire"
	catalog_heading.add_theme_font_size_override("font_size", 16)
	catalog_heading.add_theme_color_override("font_color", TEXT_COLOR)
	body.add_child(catalog_heading)

	_catalog_list = VBoxContainer.new()
	_catalog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_list.add_theme_constant_override("separation", 10)
	body.add_child(_catalog_list)

	_bind_hire_manager()
	_refresh_balance()
	_refresh_roster()
	_refresh_catalog()


func _refresh_catalog() -> void:
	if _catalog_list == null:
		return
	for child in _catalog_list.get_children():
		child.queue_free()
	var manager := _get_hire_manager()
	var available: Array = manager.get_available_hire_entries() if manager else []
	if available.is_empty():
		var empty := Label.new()
		empty.text = "Everyone available is already on your team."
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", DIM_TEXT)
		_catalog_list.add_child(empty)
		return
	for entry in available:
		if entry is Dictionary:
			_catalog_list.add_child(_build_catalog_card(entry))


func _refresh_roster() -> void:
	if _roster_list == null:
		return
	for child in _roster_list.get_children():
		child.queue_free()
	var manager := _get_hire_manager()
	var roster: Array = manager.get_roster_summaries() if manager else []
	if roster.is_empty():
		var empty := Label.new()
		empty.text = "No workers in the warehouse yet."
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", DIM_TEXT)
		_roster_list.add_child(empty)
		return
	for summary in roster:
		if summary is Dictionary:
			_roster_list.add_child(_build_roster_card(summary))


func _build_catalog_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)

	var title := Label.new()
	title.text = String(entry.get("display_name", "Worker"))
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	body.add_child(title)

	var description := Label.new()
	description.text = String(entry.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", DIM_TEXT)
	body.add_child(description)

	var cost := Label.new()
	var hire_cost := int(entry.get("hire_cost", 0))
	var salary := int(entry.get("daily_salary", 0))
	cost.text = "Hire: %d coins  •  Salary: %d / day" % [hire_cost, salary]
	cost.add_theme_font_size_override("font_size", 14)
	cost.add_theme_color_override("font_color", ACCENT)
	body.add_child(cost)

	var worker_id := String(entry.get("id", ""))
	var hire_btn := _make_button("Hire %s" % String(entry.get("display_name", "Worker")))
	hire_btn.pressed.connect(func() -> void: _request_hire(worker_id))
	body.add_child(hire_btn)
	return card


func _build_roster_card(summary: Dictionary) -> Label:
	var label := Label.new()
	var name_text := String(summary.get("display_name", "Worker"))
	var salary := int(summary.get("daily_salary", 0))
	var role := String(summary.get("specialization", "general"))
	if bool(summary.get("is_manager", false)):
		label.text = "%s  (Manager)" % name_text
	else:
		label.text = "%s  —  %d coins/day  (%s)" % [name_text, salary, role]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label


func _request_hire(worker_id: String) -> void:
	var manager := _get_hire_manager()
	if manager == null:
		_notify_player("Hiring service unavailable.", true)
		return
	var result: Dictionary = manager.hire_worker(worker_id)
	if bool(result.get("ok", false)):
		var worker: Node = result.get("worker", null)
		var hired_name: String = worker_id
		if worker != null and worker.has_method("get_display_name"):
			hired_name = String(worker.get_display_name())
		_notify_player("%s joined the warehouse team." % hired_name, false)
		hire_requested.emit(worker_id)
		_refresh_balance()
		_refresh_roster()
		_refresh_catalog()
		return
	_notify_player(_reason_message(String(result.get("reason", "")), worker_id), true)


func _reason_message(reason: String, worker_id: String = "") -> String:
	match reason:
		"insufficient_coins":
			var cost := WorkerHireConfigScript.get_hire_cost(worker_id)
			var economy := get_node_or_null("/root/EconomyManager")
			var coins := int(economy.get_coins()) if economy else 0
			return "Not enough coins — need %d, you have %d." % [cost, coins]
		"already_hired":
			return "That worker is already on your team."
		"unknown_worker":
			return "That worker is not available."
		"no_economy":
			return "Coin balance unavailable."
		"spawn_failed":
			return "Couldn't place the worker in the warehouse."
		_:
			return "Could not complete that hire."


func _bind_hire_manager() -> void:
	var manager := _get_hire_manager()
	if manager == null:
		return
	if manager.has_signal("roster_changed"):
		if not manager.roster_changed.is_connected(_on_roster_changed):
			manager.roster_changed.connect(_on_roster_changed)
	var economy := get_node_or_null("/root/EconomyManager")
	if economy != null and economy.has_signal("coins_changed"):
		if not economy.coins_changed.is_connected(_on_coins_changed):
			economy.coins_changed.connect(_on_coins_changed)


func _on_roster_changed(_roster: Array) -> void:
	_refresh_roster()
	_refresh_catalog()


func _on_coins_changed(_balance: int, _delta: int) -> void:
	_refresh_balance()


func _refresh_balance() -> void:
	if _balance_label == null:
		return
	var economy := get_node_or_null("/root/EconomyManager")
	var coins := int(economy.get_coins()) if economy else 0
	_balance_label.text = "Coins: %d" % coins


func _get_hire_manager() -> Node:
	return get_node_or_null("/root/WorkerHireManager")


func _notify_player(message: String, warn: bool) -> void:
	ComputerScreenFeedbackScript.notify(message, _status_label, warn)


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120.0, BTN_MIN_HEIGHT)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACCENT.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)
	return btn
