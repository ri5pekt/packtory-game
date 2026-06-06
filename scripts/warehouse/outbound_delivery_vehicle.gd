class_name OutboundDeliveryVehicle
extends Node3D

## Player-owned delivery van for shipping packed online orders.
## Distinct from the morning supply truck on LoadingDock.

enum VanState { IDLE, ON_ROUTE }

signal cargo_changed(loaded_count: int, capacity: int)
signal dispatch_started(package_count: int)
signal dispatch_completed(package_count: int)
signal route_progress_changed(remaining_minutes: float, total_minutes: float)

const OutboundDeliveryConfigScript = preload(
	"res://scripts/gameplay/outbound_delivery_config.gd"
)
const OutboundDispatchConfigScript = preload(
	"res://scripts/gameplay/outbound_dispatch_config.gd"
)
const OutboundTruckStatsScript = preload("res://scripts/gameplay/outbound_truck_stats.gd")
const BillboardScreenScaleScript = preload("res://scripts/shared/billboard_screen_scale.gd")
const VAN_MODEL := (
	"res://blender/assets/kenney_car-kit/Models/GLB format/delivery.glb"
)
const CLICK_LAYER := 1
const VAN_SCALE := 0.5
const APPROACH_Z := 1.1
const FACE_Z := 0.35
const TRUCK_YAW_EAST := 90.0

var _loaded_packages: Array[Dictionary] = []
var _packages_on_route: Array[Dictionary] = []
var _cargo_label: Label3D
var _click_area: Area3D
var _grid: WarehouseGrid
var _state: VanState = VanState.IDLE
var _home_position: Vector3 = Vector3.ZERO
var _home_yaw: float = 0.0
var _route_started_at: float = 0.0
var _route_ends_at: float = 0.0
var _animating: bool = false
var _instant_anim: bool = false
var _cargo_label_base_font := 24
var _applied_label_scale := -1.0


func _ready() -> void:
	add_to_group("outbound_delivery_vehicles")
	call_deferred("_bind_game_time")
	set_process(true)


func _process(_delta: float) -> void:
	_sync_cargo_label_scale()


func _sync_cargo_label_scale() -> void:
	if _cargo_label == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var factor := BillboardScreenScaleScript.get_factor(tree)
	if is_equal_approx(factor, _applied_label_scale):
		return
	_applied_label_scale = factor
	_cargo_label.font_size = BillboardScreenScaleScript.scaled_font_size(_cargo_label_base_font, tree)


func setup(world_position: Vector3, yaw_deg: float) -> void:
	add_to_group("outbound_delivery_vehicles")
	_ensure_grid()
	_home_position = world_position
	_home_yaw = yaw_deg
	position = world_position
	rotation_degrees.y = yaw_deg
	if get_child_count() == 0:
		_build_van()
		_build_click_area()
		_build_cargo_label()
		_build_body_collision()
	else:
		_sync_click_area_layer()
		_click_area = get_node_or_null("ClickArea") as Area3D
	_refresh_cargo_label()
	_update_interaction_state()
	_set_grid_blocked(true)


func get_capacity() -> int:
	return OutboundDeliveryConfigScript.get_package_capacity()


func get_loaded_count() -> int:
	return _loaded_packages.size()


func get_loaded_packages() -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for entry in _loaded_packages:
		copies.append(entry.duplicate())
	return copies


func is_available() -> bool:
	return _state == VanState.IDLE and not _animating


func is_on_route() -> bool:
	return _state == VanState.ON_ROUTE


func can_load_package() -> bool:
	return is_available() and get_loaded_count() < get_capacity()


func get_cargo_summary() -> String:
	if is_on_route():
		return "%d package(s) on route" % _packages_on_route.size()
	return "%d / %d packages" % [get_loaded_count(), get_capacity()]


func get_load_block_reason(worker: Worker) -> String:
	if not is_available():
		return "Delivery van is out on a route."
	if worker == null:
		return "No worker available."
	if not worker.has_package():
		return "You aren't carrying a packed package."
	if not worker.is_online_package():
		return "Only packed online orders can be loaded here."
	if not can_load_package():
		return (
			"Delivery van is full (%s). Upgrade capacity or dispatch before loading more."
			% get_cargo_summary()
		)
	return ""


func can_dispatch() -> bool:
	return is_available() and get_loaded_count() > 0


func get_dispatch_block_reason() -> String:
	if is_on_route():
		return _route_status_message()
	if _animating:
		return "Delivery van is departing."
	if get_loaded_count() == 0:
		return "Load packed online orders before dispatching."
	var economy := _get_economy()
	if economy == null:
		return "Coin balance unavailable."
	if economy.get_coins() < OutboundDispatchConfigScript.dispatch_fee():
		return "Not enough coins to dispatch (%d required)." % OutboundDispatchConfigScript.dispatch_fee()
	return ""


func get_route_progress() -> Dictionary:
	if not is_on_route():
		return {}
	var game_time := _get_game_time()
	var now := float(game_time.get_precise_minutes()) if game_time else 0.0
	var total := maxf(0.001, _route_ends_at - _route_started_at)
	var remaining := maxf(0.0, _route_ends_at - now)
	return {
		"remaining_minutes": remaining,
		"total_minutes": total,
		"progress": clampf(1.0 - remaining / total, 0.0, 1.0),
	}


func try_dispatch(instant_anim: bool = false) -> Dictionary:
	if not can_dispatch():
		return {"ok": false, "reason": _dispatch_failure_reason()}
	var economy := _get_economy()
	if economy == null:
		return {"ok": false, "reason": "no_economy"}
	var fee := OutboundDispatchConfigScript.dispatch_fee()
	if economy.get_coins() < fee:
		return {"ok": false, "reason": "insufficient_coins"}
	var charged: Dictionary = economy.charge_expense(
		fee,
		"outbound_dispatch",
		economy.get_expense_category_delivery(),
		{}
	)
	if int(charged.get("charged", 0)) < fee:
		return {"ok": false, "reason": "insufficient_coins"}
	return _start_dispatch(instant_anim)


func _dispatch_failure_reason() -> String:
	if is_on_route():
		return "on_route"
	if _animating:
		return "departing"
	if get_loaded_count() == 0:
		return "no_cargo"
	return "unavailable"


func load_test_package(meta: Dictionary) -> void:
	if not is_available():
		return
	_loaded_packages.append(meta.duplicate())
	_refresh_cargo_label()
	cargo_changed.emit(get_loaded_count(), get_capacity())


func try_load_from_worker(worker: Worker) -> bool:
	var reason := get_load_block_reason(worker)
	if reason != "":
		return false
	var meta := worker.get_package_meta()
	if not worker.remove_product("package"):
		return false
	_loaded_packages.append(meta)
	_refresh_cargo_label()
	cargo_changed.emit(get_loaded_count(), get_capacity())
	return true


func get_approach_position() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.0, APPROACH_Z)


func get_face_target() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.75, FACE_Z)


func process_route_due() -> void:
	_check_route_completion()


func force_complete_route() -> bool:
	if not is_on_route():
		return false
	_finish_route()
	return true


func export_save_state() -> Dictionary:
	return {
		"loaded_packages": get_loaded_packages(),
		"capacity": get_capacity(),
		"state": "on_route" if is_on_route() else "idle",
		"route_started_at": _route_started_at,
		"route_ends_at": _route_ends_at,
		"packages_on_route": _packages_on_route.duplicate(true),
		"home_position": [_home_position.x, _home_position.y, _home_position.z],
		"home_yaw": _home_yaw,
		"truck_stats": _export_truck_stats(),
	}


func apply_save_state(data: Dictionary) -> void:
	_loaded_packages.clear()
	for entry in data.get("loaded_packages", []):
		_loaded_packages.append(entry.duplicate())
	_packages_on_route.clear()
	for entry in data.get("packages_on_route", []):
		_packages_on_route.append(entry.duplicate())
	var home: Array = data.get("home_position", [])
	if home.size() >= 3:
		_home_position = Vector3(float(home[0]), float(home[1]), float(home[2]))
	_home_yaw = float(data.get("home_yaw", _home_yaw))
	_route_started_at = float(data.get("route_started_at", 0.0))
	_route_ends_at = float(data.get("route_ends_at", 0.0))
	if String(data.get("state", "idle")) == "on_route":
		_state = VanState.ON_ROUTE
		_instant_anim = true
		_set_departed_visual()
	else:
		_state = VanState.IDLE
		position = _home_position
		rotation_degrees.y = _home_yaw
		visible = true
	_refresh_cargo_label()
	_update_interaction_state()
	cargo_changed.emit(get_loaded_count(), get_capacity())
	if data.has("truck_stats"):
		_apply_truck_stats(data.get("truck_stats", {}))
	if is_on_route():
		_emit_route_progress()
		_check_route_completion()


func _export_truck_stats() -> Dictionary:
	return OutboundTruckStatsScript.export_state()


func _apply_truck_stats(data: Variant) -> void:
	if data is Dictionary:
		OutboundTruckStatsScript.apply_state(data)


func _start_dispatch(instant_anim: bool) -> Dictionary:
	_instant_anim = instant_anim
	_packages_on_route.clear()
	for entry in _loaded_packages:
		_packages_on_route.append(entry.duplicate())
	var package_count := _packages_on_route.size()
	_loaded_packages.clear()
	cargo_changed.emit(get_loaded_count(), get_capacity())

	var game_time := _get_game_time()
	var now := float(game_time.get_precise_minutes()) if game_time else 0.0
	_route_started_at = now
	var route_minutes := OutboundDispatchConfigScript.route_duration_minutes(package_count)
	_route_ends_at = now + route_minutes
	_state = VanState.ON_ROUTE
	_update_interaction_state()
	dispatch_started.emit(package_count)
	_emit_route_progress()
	_play_departure()
	_check_route_completion()
	return {"ok": true, "package_count": package_count}


func _play_departure() -> void:
	if _instant_anim:
		_set_departed_visual()
		return
	_animating = true
	_update_interaction_state()
	var exit_pos := _off_screen_position()
	var tween := create_tween()
	tween.tween_property(self, "position", exit_pos, OutboundDispatchConfigScript.DEPART_ANIM_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_set_departed_visual()
		_animating = false
		_update_interaction_state()
	)


func _set_departed_visual() -> void:
	visible = false
	_set_grid_blocked(false)


func _play_return() -> void:
	if _instant_anim:
		position = _home_position
		rotation_degrees.y = _home_yaw
		visible = true
		return
	_animating = true
	_update_interaction_state()
	visible = true
	position = _off_screen_position()
	var tween := create_tween()
	tween.tween_property(self, "position", _home_position, OutboundDispatchConfigScript.RETURN_ANIM_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		rotation_degrees.y = _home_yaw
		_animating = false
		_set_grid_blocked(true)
		_update_interaction_state()
	)


func _off_screen_position() -> Vector3:
	_ensure_grid()
	if _grid:
		var junction := _grid.get_dock_road_junction_world()
		return Vector3(float(_grid.total_size.x) + 4.0, junction.y, junction.z)
	return _home_position + Vector3(8.0, 0.0, 0.0)


func _check_route_completion() -> void:
	if not is_on_route():
		return
	var game_time := _get_game_time()
	if game_time == null:
		return
	if float(game_time.get_precise_minutes()) < _route_ends_at:
		_emit_route_progress()
		return
	_finish_route()


func _finish_route() -> void:
	var fulfilled := _packages_on_route.size()
	var packages := _packages_on_route.duplicate(true)
	var route_total := maxf(0.001, _route_ends_at - _route_started_at)
	_packages_on_route.clear()
	_state = VanState.IDLE
	_route_started_at = 0.0
	_route_ends_at = 0.0
	_fulfill_packages(packages)
	_refresh_cargo_label()
	_update_interaction_state()
	cargo_changed.emit(get_loaded_count(), get_capacity())
	_play_return()
	dispatch_completed.emit(fulfilled)
	_notify_delivery_complete(fulfilled)
	route_progress_changed.emit(0.0, route_total)


func _fulfill_packages(packages: Array) -> void:
	var queue := _get_customer_queue()
	if queue == null:
		return
	for entry in packages:
		if entry is Dictionary:
			queue.notify_online_package_shipped(entry)


func _notify_delivery_complete(count: int) -> void:
	var alerts := get_node_or_null("/root/AlertMessages")
	if alerts != null and alerts.has_method("info"):
		if count == 1:
			alerts.info("Delivery complete — 1 online order fulfilled.")
		else:
			alerts.info("Delivery complete — %d online orders fulfilled." % count)


func _route_status_message() -> String:
	var progress: Dictionary = get_route_progress()
	var remaining := float(progress.get("remaining_minutes", 0.0))
	if remaining <= 0.5:
		return "Delivery van is returning."
	return "Delivery van is on a route (%.0f min remaining)." % ceil(remaining)


func _emit_route_progress() -> void:
	var progress: Dictionary = get_route_progress()
	route_progress_changed.emit(
		float(progress.get("remaining_minutes", 0.0)),
		float(progress.get("total_minutes", 0.0))
	)


func _bind_game_time() -> void:
	var game_time := _get_game_time()
	if game_time == null:
		return
	if game_time.has_signal("minute_advanced"):
		if not game_time.minute_advanced.is_connected(_on_minute_advanced):
			game_time.minute_advanced.connect(_on_minute_advanced)
	if game_time.has_signal("time_changed"):
		if not game_time.time_changed.is_connected(_on_time_changed):
			game_time.time_changed.connect(_on_time_changed)


func _on_minute_advanced(_minutes: int, _day: int) -> void:
	_check_route_completion()


func _on_time_changed(_minutes: int, _day: int) -> void:
	_check_route_completion()


func _update_interaction_state() -> void:
	if _click_area == null:
		_click_area = get_node_or_null("ClickArea") as Area3D
	if _click_area:
		_click_area.input_ray_pickable = is_available()


func _ensure_grid() -> void:
	if _grid != null:
		return
	if is_inside_tree():
		_grid = get_tree().root.get_node_or_null("GridService") as WarehouseGrid
	if _grid == null:
		_grid = get_node_or_null("/root/GridService") as WarehouseGrid


func _get_economy() -> Node:
	return get_node_or_null("/root/EconomyManager")


func _get_game_time() -> Node:
	return get_node_or_null("/root/GameTimeManager")


func _get_customer_queue() -> Node:
	if not is_inside_tree():
		return get_node_or_null("/root/CustomerQueue")
	return get_tree().get_first_node_in_group("customer_queue")


func _build_van() -> void:
	var scene: PackedScene = load(VAN_MODEL)
	if scene == null:
		push_error("OutboundDeliveryVehicle: failed to load %s" % VAN_MODEL)
		return
	var mesh: Node3D = scene.instantiate()
	mesh.name = "Mesh"
	mesh.scale = Vector3.ONE * VAN_SCALE
	add_child(mesh)


func _build_click_area() -> void:
	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = CLICK_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Cab-focused collider — full-truck volume blocked dock boxes behind the van.
	box.size = Vector3(1.6, 1.2, 2.2)
	shape.shape = box
	shape.position = Vector3(0.0, 0.5, -0.35)
	area.add_child(shape)
	add_child(area)
	_click_area = area


func _sync_click_area_layer() -> void:
	var area := get_node_or_null("ClickArea") as Area3D
	if area:
		area.collision_layer = CLICK_LAYER
		_click_area = area


func _build_body_collision() -> void:
	# StaticBody so the player can't walk through the parked van
	var body := StaticBody3D.new()
	body.name = "VanBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.4, 2.8)
	shape.shape = box
	shape.position = Vector3(0.0, 0.7, 0.0)
	body.add_child(shape)
	add_child(body)


func _get_occupied_cells() -> Array[Vector2i]:
	_ensure_grid()
	if _grid == null:
		return []
	var center := _grid.world_to_cell(_home_position)
	return [center, Vector2i(center.x, center.y - 1), Vector2i(center.x, center.y + 1)]


func _set_grid_blocked(blocked: bool) -> void:
	_ensure_grid()
	if _grid == null:
		return
	for cell in _get_occupied_cells():
		if blocked:
			_grid.block_cell(cell)
		else:
			_grid.unblock_cell(cell)


func _build_cargo_label() -> void:
	_cargo_label = Label3D.new()
	_cargo_label.name = "CargoLabel"
	_cargo_label.position = Vector3(0.0, 1.15, 0.0)
	_cargo_label.font_size = _cargo_label_base_font
	_cargo_label.modulate = Color(0.82, 0.95, 0.78)
	_cargo_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_cargo_label)
	_refresh_cargo_label()


func _refresh_cargo_label() -> void:
	if _cargo_label:
		if is_on_route():
			_cargo_label.text = "On route\n%d pkg" % _packages_on_route.size()
		else:
			_cargo_label.text = "Online van\n%s" % get_cargo_summary()
