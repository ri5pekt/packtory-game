class_name WorkerHireConfig
extends RefCounted

## Hireable generic workers — placeholder names; specialization hooks for future roles.

const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")
const CharacterCatalogScript = preload("res://scripts/dev/character_catalog.gd")

const SPECIALIZATION_GENERAL := "general"
const SPECIALIZATION_PICKER := "picker"
const SPECIALIZATION_PACKER := "packer"
const SPECIALIZATION_DRIVER := "driver"

const HIREABLE_WORKERS: Array[Dictionary] = [
	{
		"id": "helper_alex",
		"display_name": "Alex",
		"hire_cost": EconomyConfigScript.HIRE_FEE_PLACEHOLDER,
		"daily_salary": EconomyConfigScript.SALARY_PLACEHOLDER,
		"specialization": SPECIALIZATION_GENERAL,
		"model": "character-female-c.glb",
		"description": "General helper — can run storage and cleaning tasks when assigned.",
	},
	{
		"id": "helper_jordan",
		"display_name": "Jordan",
		"hire_cost": EconomyConfigScript.HIRE_FEE_PLACEHOLDER,
		"daily_salary": EconomyConfigScript.SALARY_PLACEHOLDER,
		"specialization": SPECIALIZATION_GENERAL,
		"model": "character-male-b.glb",
		"description": "General helper — can run storage and cleaning tasks when assigned.",
	},
	{
		"id": "helper_sam",
		"display_name": "Sam",
		"hire_cost": EconomyConfigScript.HIRE_FEE_PLACEHOLDER,
		"daily_salary": EconomyConfigScript.SALARY_PLACEHOLDER,
		"specialization": SPECIALIZATION_GENERAL,
		"model": "character-female-a.glb",
		"description": "General helper — can run storage and cleaning tasks when assigned.",
	},
	{
		"id": "helper_riley",
		"display_name": "Riley",
		"hire_cost": EconomyConfigScript.HIRE_FEE_PLACEHOLDER,
		"daily_salary": EconomyConfigScript.SALARY_PLACEHOLDER,
		"specialization": SPECIALIZATION_GENERAL,
		"model": "character-male-a.glb",
		"description": "General helper — can run storage and cleaning tasks when assigned.",
	},
]


static func get_hireable_workers() -> Array[Dictionary]:
	return HIREABLE_WORKERS.duplicate(true)


static func get_worker(worker_id: String) -> Dictionary:
	for entry in HIREABLE_WORKERS:
		if String(entry.get("id", "")) == worker_id:
			return entry.duplicate(true)
	return {}


static func has_worker(worker_id: String) -> bool:
	return not get_worker(worker_id).is_empty()


static func get_hire_cost(worker_id: String) -> int:
	return int(get_worker(worker_id).get("hire_cost", 0))


static func get_daily_salary(worker_id: String) -> int:
	return int(get_worker(worker_id).get("daily_salary", EconomyConfigScript.SALARY_PLACEHOLDER))


static func get_model_path(worker_id: String) -> String:
	var model_file := String(get_worker(worker_id).get("model", ""))
	if model_file == "":
		return ""
	return CharacterCatalogScript.model_path(model_file)
