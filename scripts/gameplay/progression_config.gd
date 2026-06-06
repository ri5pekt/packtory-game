class_name ProgressionConfig
extends RefCounted

## Configurable XP/level table — keep thresholds and rewards out of gameplay logic.
## Coin rewards live in EconomyConfig; XP is intentionally asymmetric.

const STARTING_LEVEL := 0
const STARTING_TOTAL_XP := 0

const IN_PERSON_ORDER_XP := 15
const ONLINE_ORDER_XP := 12

# XP required to advance FROM level N TO level N+1 (index = current level).
const XP_TO_NEXT_LEVEL: Array[int] = [
	50,
	75,
	100,
	125,
	150,
	200,
	250,
	300,
	400,
	500,
]


static func xp_reward_for_fulfillment(source: String) -> int:
	match source:
		"online":
			return ONLINE_ORDER_XP
		_:
			return IN_PERSON_ORDER_XP


static func max_level() -> int:
	return XP_TO_NEXT_LEVEL.size()


static func is_max_level(level: int) -> bool:
	return level >= max_level()


static func xp_required_for_level(level: int) -> int:
	if XP_TO_NEXT_LEVEL.is_empty():
		return 1
	if level < 0:
		return XP_TO_NEXT_LEVEL[0]
	if level >= XP_TO_NEXT_LEVEL.size():
		return XP_TO_NEXT_LEVEL[XP_TO_NEXT_LEVEL.size() - 1]
	return XP_TO_NEXT_LEVEL[level]


static func total_xp_for_level(level: int) -> int:
	var total := 0
	var capped := clampi(level, STARTING_LEVEL, max_level())
	for i in range(capped):
		total += XP_TO_NEXT_LEVEL[i]
	return total


static func level_from_total_xp(total_xp: int) -> int:
	var level := STARTING_LEVEL
	var remaining := maxi(0, total_xp)
	while level < max_level():
		var need := XP_TO_NEXT_LEVEL[level]
		if remaining < need:
			break
		remaining -= need
		level += 1
	return level


static func xp_into_current_level(total_xp: int) -> int:
	return maxi(0, total_xp) - total_xp_for_level(level_from_total_xp(total_xp))


static func progress_ratio(total_xp: int) -> float:
	var level := level_from_total_xp(total_xp)
	if is_max_level(level):
		return 1.0
	var need := xp_required_for_level(level)
	if need <= 0:
		return 1.0
	return clampf(float(xp_into_current_level(total_xp)) / float(need), 0.0, 1.0)


static func total_xp_from_legacy_save(level: int, xp_into_level: int) -> int:
	# Older saves used level 1 as the starting rank.
	var adjusted_level := maxi(0, level - 1)
	return total_xp_for_level(adjusted_level) + maxi(0, xp_into_level)
