class_name CustomerPatienceConfig
extends RefCounted

## Configurable queue wait thresholds before status icons change.

# Game-clock thresholds (preferred during gameplay).
const IMPATIENT_AFTER_GAME_MINUTES := 4.0
const ANGRY_AFTER_GAME_MINUTES := 8.0

# Real-time fallback when the accelerated game clock is unavailable.
const IMPATIENT_AFTER_REAL_SECONDS := 12.0
const ANGRY_AFTER_REAL_SECONDS := 24.0


static func status_for_wait_game_minutes(wait_minutes: float) -> int:
	const CustomerStatusScript = preload("res://scripts/gameplay/customer_status.gd")
	if wait_minutes > ANGRY_AFTER_GAME_MINUTES:
		return CustomerStatusScript.Kind.ANGRY
	if wait_minutes > IMPATIENT_AFTER_GAME_MINUTES:
		return CustomerStatusScript.Kind.IMPATIENT
	return CustomerStatusScript.Kind.WAITING


static func status_for_wait_real_seconds(wait_seconds: float) -> int:
	const CustomerStatusScript = preload("res://scripts/gameplay/customer_status.gd")
	if wait_seconds > ANGRY_AFTER_REAL_SECONDS:
		return CustomerStatusScript.Kind.ANGRY
	if wait_seconds > IMPATIENT_AFTER_REAL_SECONDS:
		return CustomerStatusScript.Kind.IMPATIENT
	return CustomerStatusScript.Kind.WAITING
