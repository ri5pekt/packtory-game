extends Node3D

## Spawns the default manager worker when no roster exists yet.

const WorkerHireManagerScript = preload("res://scripts/gameplay/worker_hire_manager.gd")


func _ready() -> void:
	add_to_group("worker_spawn")
	call_deferred("_ensure_default_manager")


func _ensure_default_manager() -> void:
	if get_tree().get_nodes_in_group("workers").size() > 0:
		return
	var save := get_node_or_null("/root/SaveManager")
	if save != null and save.has_method("is_loading_save") and save.is_loading_save():
		return
	var hire_manager := get_node_or_null("/root/WorkerHireManager")
	if hire_manager != null and hire_manager.has_method("spawn_default_manager"):
		hire_manager.spawn_default_manager()
