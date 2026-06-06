extends Node

## Spawns occasional customer litter near the queue and tracks floor garbage.

signal garbage_spawned(garbage)
signal garbage_cleaned(garbage)

const FloorGarbageScript = preload("res://scripts/gameplay/floor_garbage.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")
const GarbageDropConfigScript = preload("res://scripts/gameplay/garbage_drop_config.gd")
const GarbageReputationConfigScript = preload("res://scripts/gameplay/garbage_reputation_config.gd")
const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")

var _rng := RandomNumberGenerator.new()
var _grid: WarehouseGrid
var _penalty_accumulator := 0.0
var _last_penalty_total_minutes := -1.0


func _ready() -> void:
	add_to_group("garbage_drop_manager")
	_rng.randomize()
	call_deferred("_bind_grid")
	call_deferred("_bind_game_time")
	call_deferred("_bind_scene_customers")
	var tree := get_tree()
	if tree and not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


func reset_for_new_game() -> void:
	clear_all_garbage()
	_reset_reputation_penalty_state()


func clear_all_garbage() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("floor_garbage"):
		if is_instance_valid(node):
			node.queue_free()


func advance_reputation_penalty(game_minutes_delta: float) -> int:
	if game_minutes_delta <= 0.0:
		return 0
	return _accumulate_and_apply_penalty(game_minutes_delta)


func count_offending_garbage() -> int:
	return _count_offending_garbage(_current_game_time_snapshot())


func get_garbage_count() -> int:
	var tree := get_tree()
	if tree == null:
		return 0
	return tree.get_nodes_in_group("floor_garbage").size()


func export_save_state() -> Dictionary:
	var pieces: Array = []
	var tree := get_tree()
	if tree == null:
		return {"pieces": pieces}
	for node in tree.get_nodes_in_group("floor_garbage"):
		if not is_instance_valid(node):
			continue
		if not node.has_method("export_save_state"):
			continue
		pieces.append(node.export_save_state())
	return {"pieces": pieces}


func apply_save_state(data: Dictionary) -> void:
	clear_all_garbage()
	for entry in data.get("pieces", []):
		if not entry is Dictionary:
			continue
		spawn_garbage_from_save(entry)
	_reset_reputation_penalty_state()


func spawn_garbage_from_save(entry: Dictionary) -> FloorGarbage:
	_ensure_grid()
	var position := SaveManagerScript.array_to_vec3(entry.get("position", [0, 0, 0]))
	var model_index := int(entry.get("variant_index", 0))
	var yaw := float(entry.get("yaw", 0.0))
	var garbage = FloorGarbageScript.new()
	garbage.name = "FloorGarbage_%d" % get_garbage_count()
	_get_spawn_parent().add_child(garbage)
	garbage.setup(position, model_index, yaw)
	if entry.has("spawned_at_day"):
		garbage.spawned_at_day = int(entry.get("spawned_at_day", garbage.spawned_at_day))
	if entry.has("spawned_at_minutes"):
		garbage.spawned_at_minutes = float(entry.get("spawned_at_minutes", garbage.spawned_at_minutes))
	garbage.cleaned.connect(_on_garbage_cleaned)
	garbage_spawned.emit(garbage)
	return garbage


func try_drop_near(world_position: Vector3, chance: float, force: bool = false):
	if not force and _rng.randf() > chance:
		return null
	if get_garbage_count() >= GarbageDropConfigScript.MAX_GARBAGE_PIECES:
		return null
	return spawn_garbage_at(world_position)


func spawn_garbage_at(world_position: Vector3):
	_ensure_grid()
	var offset := Vector3(
		_rng.randf_range(-0.5, 0.5),
		0.0,
		_rng.randf_range(-0.4, 0.4)
	)
	var target := world_position + offset
	if _grid != null:
		target = _grid.clamp_world_to_navigable(target)
		var cell := _grid.world_to_cell(target)
		target.y = _grid.walk_surface_y(cell)
	else:
		target.y = WarehouseGrid.WAREHOUSE_FLOOR_SURFACE_Y

	var garbage = FloorGarbageScript.new()
	garbage.name = "FloorGarbage_%d" % get_garbage_count()
	var model_index := _rng.randi_range(0, GarbageDropConfigScript.LITTER_MODELS.size() - 1)
	var yaw := _rng.randf_range(0.0, 360.0)
	_get_spawn_parent().add_child(garbage)
	garbage.setup(target, model_index, yaw)
	garbage.cleaned.connect(_on_garbage_cleaned)
	garbage_spawned.emit(garbage)
	return garbage


func _bind_game_time() -> void:
	var game_time := _get_game_time()
	if game_time == null:
		return
	if not game_time.time_changed.is_connected(_on_game_time_changed):
		game_time.time_changed.connect(_on_game_time_changed)
	_reset_reputation_penalty_clock()


func _bind_grid() -> void:
	_grid = get_node_or_null("/root/GridService") as WarehouseGrid


func _ensure_grid() -> void:
	if _grid == null:
		_bind_grid()


func _bind_scene_customers() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for customer in tree.get_nodes_in_group("customers"):
		_connect_customer(customer)


func _on_node_added(node: Node) -> void:
	if node is Customer:
		_connect_customer(node)


func _connect_customer(customer: Customer) -> void:
	if not customer.arrived_at_slot.is_connected(_on_customer_arrived_at_slot):
		customer.arrived_at_slot.connect(_on_customer_arrived_at_slot)
	if not customer.departed.is_connected(_on_customer_departed):
		customer.departed.connect(_on_customer_departed)


func _on_customer_arrived_at_slot(customer: Customer) -> void:
	if customer == null or not customer.has_entered_warehouse():
		return
	try_drop_near(customer.global_position, GarbageDropConfigScript.DROP_CHANCE_ON_ARRIVE)


func _on_customer_departed(customer: Customer) -> void:
	if customer == null:
		return
	try_drop_near(customer.global_position, GarbageDropConfigScript.DROP_CHANCE_ON_DEPART)


func _on_garbage_cleaned(garbage) -> void:
	garbage_cleaned.emit(garbage)


func _on_game_time_changed(_game_minutes: int, day: int) -> void:
	var game_time := _get_game_time()
	if game_time == null or not game_time.is_running():
		return
	var total := _total_game_minutes(day, game_time.get_precise_minutes())
	if _last_penalty_total_minutes < 0.0:
		_last_penalty_total_minutes = total
		return
	var delta := total - _last_penalty_total_minutes
	_last_penalty_total_minutes = total
	advance_reputation_penalty(delta)


func _accumulate_and_apply_penalty(game_minutes_delta: float) -> int:
	_penalty_accumulator += game_minutes_delta
	var total_loss := 0
	while _penalty_accumulator >= GarbageReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES:
		_penalty_accumulator -= GarbageReputationConfigScript.PENALTY_INTERVAL_GAME_MINUTES
		total_loss += _apply_penalty_tick()
	return total_loss


func _apply_penalty_tick() -> int:
	var offending := _count_offending_garbage(_current_game_time_snapshot())
	if offending <= 0:
		return 0
	var amount := offending * GarbageReputationConfigScript.REPUTATION_LOSS_PER_PIECE_PER_TICK
	var reputation := _get_reputation()
	if reputation == null:
		return 0
	var changed: int = reputation.reduce_reputation(amount)
	return maxi(0, -changed)


func _count_offending_garbage(snapshot: Dictionary) -> int:
	var tree := get_tree()
	if tree == null:
		return 0
	var day := int(snapshot.get("day", GameTimeConfigScript.STARTING_DAY))
	var minutes := float(snapshot.get("minutes", float(GameTimeConfigScript.DAY_START_MINUTES)))
	var grace := GarbageReputationConfigScript.GRACE_GAME_MINUTES
	var count := 0
	for node in tree.get_nodes_in_group("floor_garbage"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_past_grace") and node.is_past_grace(grace, day, minutes):
			count += 1
	return count


func _current_game_time_snapshot() -> Dictionary:
	var game_time := _get_game_time()
	if game_time == null:
		return {
			"day": GameTimeConfigScript.STARTING_DAY,
			"minutes": float(GameTimeConfigScript.DAY_START_MINUTES),
		}
	return {
		"day": game_time.get_day(),
		"minutes": game_time.get_precise_minutes(),
	}


func _reset_reputation_penalty_state() -> void:
	_penalty_accumulator = 0.0
	_reset_reputation_penalty_clock()


func _reset_reputation_penalty_clock() -> void:
	var game_time := _get_game_time()
	if game_time == null:
		_last_penalty_total_minutes = -1.0
		return
	_last_penalty_total_minutes = _total_game_minutes(
		game_time.get_day(),
		game_time.get_precise_minutes()
	)


func _total_game_minutes(day: int, minutes: float) -> float:
	return float((maxi(1, day) - 1) * GameTimeConfigScript.MINUTES_PER_DAY) + minutes


func _get_game_time() -> Node:
	return get_node_or_null("/root/GameTimeManager")


func _get_reputation() -> Node:
	return get_node_or_null("/root/ReputationManager")


func _get_spawn_parent() -> Node:
	var tree := get_tree()
	if tree == null:
		return self
	var warehouse := tree.get_first_node_in_group("warehouse_root")
	if warehouse:
		return warehouse
	return tree.root
