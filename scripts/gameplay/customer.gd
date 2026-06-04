class_name Customer
extends Node3D

## A shopper that walks in along a waypoint path, queues, and carries an order.
## The front customer shows a note bubble while pending; after packing they wait
## for the manager to hand off the package.

signal arrived_at_slot(customer: Customer)
signal departed(customer: Customer)

enum State { ARRIVING, PENDING, TAKEN, WAITING_PICKUP, REPOSITIONING, DEPARTING }

const WALK_SPEED := 1.6
const ARRIVE_DISTANCE := 0.06
const MODEL_SCALE := 1.0
const BUBBLE_Y := 1.42
const BUBBLE_BOB_AMPLITUDE := 0.07
const BUBBLE_BOB_SPEED := 2.2
const CLICK_LAYER := 1
const CUSTOMER_BODY_LAYER := 4
const BODY_RADIUS := 0.32   # smaller so queued shoppers can stand closer
const BODY_HEIGHT := 1.05
const QUEUE_FACE_DIR := Vector3(0.0, 0.0, -1.0)
# Customers face north (-Z); the worker stands on that side, not behind the queue line.
const APPROACH_OFFSET := Vector3(0.0, 0.0, -1.05)
const QUEUE_SLOT_TOLERANCE := 0.35
const REPATH_STUCK_SEC := 0.4

var order: Dictionary = {}
var state: int = State.ARRIVING

var _waypoints: Array[Vector3] = []
var _wp_index := 0
var _nav_targets: Array[Vector3] = []
var _nav_stuck_time := 0.0
var _anim: AnimationPlayer
var _walk_anim := ""
var _idle_anim := ""
var _bubble: Node3D
var _click_area: Area3D
var _body: StaticBody3D
var _grid: WarehouseGrid
var _pathfinding: Pathfinding
var assigned_slot: Vector3 = Vector3.ZERO
var _bubble_time := 0.0


func setup(
	model_path: String,
	waypoints: Array[Vector3],
	order_data: Dictionary,
	slot: Vector3
) -> void:
	order = order_data
	assigned_slot = slot
	position = waypoints[0]
	add_to_group("customers")
	_bind_pathfinding()

	_build_model(model_path)
	_build_body_collision()
	_build_click_area()
	_build_bubble()
	hide_bubble()
	_start_path(waypoints.slice(1), State.ARRIVING)


func has_pending_order() -> bool:
	return state == State.PENDING


func is_departing() -> bool:
	return state == State.DEPARTING


func is_in_queue() -> bool:
	return state != State.DEPARTING and state != State.ARRIVING


func is_waiting_pickup() -> bool:
	return state == State.WAITING_PICKUP


func is_interactive() -> bool:
	return state == State.PENDING or state == State.WAITING_PICKUP


func set_order_taken() -> void:
	state = State.TAKEN
	hide_bubble()
	_update_clickable()


func set_pending() -> void:
	state = State.PENDING
	_update_clickable()


func set_waiting_pickup() -> void:
	state = State.WAITING_PICKUP
	_update_clickable()


func show_bubble() -> void:
	if _bubble == null:
		return
	_bubble.visible = true
	_update_clickable()


func hide_bubble() -> void:
	if _bubble == null:
		return
	_bubble.visible = false
	_update_clickable()


func walk_to_slot(target: Vector3) -> void:
	if state == State.DEPARTING or state == State.ARRIVING:
		return
	assigned_slot = target
	_walk_to_target(target, State.REPOSITIONING)


## Re-path a shopper still walking in so they target an updated queue slot.
func redirect_to_slot(slot: Vector3) -> void:
	if state == State.DEPARTING:
		return
	assigned_slot = slot
	_start_path([slot], State.ARRIVING)


func begin_depart(exit_waypoints: Array[Vector3]) -> void:
	hide_bubble()
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
		if walk_state == State.REPOSITIONING:
			state = State.PENDING
			_play_idle()
			_face(QUEUE_FACE_DIR)
			arrived_at_slot.emit(self)
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


func _pathfinding_segment(from_world: Vector3, to_world: Vector3) -> Array[Vector3]:
	if _pathfinding == null or _grid == null:
		return [to_world]

	var from_cell := _grid.world_to_cell(from_world)
	var to_cell := _grid.world_to_cell(to_world)
	if not _grid.is_warehouse_cell(from_cell) or not _grid.is_warehouse_cell(to_cell):
		return [to_world]

	return _pathfinding.path_as_world_array(from_world, to_world)


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
	if _bubble != null and _bubble.visible:
		_bubble_time += delta
		_bubble.position.y = BUBBLE_Y + sin(_bubble_time * BUBBLE_BOB_SPEED) * BUBBLE_BOB_AMPLITUDE


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
		position = Vector3(_waypoints[_wp_index].x, position.y, _waypoints[_wp_index].z)
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
	elif distance <= QUEUE_SLOT_TOLERANCE and QueueAreaLayout.is_queue_slot(_waypoints[_wp_index]):
		var snap := Vector3(_waypoints[_wp_index].x, position.y, _waypoints[_wp_index].z)
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
	return _pathfinding.is_segment_walkable(position, target)


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


func _separate_from_others(candidate: Vector3) -> Vector3:
	var resolved := candidate
	var min_dist := BODY_RADIUS * 2.0 + 0.05
	for node in get_tree().get_nodes_in_group("customers"):
		if node == self or not is_instance_valid(node) or not node is Customer:
			continue
		var other: Customer = node
		var other_pos := other.global_position
		var offset := Vector3(resolved.x - other_pos.x, 0.0, resolved.z - other_pos.z)
		var dist_sq := offset.length_squared()
		if dist_sq >= min_dist * min_dist:
			continue
		if dist_sq > 0.0001:
			resolved += offset.normalized() * (min_dist - sqrt(dist_sq))
		else:
			var nudge := 1.0 if get_instance_id() > other.get_instance_id() else -1.0
			resolved += Vector3(nudge * min_dist * 0.5, 0.0, 0.0)
	return resolved


func _arrive() -> void:
	if state in [State.ARRIVING, State.REPOSITIONING]:
		position = Vector3(assigned_slot.x, position.y, assigned_slot.z)
	match state:
		State.ARRIVING:
			state = State.PENDING
			_play_idle()
			_face(QUEUE_FACE_DIR)
			arrived_at_slot.emit(self)
		State.REPOSITIONING:
			state = State.PENDING
			_play_idle()
			_face(QUEUE_FACE_DIR)
			arrived_at_slot.emit(self)
		State.DEPARTING:
			departed.emit(self)
			queue_free()


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


func _build_bubble() -> void:
	# Reusable speech bubble holding the order-list icon as its content.
	var bubble := SpeechBubble3D.new()
	bubble.name = "Bubble"
	bubble.position = Vector3(0.0, BUBBLE_Y, 0.0)
	add_child(bubble)
	bubble.set_content(IconRegistry.get_icon("order_list"))
	_bubble = bubble


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
