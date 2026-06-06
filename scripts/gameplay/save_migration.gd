class_name SaveMigration
extends RefCounted

## Versioned save migrations — keep forward-compatible defaults for missing keys.

const ReputationConfigScript = preload("res://scripts/gameplay/reputation_config.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")


static func migrate(data: Dictionary, target_version: int) -> Dictionary:
	var version := int(data.get("version", 0))
	var migrated := data.duplicate(true)
	if version < 1:
		migrated = _to_v1(migrated)
		version = 1
	if version < 2 and target_version >= 2:
		migrated = _to_v2(migrated)
		version = 2
	migrated["version"] = target_version
	return migrated


static func _to_v1(data: Dictionary) -> Dictionary:
	if not data.has("progression"):
		data["progression"] = {}
	var progression: Dictionary = data.get("progression", {})
	if not progression.has("reputation"):
		progression["reputation"] = ReputationConfigScript.STARTING_REPUTATION
	data["progression"] = progression
	return data


static func _to_v2(data: Dictionary) -> Dictionary:
	if not data.has("session"):
		data["session"] = {}
	var session: Dictionary = data.get("session", {})
	if not session.has("time_running"):
		session["time_running"] = bool(session.get("is_day_started", false))
	data["session"] = session
	if not data.has("economy"):
		data["economy"] = {"day_expenses": []}
	if not data.has("day_end"):
		data["day_end"] = {
			"payroll_settled_day": -1,
			"last_checked_minute": -1,
		}
	if not data.has("day_stats"):
		data["day_stats"] = {
			"tracking": bool(session.get("is_day_started", false)),
			"in_person_orders": 0,
			"online_orders": 0,
			"total_earnings": 0,
			"delivery_expenses": 0,
			"reputation_start": int(
				data.get("progression", {}).get("reputation", ReputationConfigScript.STARTING_REPUTATION)
			),
		}
	if not data.has("garbage"):
		data["garbage"] = {"pieces": []}
	var dock: Dictionary = data.get("dock", {})
	if not dock.has("equipment_boxes"):
		dock["equipment_boxes"] = []
	data["dock"] = dock
	if not data.has("game_time"):
		var progression: Dictionary = data.get("progression", {})
		data["game_time"] = {
			"day": int(progression.get("day", GameTimeConfigScript.STARTING_DAY)),
			"game_minutes": int(progression.get("game_minutes", GameTimeConfigScript.DAY_START_MINUTES)),
			"running": bool(session.get("time_running", false)),
		}
	return data
