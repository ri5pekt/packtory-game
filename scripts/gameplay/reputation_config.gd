class_name ReputationConfig
extends RefCounted

## Configurable reputation bounds — future hooks: customer volume, fees, specials.

const STARTING_REPUTATION := 100
const MIN_REPUTATION := 0
const MAX_REPUTATION := 100


static func clamp_reputation(value: int) -> int:
	return clampi(value, MIN_REPUTATION, MAX_REPUTATION)


static func ratio_for_value(value: int) -> float:
	var span := MAX_REPUTATION - MIN_REPUTATION
	if span <= 0:
		return 0.0
	return clampf(float(clamp_reputation(value) - MIN_REPUTATION) / float(span), 0.0, 1.0)
