class_name OutboundDispatchConfig
extends RefCounted

## Outgoing online delivery van — animation timings and dispatch fee facade.

const OutboundTruckStatsScript = preload("res://scripts/gameplay/outbound_truck_stats.gd")

const DEPART_ANIM_SEC := 1.5
const RETURN_ANIM_SEC := 1.5


static func dispatch_fee() -> int:
	return OutboundTruckStatsScript.get_operating_cost()


static func route_duration_minutes(order_count: int) -> float:
	return OutboundTruckStatsScript.route_duration_minutes(order_count)
