class_name OutboundTruckStats
extends RefCounted

## Configurable outgoing delivery truck stats — upgrade hooks for speed, capacity, and costs.

const OutboundDeliveryConfigScript = preload("res://scripts/gameplay/outbound_delivery_config.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")

const DEFAULT_BASE_DELIVERY_MINUTES := 60.0
const DEFAULT_SPEED_MULTIPLIER := 1.0
const MIN_SPEED_MULTIPLIER := 0.1

static var base_delivery_minutes: float = DEFAULT_BASE_DELIVERY_MINUTES
static var speed_multiplier: float = DEFAULT_SPEED_MULTIPLIER
static var operating_cost_override: int = -1


static func reset_to_defaults() -> void:
	base_delivery_minutes = DEFAULT_BASE_DELIVERY_MINUTES
	speed_multiplier = DEFAULT_SPEED_MULTIPLIER
	operating_cost_override = -1
	OutboundDeliveryConfigScript.set_package_capacity(4)


static func get_capacity() -> int:
	return OutboundDeliveryConfigScript.get_package_capacity()


static func set_capacity(value: int) -> void:
	OutboundDeliveryConfigScript.set_package_capacity(value)


static func get_speed_multiplier() -> float:
	return speed_multiplier


static func set_speed_multiplier(value: float) -> void:
	speed_multiplier = maxf(MIN_SPEED_MULTIPLIER, value)


static func get_base_delivery_minutes() -> float:
	return base_delivery_minutes


static func set_base_delivery_minutes(value: float) -> void:
	base_delivery_minutes = maxf(1.0, value)


static func get_operating_cost() -> int:
	if operating_cost_override >= 0:
		return operating_cost_override
	return EconomyConfigScript.OUTBOUND_DISPATCH_FEE


static func set_operating_cost(value: int) -> void:
	operating_cost_override = maxi(0, value)


static func clear_operating_cost_override() -> void:
	operating_cost_override = -1


## Route length in game minutes: base × order_count ÷ speed_multiplier.
static func route_duration_minutes(order_count: int) -> float:
	var orders := maxi(1, order_count)
	var speed := maxf(MIN_SPEED_MULTIPLIER, speed_multiplier)
	return base_delivery_minutes * float(orders) / speed


static func export_state() -> Dictionary:
	return {
		"base_delivery_minutes": base_delivery_minutes,
		"speed_multiplier": speed_multiplier,
		"operating_cost": operating_cost_override,
		"capacity": get_capacity(),
	}


static func apply_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	set_base_delivery_minutes(float(data.get("base_delivery_minutes", DEFAULT_BASE_DELIVERY_MINUTES)))
	set_speed_multiplier(float(data.get("speed_multiplier", DEFAULT_SPEED_MULTIPLIER)))
	var cost := int(data.get("operating_cost", -1))
	if cost >= 0:
		set_operating_cost(cost)
	else:
		clear_operating_cost_override()
	if data.has("capacity"):
		set_capacity(int(data.get("capacity", get_capacity())))
