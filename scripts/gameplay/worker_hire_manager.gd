extends Node

## Hires generic warehouse workers from the computer terminal.

signal roster_changed(workers: Array)

const WORKER_SCENE := preload("res://scenes/worker/worker.tscn")
const WorkerHireConfigScript = preload("res://scripts/gameplay/worker_hire_config.gd")
const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")

const SPAWN_CELLS := [
	Vector2i(12, 16),
	Vector2i(14, 16),
	Vector2i(13, 15),
	Vector2i(13, 17),
	Vector2i(12, 15),
	Vector2i(14, 15),
]

const DEFAULT_YAW := 180.0


func _ready() -> void:
	add_to_group("worker_hire_manager")


func reset_for_new_game() -> void:
	roster_changed.emit(get_roster_summaries())


func get_roster_summaries() -> Array:
	var summaries: Array = []
	for worker in _workers_in_scene():
		if worker.has_method("get_roster_summary"):
			summaries.append(worker.get_roster_summary())
	return summaries


func get_available_hire_entries() -> Array:
	var available: Array = []
	for entry in WorkerHireConfigScript.get_hireable_workers():
		var worker_id := String(entry.get("id", ""))
		if worker_id == "" or is_worker_hired(worker_id):
			continue
		available.append(entry.duplicate(true))
	return available


func is_worker_hired(worker_id: String) -> bool:
	for worker in _workers_in_scene():
		if worker.has_method("get_worker_id") and worker.get_worker_id() == worker_id:
			return true
	return false


func can_afford_hire(worker_id: String) -> bool:
	var entry := WorkerHireConfigScript.get_worker(worker_id)
	if entry.is_empty():
		return false
	var economy := _get_economy()
	if economy == null:
		return false
	return economy.get_coins() >= int(entry.get("hire_cost", 0))


func hire_worker(worker_id: String) -> Dictionary:
	var entry := WorkerHireConfigScript.get_worker(worker_id)
	if entry.is_empty():
		return {"ok": false, "reason": "unknown_worker"}
	if is_worker_hired(worker_id):
		return {"ok": false, "reason": "already_hired"}
	var economy := _get_economy()
	if economy == null:
		return {"ok": false, "reason": "no_economy"}
	var cost := int(entry.get("hire_cost", 0))
	if not economy.try_spend(cost, "hire_worker:%s" % worker_id):
		return {"ok": false, "reason": "insufficient_coins"}
	var worker := spawn_hired_worker(entry)
	if worker == null:
		if cost > 0:
			economy.add_coins(cost, "hire_worker_refund:%s" % worker_id)
		return {"ok": false, "reason": "spawn_failed"}
	roster_changed.emit(get_roster_summaries())
	return {"ok": true, "worker": worker}


func spawn_hired_worker(entry: Dictionary) -> Worker:
	var worker_id := String(entry.get("id", ""))
	if worker_id == "":
		return null
	var cell := _next_spawn_cell()
	return _spawn_worker(_build_roster_from_entry(entry), cell)


func spawn_worker_from_save(data: Dictionary) -> Worker:
	var worker_id := String(data.get("worker_id", data.get("id", "")))
	if worker_id == "":
		return null
	var cell := _next_spawn_cell()
	var roster := {
		"worker_id": worker_id,
		"display_name": String(data.get("display_name", worker_id)),
		"daily_salary": int(data.get("daily_salary", data.get("salary", 0))),
		"specialization": String(data.get("specialization", WorkerHireConfigScript.SPECIALIZATION_GENERAL)),
		"is_manager": bool(data.get("is_manager", worker_id == "manager")),
		"model": String(data.get("model", "")),
	}
	var worker := _spawn_worker(roster, cell)
	if worker == null:
		return null
	if data.has("position"):
		worker.global_position = SaveManagerScript.array_to_vec3(data.get("position", [0, 0, 0]))
	if data.has("yaw"):
		worker.rotation_degrees.y = float(data.get("yaw", DEFAULT_YAW))
	if worker.has_method("apply_save_state"):
		worker.apply_save_state(data)
	return worker


func spawn_default_manager() -> Worker:
	if _find_worker_by_id("manager") != null:
		return null
	return _spawn_worker({
		"worker_id": "manager",
		"display_name": "Manager",
		"daily_salary": 0,
		"specialization": WorkerHireConfigScript.SPECIALIZATION_GENERAL,
		"is_manager": true,
		"model": "character-male-d.glb",
	}, Vector2i(13, 16))


func _spawn_worker(roster: Dictionary, cell: Vector2i) -> Worker:
	var grid := _get_grid()
	var parent := _get_spawn_parent()
	if grid == null or parent == null:
		return null
	var worker: Worker = WORKER_SCENE.instantiate()
	worker.name = String(roster.get("display_name", roster.get("worker_id", "Worker")))
	parent.add_child(worker)
	worker.global_position = grid.cell_to_world(cell)
	worker.rotation_degrees.y = DEFAULT_YAW
	if worker.has_method("apply_roster_profile"):
		worker.apply_roster_profile(roster)
	return worker


func _build_roster_from_entry(entry: Dictionary) -> Dictionary:
	return {
		"worker_id": String(entry.get("id", "")),
		"display_name": String(entry.get("display_name", "")),
		"daily_salary": int(entry.get("daily_salary", 0)),
		"specialization": String(entry.get("specialization", WorkerHireConfigScript.SPECIALIZATION_GENERAL)),
		"is_manager": false,
		"model": String(entry.get("model", "")),
	}


func _next_spawn_cell() -> Vector2i:
	var grid := _get_grid()
	if grid == null:
		return SPAWN_CELLS[0]
	for cell in SPAWN_CELLS:
		var occupied := false
		for worker in _workers_in_scene():
			if grid.world_to_cell(worker.global_position) == cell:
				occupied = true
				break
		if not occupied:
			return cell
	return SPAWN_CELLS[0]


func _find_worker_by_id(worker_id: String) -> Worker:
	for worker in _workers_in_scene():
		if worker.has_method("get_worker_id") and worker.get_worker_id() == worker_id:
			return worker
	return null


func _workers_in_scene() -> Array:
	var tree := get_tree()
	if tree == null:
		return []
	return tree.get_nodes_in_group("workers")


func _get_spawn_parent() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var spawn := tree.get_first_node_in_group("worker_spawn")
	if spawn:
		return spawn
	return tree.root


func _get_grid() -> WarehouseGrid:
	return get_node_or_null("/root/GridService") as WarehouseGrid


func _get_economy() -> Node:
	return get_node_or_null("/root/EconomyManager")

