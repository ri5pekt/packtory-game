class_name PedestrianRoles
extends RefCounted

## Distinguishes decorative sidewalk walkers from shoppers heading to the warehouse.

const GROUP_DECORATIVE := "decorative_pedestrians"
const GROUP_CUSTOMER_APPROACH := "customer_pedestrians"
const GROUP_WAREHOUSE_CUSTOMER := "customers"


static func is_decorative(node: Node) -> bool:
	return node != null and node.is_in_group(GROUP_DECORATIVE)


static func is_customer_approach(node: Node) -> bool:
	return node != null and node.is_in_group(GROUP_CUSTOMER_APPROACH)


static func is_warehouse_customer(node: Node) -> bool:
	return (
		node != null
		and node.is_in_group(GROUP_WAREHOUSE_CUSTOMER)
		and node.has_method("has_entered_warehouse")
		and node.has_entered_warehouse()
	)
