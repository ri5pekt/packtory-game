class_name FloorGarbage
extends Node3D

## Small litter on the warehouse floor — clickable and cleaned via context menu.

signal cleaned(garbage)

const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")
const GarbageDropConfigScript = preload("res://scripts/gameplay/garbage_drop_config.gd")

var variant_index := 0
var spawned_at_day := GameTimeConfigScript.STARTING_DAY
var spawned_at_minutes := float(GameTimeConfigScript.DAY_START_MINUTES)


func setup(world_position: Vector3, model_index: int = 0, yaw_deg: float = 0.0) -> void:
	variant_index = model_index
	position = world_position
	rotation_degrees.y = yaw_deg
	add_to_group("floor_garbage")
	_capture_spawn_time()
	_build_visual(model_index)
	_build_click_area()


func get_age_game_minutes(current_day: int, current_minutes: float) -> float:
	var spawn_total := _total_game_minutes(spawned_at_day, spawned_at_minutes)
	var current_total := _total_game_minutes(current_day, current_minutes)
	return maxf(0.0, current_total - spawn_total)


func is_past_grace(grace_minutes: float, current_day: int, current_minutes: float) -> bool:
	return get_age_game_minutes(current_day, current_minutes) > grace_minutes


func _capture_spawn_time() -> void:
	var game_time := get_node_or_null("/root/GameTimeManager")
	if game_time == null:
		spawned_at_day = GameTimeConfigScript.STARTING_DAY
		spawned_at_minutes = float(GameTimeConfigScript.DAY_START_MINUTES)
		return
	spawned_at_day = game_time.get_day()
	spawned_at_minutes = game_time.get_precise_minutes()


static func _total_game_minutes(day: int, minutes: float) -> float:
	return float((maxi(1, day) - 1) * GameTimeConfigScript.MINUTES_PER_DAY) + minutes


func get_approach_position() -> Vector3:
	return global_position + Vector3(0.0, 0.0, -0.75)


func get_face_target() -> Vector3:
	return global_position + Vector3(0.0, 0.12, 0.0)


func clean() -> void:
	cleaned.emit(self)
	queue_free()


const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")


func export_save_state() -> Dictionary:
	return {
		"position": SaveManagerScript.vec3_to_array(global_position),
		"variant_index": variant_index,
		"yaw": rotation_degrees.y,
		"spawned_at_day": spawned_at_day,
		"spawned_at_minutes": spawned_at_minutes,
	}


func _build_visual(model_index: int) -> void:
	var models: Array = GarbageDropConfigScript.LITTER_MODELS
	var path := String(models[model_index % models.size()])
	var scene: PackedScene = load(path) as PackedScene
	if scene != null:
		var mesh: Node3D = scene.instantiate()
		mesh.name = "LitterMesh"
		mesh.scale = Vector3.ONE * GarbageDropConfigScript.MODEL_SCALE
		mesh.rotation_degrees.x = -90.0
		mesh.rotation_degrees.z = randf_range(-18.0, 18.0)
		add_child(mesh)
		return
	_build_placeholder()


func _build_placeholder() -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "LitterMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.04, 0.18)
	mesh_node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.38, 0.32)
	mat.roughness = 0.95
	mesh_node.material_override = mat
	mesh_node.rotation_degrees.x = -8.0
	mesh_node.rotation_degrees.z = randf_range(-25.0, 25.0)
	add_child(mesh_node)


func _build_click_area() -> void:
	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = GarbageDropConfigScript.CLICK_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.42, 0.12, 0.42)
	shape.shape = box
	shape.position = Vector3(0.0, 0.06, 0.0)
	area.add_child(shape)
	add_child(area)
