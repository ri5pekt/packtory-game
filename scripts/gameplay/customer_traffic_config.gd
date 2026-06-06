class_name CustomerTrafficConfig
extends RefCounted

## Configurable in-person customer traffic by time of day.

const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")

const PERIOD_NIGHT := "night"
const PERIOD_MORNING := "morning"
const PERIOD_AFTERNOON := "afternoon"
const PERIOD_EVENING := "evening"

const FIRST_SPAWN_DELAY_MINUTES := 10.0

# Spawn delay ranges in game minutes (lower = busier traffic).
const TRAFFIC_BANDS: Array[Dictionary] = [
	{
		"start": 0.0,
		"end": 360.0,
		"period": PERIOD_NIGHT,
		"spawn_min_minutes": -1.0,
		"spawn_max_minutes": -1.0,
	},
	{
		"start": 360.0,
		"end": 720.0,
		"period": PERIOD_MORNING,
		"spawn_min_minutes": 14.0,
		"spawn_max_minutes": 22.0,
	},
	{
		"start": 720.0,
		"end": 1020.0,
		"period": PERIOD_AFTERNOON,
		"spawn_min_minutes": 7.0,
		"spawn_max_minutes": 12.0,
	},
	{
		"start": 1020.0,
		"end": float(GameTimeConfigScript.STORE_CLOSE_MINUTES),
		"period": PERIOD_EVENING,
		"spawn_min_minutes": 16.0,
		"spawn_max_minutes": 24.0,
	},
	{
		"start": float(GameTimeConfigScript.STORE_CLOSE_MINUTES),
		"end": float(GameTimeConfigScript.MINUTES_PER_DAY),
		"period": PERIOD_NIGHT,
		"spawn_min_minutes": -1.0,
		"spawn_max_minutes": -1.0,
	},
]


static func wrap_minutes(minutes: float) -> float:
	return GameTimeConfigScript.clamp_minutes(minutes)


static func is_store_open(minutes: float) -> bool:
	var wrapped := wrap_minutes(minutes)
	return (
		wrapped >= float(GameTimeConfigScript.STORE_OPEN_MINUTES)
		and wrapped < float(GameTimeConfigScript.STORE_CLOSE_MINUTES)
	)


static func can_spawn_customers(minutes: float) -> bool:
	if not is_store_open(minutes):
		return false
	var band := _band_at_minutes(minutes)
	return (
		float(band.get("spawn_min_minutes", -1.0)) >= 0.0
		and float(band.get("spawn_max_minutes", -1.0)) >= 0.0
	)


static func traffic_period_at(minutes: float) -> String:
	return String(_band_at_minutes(minutes).get("period", PERIOD_NIGHT))


static func spawn_delay_range(minutes: float) -> Vector2:
	var band := _band_at_minutes(minutes)
	var min_delay := float(band.get("spawn_min_minutes", -1.0))
	var max_delay := float(band.get("spawn_max_minutes", -1.0))
	if min_delay < 0.0 or max_delay < 0.0:
		return Vector2(-1.0, -1.0)
	return Vector2(min_delay, max_delay)


static func random_spawn_delay_minutes(minutes: float, rng: RandomNumberGenerator) -> float:
	var range := spawn_delay_range(minutes)
	if range.x < 0.0:
		return -1.0
	return rng.randf_range(range.x, range.y)


static func traffic_intensity_rank(period: String) -> int:
	match period:
		PERIOD_AFTERNOON:
			return 3
		PERIOD_MORNING:
			return 2
		PERIOD_EVENING:
			return 1
		_:
			return 0


static func _band_at_minutes(minutes: float) -> Dictionary:
	var wrapped := wrap_minutes(minutes)
	for band in TRAFFIC_BANDS:
		var start := float(band.get("start", 0.0))
		var end := float(band.get("end", 0.0))
		if wrapped >= start and wrapped < end:
			return band
	return TRAFFIC_BANDS[TRAFFIC_BANDS.size() - 1]
