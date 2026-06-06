class_name Customer
extends Node3D

## A shopper that walks in along a waypoint path, queues, and carries an order.
## Queue status icons (waiting, impatient, ready to leave, etc.) are shown via
## CustomerStatusIndicator above the head.

signal arrived_at_slot(customer: Customer)
signal departed(customer: Customer)

enum State { ARRIVING, PENDING, TAKEN, WAITING_PICKUP, REPOSITIONING, DEPARTING }

const WALK_SPEED := 1.6
const ARRIVE_DISTANCE := 0.06
const MODEL_SCALE := 1.0
const CustomerPatienceConfigScript = preload("res://scripts/gameplay/customer_patience_config.gd")
const CustomerStatusIndicatorScript = preload("res://scripts/ui/customer_status_indicator.gd")
const CustomerStatusScript = preload("res://scripts/gameplay/customer_status.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")
const ReceptionTableScript = preload("res://scripts/warehouse/reception_table.gd")
const CLICK_LAYER := 1
const CUSTOMER_BODY_LAYER := 4
const BODY_RADIUS := 0.32   # smaller so queued shoppers can stand closer
const BODY_HEIGHT := 1.05
# Customers face north (-Z); the worker stands on that side, not behind the queue line.
const APPROACH_OFFSET := Vector3(0.0, 0.0, -1.05)
const QUEUE_SLOT_TOLERANCE := 0.12
const REPATH_STUCK_SEC := 0.4

static var _active_instances: Array[Customer] = []

var order: Dictionary = {}
var state: int = State.ARRIVING
var _entered_warehouse := false

var _waypoints: Array[Vector3] = []
var _wp_index := 0
var _nav_targets: Array[Vector3] = []
var _nav_stuck_time := 0.0
var _anim: AnimationPlayer
var _walk_anim := ""
var _idle_anim := ""
var _status_indicator: Node3D
var _click_area: Area3D
var _body: StaticBody3D
var _grid: WarehouseGrid
var _pathfinding: Pathfinding
var assigned_slot: Vector3 = Vector3.ZERO
var _model_path := ""
var _tracking_queue_wait := false
var _queue_wait_origin_set := false
var _queue_wait_started_day := GameTimeConfigScript.STARTING_DAY
var _queue_wait_started_minutes := float(GameTimeConfigScript.DAY_START_MINUTES)
var _queue_wait_started_real_ms := 0


func setup(
	model_path: String,
	waypoints: Array[Vector3],
	order_data: Dictionary,
	slot: Vector3,
	entered_warehouse: bool = true
) -> void:
	order = order_data
	_model_path = model_path
	assigned_slot = slot
	position = waypoints[0]
	_entered_warehouse = entered_warehouse
	if _entered_warehouse:
		_register_as_warehouse_customer()
	_bind_pathfinding()

	_build_model(model_path)
	_build_body_collision()
	_build_click_area()
	_attach_status_indicator()
	clear_queue_status()
	_start_path(waypoints.slice(1), State.ARRIVING)


func get_model_path() -> String:
	return _model_path


func has_entered_warehouse() -> bool:
	return _entered_warehouse


const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")


func export_save_state() -> Dictionary:
	return {
		"model_path": _model_path,
		"state": state,
		"order": order.duplicate(),
		"position": SaveManagerScript.vec3_to_array(global_position),
		"yaw": rotation_degrees.y,
		"queue_wait_started_day": _queue_wait_started_day,
		"queue_wait_started_minutes": _queue_wait_started_minutes,
		"queue_wait_origin_set": _queue_wait_origin_set,
		"tracking_queue_wait": _tracking_queue_wait,
	}


func apply_save_state(data: Dictionary, slot: Vector3) -> void:
	_model_path = String(
		data.get("model_path", "res://blender/assets/kenney_mini-characters/Models/GLB format/character-male-a.glb")
	)
	order = data.get("order", {}).duplicate()
	assigned_slot = slot
	global_position = SaveManagerScript.array_to_vec3(data.get("position", [0, 0, 0]))
	rotation_degrees.y = float(data.get("yaw", 0.0))
	_entered_warehouse = true
	_register_as_warehouse_customer()
	_bind_pathfinding()
	_build_model(_model_path)
	_build_body_collision()
	_build_click_area()
	_attach_status_indicator()
	_queue_wait_started_day = int(
		data.get("queue_wait_started_day", GameTimeConfigScript.STARTING_DAY)
	)
	_queue_wait_started_minutes = float(
		data.get("queue_wait_started_minutes", GameTimeConfigScript.DAY_START_MINUTES)
	)
	_queue_wait_origin_set = bool(data.get("queue_wait_origin_set", false))
	_tracking_queue_wait = bool(data.get("tracking_queue_wait", false))
	state = int(data.get("state", State.PENDING))
	if state == State.PENDING and _tracking_queue_wait:
		_capture_queue_wait_origin()
	_wp_index = 0
	_nav_targets.clear()
	_play_idle()
	_update_clickable()


func mark_entered_warehouse() -> void:
	if _entered_warehouse:
		return
	_entered_warehouse = true
	_register_as_warehouse_customer()
	_update_clickable()


func _register_as_warehouse_customer() -> void:
	if not is_in_group("customers"):
		add_to_group("customers")
	if self not in _active_instances:
		_register_instance()


func has_pending_order() -> bool:
	return state == State.PENDING


func is_departing() -> bool:
	return state == State.DEPARTING


func is_in_queue() -> bool:
	return state != State.DEPARTING and state != State.ARRIVING


func is_waiting_pickup() -> bool:
	return state == State.WAITING_PICKUP


func is_interactive() -> bool:
	# TAKEN is interactive too so the player can tap the customer mid-pack and
	# queue the fulfill action (executes once packing finishes).
	return (
		state == State.PENDING
		or state == State.TAKEN
		or state == State.WAITING_PICKUP
	)


func set_order_taken() -> void:
	state = State.TAKEN
	stop_queue_wait_tracking()
	_update_clickable()


func set_pending() -> void:
	state = State.PENDING
	resume_queue_wait_tracking()
	_update_clickable()


func set_waiting_pickup() -> void:
	state = State.WAITING_PICKUP
	_update_clickable()


func ensure_status_indicator() -> void:
	_attach_status_indicator()


func set_queue_status(kind: int) -> void:
	if not _entered_warehouse:
		clear_queue_status()
		return
	_attach_status_indicator()
	if _status_indicator:
		_status_indicator.set_status(kind)
	_update_clickable()


func set_queue_order(order: Dictionary) -> void:
	if not _entered_warehouse:
		clear_queue_status()
		return
	_attach_status_indicator()
	if _status_indicator:
		_status_indicator.set_order_content(order)
	_update_clickable()


func clear_queue_status() -> void:
	set_queue_status(CustomerStatusScript.Kind.NONE)


func get_queue_status() -> int:
	if _status_indicator == null:
		return CustomerStatusScript.Kind.NONE
	return _status_indicator.get_status()


func is_queue_status_visible() -> bool:
	return _status_indicator != null and _status_indicator.is_shown()


func is_queue_order_visible() -> bool:
	return _status_indicator != null and _status_indicator.is_showing_order()


func get_queue_displayed_order() -> Dictionary:
	if _status_indicator == null:
		return {}
	return _status_indicator.get_displayed_order()


func walk_to_slot(target: Vector3) -> void:
	if state == State.DEPARTING or state == State.ARRIVING:
		return
	assigned_slot = target
	if is_at_queue_slot(target):
		return
	_walk_to_target(target, State.REPOSITIONING)


## Re-path a shopper still walking in so they target an updated queue slot.
func redirect_to_slot(slot: Vector3) -> void:
	if state == State.DEPARTING:
		return
	assigned_slot = slot
	if is_at_queue_slot(slot):
		if state == State.ARRIVING:
			state = State.PENDING
			_play_idle()
			_face(_queue_face_dir())
			_on_reached_queue_slot()
		return
	_start_path([slot], State.ARRIVING)


func is_at_queue_slot(slot: Vector3) -> bool:
	var flat := Vector3(slot.x - global_position.x, 0.0, slot.z - global_position.z)
	return flat.length() <= ARRIVE_DISTANCE


func begin_queue_wait_tracking() -> void:
	if _tracking_queue_wait:
		return
	_tracking_queue_wait = true
	if not _queue_wait_origin_set:
		_capture_queue_wait_origin()


func resume_queue_wait_tracking() -> void:
	if not _queue_wait_origin_set:
		begin_queue_wait_tracking()
		return
	_tracking_queue_wait = true


func stop_queue_wait_tracking() -> void:
	_tracking_queue_wait = false


func reset_queue_wait_tracking() -> void:
	_tracking_queue_wait = false
	_queue_wait_origin_set = false


func is_tracking_queue_wait() -> bool:
	return _tracking_queue_wait


func get_queue_wait_game_minutes() -> float:
	if not _tracking_queue_wait or not _queue_wait_origin_set:
		return 0.0
	var game_time := get_node_or_null("/root/GameTimeManager")
	if game_time == null:
		return 0.0
	return _elapsed_game_minutes(
		game_time.get_day(),
		game_time.get_precise_minutes()
	)


func get_queue_wait_real_seconds() -> float:
	if not _tracking_queue_wait or not _queue_wait_origin_set:
		return 0.0
	return maxf(0.0, float(Time.get_ticks_msec() - _queue_wait_started_real_ms) / 1000.0)


func get_patience_queue_status() -> int:
	if not _tracking_queue_wait:
		return CustomerStatusScript.Kind.NONE
	var game_time := get_node_or_null("/root/GameTimeManager")
	if game_time != null:
		return CustomerPatienceConfigScript.status_for_wait_game_minutes(get_queue_wait_game_minutes())
	return CustomerPatienceConfigScript.status_for_wait_real_seconds(get_queue_wait_real_seconds())


func begin_depart(exit_waypoints: Array[Vector3]) -> void:
	_release_grid_block()
	reset_queue_wait_tracking()
	clear_queue_status()
	if _click_area:
		_click_area.collision_layer = 0
	state = State.DEPARTING
	_start_path(exit_waypoints, State.DEPARTING)


func get_approach_position() -> Vector3:
	return global_position + APPROACH_OFFSET


func get_face_target() -> Vector3:
	return global_position + Vector3(0.0, 0.75, 0.15)


func _walk_to_target(target: Vector3, walk_state: int) -> void:
	var flat_offset := Vector3(target.x - position.x, 0.0, target.z - position.z)
	if flat_offset.length() <= ARRIVE_DISTANCE:
		position = Vector3(target.x, target.y, target.z)
		if walk_state == State.REPOSITIONING:
			state = State.PENDING
			_play_idle()
			_face(_queue_face_dir())
			_on_reached_queue_slot()
		return
	_start_path([target], walk_state)


func _bind_pathfinding() -> void:
	if _grid == null:
		_grid = get_node("/root/GridService") as WarehouseGrid
	if _grid != null:
		_pathfinding = _grid.pathfinding
		if not _grid.navigation_changed.is_connected(_on_navigation_changed):
			_grid.navigation_changed.connect(_on_navigation_changed)


func _on_navigation_changed() -> void:
	if state in [State.ARRIVING, State.REPOSITIONING, State.DEPARTING]:
		_repath_to_targets()


func _start_path(targets: Array, walk_state: int) -> void:
	_bind_pathfinding()
	state = walk_state
	_nav_targets.clear()
	for target_variant in targets:
		_nav_targets.append(target_variant)
	_nav_stuck_time = 0.0
	_repath_to_targets()
	if _waypoints.is_empty():
		if _is_at_nav_goal():
			_arrive()
		else:
			_play_idle()
		return
	_play_walk()


func _repath_to_targets() -> void:
	_waypoints = _build_waypoints(_nav_targets)
	_wp_index = 0
	if not _waypoints.is_empty() and state in [State.ARRIVING, State.REPOSITIONING, State.DEPARTING]:
		_play_walk()


func _build_waypoints(targets: Array) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var origin := global_position
	for target_variant in targets:
		var target: Vector3 = target_variant
		for point in _pathfinding_segment(origin, target):
			if result.is_empty() or result[result.size() - 1].distance_to(point) > ARRIVE_DISTANCE:
				result.append(point)
		origin = target
	return result


func build_path_for_test(targets: Array) -> Array[Vector3]:
	_bind_pathfinding()
	return _build_waypoints(targets)


func _pathfinding_segment(from_world: Vector3, to_world: Vector3) -> Array[Vector3]:
	if state in [State.ARRIVING, State.REPOSITIONING] and QueueAreaLayout.is_queue_slot(to_world):
		if _pathfinding == null or _pathfinding.is_segment_walkable(from_world, to_world):
			return [to_world]
		return _queue_lane_waypoints(from_world, to_world)
	if _can_use_direct_queue_move(from_world, to_world):
		return [to_world]
	if _pathfinding == null or _grid == null:
		return [to_world]

	var from_cell := _grid.world_to_cell(from_world)
	var to_cell := _grid.world_to_cell(to_world)
	if not _grid.is_warehouse_cell(from_cell) or not _grid.is_warehouse_cell(to_cell):
		return [to_world]

	return _pathfinding.path_as_world_array(from_world, to_world)


func _queue_lane_waypoints(from_world: Vector3, to_world: Vector3) -> Array[Vector3]:
	var reception: Node3D = QueueAreaLayout.get_reception()
	if reception == null:
		return [to_world]
	var start: Vector3 = reception.get_queue_start_world()
	var primary: Vector3 = reception.get_line_direction()
	var spacing := ReceptionTableScript.SLOT_SPACING
	var t_dest: float = primary.dot(to_world - start)
	var t_here: float = primary.dot(from_world - start)
	var points: Array[Vector3] = []
	if t_here <= t_dest + 0.01:
		var t := maxf(0.0, ceil((t_here + ARRIVE_DISTANCE) / spacing) * spacing)
		while t < t_dest - ARRIVE_DISTANCE:
			var point: Vector3 = start + primary * t
			point.y = to_world.y
			points.append(point)
			t += spacing
	points.append(to_world)
	return points if not points.is_empty() else [to_world]


func _can_use_direct_queue_move(from_world: Vector3, to_world: Vector3) -> bool:
	if state not in [State.ARRIVING, State.REPOSITIONING]:
		return false
	if _pathfinding == null:
		return false
	if not QueueAreaLayout.is_queue_slot(from_world):
		return false
	if not QueueAreaLayout.is_queue_slot(to_world):
		return false
	return _pathfinding.is_segment_walkable(from_world, to_world)


func _update_clickable() -> void:
	if _click_area == null:
		return
	if is_interactive():
		_click_area.collision_layer = CLICK_LAYER
	else:
		_click_area.collision_layer = 0


func _process(delta: float) -> void:
	if state in [State.ARRIVING, State.REPOSITIONING, State.DEPARTING]:
		_advance(delta)


func _advance(delta: float) -> void:
	if _wp_index >= _waypoints.size():
		if _is_at_nav_goal():
			_arrive()
		else:
			_nav_stuck_time += delta
			if _nav_stuck_time >= REPATH_STUCK_SEC:
				_repath_to_targets()
				_nav_stuck_time = 0.0
			_play_idle()
		return
	var to_target := _waypoints[_wp_index] - position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= ARRIVE_DISTANCE:
		position = _waypoints[_wp_index]
		_wp_index += 1
		if _wp_index >= _waypoints.size():
			_arrive()
		return
	var step_size := minf(WALK_SPEED * delta, distance)
	var displacement := _compute_move_displacement(to_target.normalized(), step_size)
	if displacement.length_squared() > 0.000001:
		position += displacement
		_face(to_target)
		_play_walk()
		_nav_stuck_time = 0.0
	elif distance <= ARRIVE_DISTANCE and QueueAreaLayout.is_queue_slot(_waypoints[_wp_index]):
		var snap := _waypoints[_wp_index]
		if _can_step_to(snap):
			position = snap
			_wp_index += 1
			_nav_stuck_time = 0.0
			if _wp_index >= _waypoints.size():
				_arrive()
	else:
		_nav_stuck_time += delta
		if _nav_stuck_time >= REPATH_STUCK_SEC:
			_repath_to_targets()
			_nav_stuck_time = 0.0
		_play_idle()


func _can_step_to(target: Vector3) -> bool:
	if _pathfinding == null:
		return true
	if state in [State.ARRIVING, State.REPOSITIONING] and QueueAreaLayout.is_queue_slot(assigned_slot):
		if QueueAreaLayout.is_queue_slot(target):
			return _is_queue_standable(target)
	return _pathfinding.is_segment_walkable(position, target)


func _is_queue_standable(target: Vector3) -> bool:
	if _grid == null:
		return true
	var cell := _grid.world_to_cell(target)
	if not _grid.is_warehouse_cell(cell):
		return false
	if _grid.is_wall_perimeter_cell(cell):
		return false
	if _pathfinding == null:
		return true
	return _pathfinding.is_walkable(cell) or QueueAreaLayout.is_queue_slot(target)


func _is_at_nav_goal() -> bool:
	var goal := assigned_slot
	if not _nav_targets.is_empty():
		goal = _nav_targets[_nav_targets.size() - 1]
	var flat := Vector3(goal.x - position.x, 0.0, goal.z - position.z)
	return flat.length() <= QUEUE_SLOT_TOLERANCE


func _compute_move_displacement(move_dir: Vector3, step_size: float) -> Vector3:
	var desired := position + move_dir * step_size
	var separated := _separate_from_others(desired)
	if _can_step_to(separated):
		return Vector3(separated.x - position.x, 0.0, separated.z - position.z)

	var half := position + move_dir * step_size * 0.5
	half = _separate_from_others(half)
	if _can_step_to(half):
		return Vector3(half.x - position.x, 0.0, half.z - position.z)

	var slide_x := Vector3(separated.x, position.y, position.z)
	if _can_step_to(slide_x):
		return Vector3(slide_x.x - position.x, 0.0, 0.0)

	var slide_z := Vector3(position.x, position.y, separated.z)
	if _can_step_to(slide_z):
		return Vector3(0.0, 0.0, slide_z.z - position.z)

	return Vector3.ZERO


func _exit_tree() -> void:
	_unregister_instance()
	_release_grid_block()


func _release_grid_block() -> void:
	if _grid != null and _blocked_cell.x != -9999:
		_grid.unblock_cell(_blocked_cell)
		_blocked_cell = Vector2i(-9999, -9999)


func _register_instance() -> void:
	if self not in _active_instances:
		_active_instances.append(self)


func _unregister_instance() -> void:
	_active_instances.erase(self)


func _separate_from_others(candidate: Vector3) -> Vector3:
	if QueueAreaLayout.is_queue_slot(assigned_slot):
		return _separate_on_queue_lane(candidate)
	return _separate_omni(candidate)


func _separate_omni(candidate: Vector3) -> Vector3:
	var resolved := candidate
	var min_dist := BODY_RADIUS * 2.0 + 0.05
	for other in _active_instances:
		if other == self or not is_instance_valid(other):
			continue
		resolved = _push_apart(resolved, other.global_position, min_dist)
	return resolved


func _separate_on_queue_lane(candidate: Vector3) -> Vector3:
	var forward := _queue_line_forward()
	var lateral := Vector3(-forward.z, 0.0, forward.x)
	var resolved := candidate
	var min_dist := BODY_RADIUS * 2.0 + 0.05
	for other in _active_instances:
		if other == self or not is_instance_valid(other):
			continue
		var other_pos := other.global_position
		var offset := Vector3(resolved.x - other_pos.x, 0.0, resolved.z - other_pos.z)
		var dist_sq := offset.length_squared()
		if dist_sq >= min_dist * min_dist:
			continue
		var push := offset.normalized() * (min_dist - sqrt(dist_sq)) if dist_sq > 0.0001 else lateral * min_dist
		# Keep shoppers spaced along the lane, not shoved sideways off the line.
		push -= forward * push.dot(forward)
		if push.length_squared() < 0.0001:
			push = lateral * (min_dist if get_instance_id() > other.get_instance_id() else -min_dist)
		resolved += push
	return resolved


func _push_apart(resolved: Vector3, other_pos: Vector3, min_dist: float) -> Vector3:
	var offset := Vector3(resolved.x - other_pos.x, 0.0, resolved.z - other_pos.z)
	var dist_sq := offset.length_squared()
	if dist_sq >= min_dist * min_dist:
		return resolved
	if dist_sq > 0.0001:
		return resolved + offset.normalized() * (min_dist - sqrt(dist_sq))
	return resolved + Vector3(min_dist * 0.5, 0.0, 0.0)


func _queue_line_forward() -> Vector3:
	var dir := -QueueAreaLayout.get_customer_face_direction()
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	return dir.normalized()


func _arrive() -> void:
	if state in [State.ARRIVING, State.REPOSITIONING]:
		position = assigned_slot
	match state:
		State.ARRIVING:
			state = State.PENDING
			_play_idle()
			_face(_queue_face_dir())
			_on_reached_queue_slot()
		State.REPOSITIONING:
			state = State.PENDING
			_play_idle()
			_face(_queue_face_dir())
			_on_reached_queue_slot()
		State.DEPARTING:
			departed.emit(self)
			queue_free()


func _on_reached_queue_slot() -> void:
	begin_queue_wait_tracking()
	arrived_at_slot.emit(self)


func _capture_queue_wait_origin() -> void:
	_queue_wait_origin_set = true
	_queue_wait_started_real_ms = Time.get_ticks_msec()
	var game_time := get_node_or_null("/root/GameTimeManager")
	if game_time == null:
		_queue_wait_started_day = GameTimeConfigScript.STARTING_DAY
		_queue_wait_started_minutes = float(GameTimeConfigScript.DAY_START_MINUTES)
		return
	_queue_wait_started_day = game_time.get_day()
	_queue_wait_started_minutes = game_time.get_precise_minutes()


func _elapsed_game_minutes(current_day: int, current_minutes: float) -> float:
	var origin := _total_game_minutes(_queue_wait_started_day, _queue_wait_started_minutes)
	var current := _total_game_minutes(current_day, current_minutes)
	return maxf(0.0, current - origin)


static func _total_game_minutes(day: int, minutes: float) -> float:
	return float((maxi(1, day) - 1) * GameTimeConfigScript.MINUTES_PER_DAY) + minutes


func _queue_face_dir() -> Vector3:
	return QueueAreaLayout.get_customer_face_direction()


func _face(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	rotation.y = atan2(direction.x, direction.z)


func _build_model(model_path: String) -> void:
	var scene: PackedScene = load(model_path)
	if scene == null:
		return
	var model: Node3D = scene.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	CharacterModelCleanup.strip_accessories(model)
	add_child(model)
	_anim = _find_anim(model)
	_walk_anim = _resolve_anim(["walk", "Walk", "run"])
	_idle_anim = _resolve_anim(["idle", "Idle", "static"])


func _build_click_area() -> void:
	_click_area = Area3D.new()
	_click_area.name = "ClickArea"
	_click_area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS + 0.02
	capsule.height = BODY_HEIGHT + 0.1
	shape.shape = capsule
	shape.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	_click_area.add_child(shape)
	add_child(_click_area)


func _build_body_collision() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = CUSTOMER_BODY_LAYER
	_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	_body.add_child(shape)
	add_child(_body)


var _blocked_cell := Vector2i(-9999, -9999)


func _set_grid_blocked(_blocked: bool) -> void:
	# Queue shoppers use the dedicated lane, not warehouse pathfinding occupancy.
	pass


func _attach_status_indicator() -> void:
	if _status_indicator != null:
		return
	_status_indicator = CustomerStatusIndicatorScript.new()
	_status_indicator.name = "StatusIndicator"
	add_child(_status_indicator)


func _play_walk() -> void:
	_play(_walk_anim)


func _play_idle() -> void:
	_play(_idle_anim)


func _play(anim_name: String) -> void:
	if _anim == null or anim_name.is_empty():
		return
	var animation := _anim.get_animation(anim_name)
	if animation:
		animation.loop_mode = Animation.LOOP_LINEAR
	if _anim.current_animation != anim_name or not _anim.is_playing():
		_anim.play(anim_name)


func _resolve_anim(names: Array) -> String:
	if _anim == null:
		return ""
	for n in names:
		if _anim.has_animation(n):
			return n
	var list := _anim.get_animation_list()
	return list[0] if not list.is_empty() else ""


func _find_anim(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_anim(child)
		if found:
			return found
	return null
