class_name OutboundDeliveryConfig
extends RefCounted

## Configurable capacity for the player's outgoing online-order delivery van.

static var package_capacity: int = 4


static func get_package_capacity() -> int:
	return maxi(1, package_capacity)


static func set_package_capacity(value: int) -> void:
	package_capacity = maxi(1, value)
