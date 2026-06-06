class_name GameTimeConfig
extends RefCounted

## Configurable accelerated game clock — 1 real second = X game minutes.

const STARTING_DAY := 1
const DAY_START_MINUTES := 480
const MINUTES_PER_DAY := 24 * 60

# Default: 1 real second advances 1 game minute (60 real sec = 1 game hour).
const DEFAULT_GAME_MINUTES_PER_REAL_SECOND := 1.0

# In-person customer store hours (8:00 AM – 8:00 PM).
const STORE_OPEN_MINUTES := 480
const STORE_CLOSE_MINUTES := 1200


static func clamp_minutes(value: float) -> float:
	return clampf(value, 0.0, float(MINUTES_PER_DAY - 1))


static func clamp_minutes_int(value: int) -> int:
	return clampi(value, 0, MINUTES_PER_DAY - 1)


static func format_clock(minutes: int) -> String:
	var hour := minutes / 60
	var minute := minutes % 60
	return "%02d:%02d" % [hour, minute]


## Fallback when GameTimeManager is unavailable (lighting, tests, save defaults).
static func resolve_precise_minutes(game_time: Node) -> float:
	if game_time and game_time.has_method("get_precise_minutes"):
		return game_time.get_precise_minutes()
	return float(DAY_START_MINUTES)
