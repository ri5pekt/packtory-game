class_name UnlockConfig
extends RefCounted

## Level-based unlock table — products now; shelves, upgrades, employees, trucks later.

const STARTING_PRODUCTS: Array[String] = ["mouse", "hair_dryer", "headphones"]

const LEVEL_UNLOCKS: Dictionary = {
	1: {
		"products": ["smart_watch"],
		"shelves": [],
		"upgrades": [],
		"employees": [],
		"trucks": [],
	},
}


static func unlocks_for_level(level: int) -> Dictionary:
	var entry: Variant = LEVEL_UNLOCKS.get(level, {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}


static func has_unlocks_at_level(level: int) -> bool:
	var entry := unlocks_for_level(level)
	for key in ["products", "shelves", "upgrades", "employees", "trucks"]:
		var list: Variant = entry.get(key, [])
		if list is Array and not (list as Array).is_empty():
			return true
	return false


static func product_unlocks_for_level(level: int) -> Array[String]:
	var entry := unlocks_for_level(level)
	var products: Array[String] = []
	for product_id in entry.get("products", []):
		products.append(String(product_id))
	return products


static func starting_products() -> Array[String]:
	return STARTING_PRODUCTS.duplicate()
