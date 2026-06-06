class_name EquipmentCatalog
extends RefCounted

## Configurable catalog for warehouse equipment and upgrade orders.

const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")

const CATEGORY_SHELVES := "shelves"
const CATEGORY_DECORATIONS := "decorations"
const CATEGORY_EQUIPMENT := "equipment"
const CATEGORY_WAREHOUSE_UPGRADES := "warehouse_upgrades"

const DELIVERY_TYPE_EQUIPMENT := "equipment"
const DELIVERY_TYPE_DECORATION := "decoration"
const DELIVERY_TYPE_UPGRADE := "warehouse_upgrade"

const ITEM_SHELF := "shelf"
const ITEM_STORAGE_SHELF := "storage_shelf"

const ORDERABLE_ITEMS: Array[Dictionary] = [
	{
		"id": ITEM_SHELF,
		"label": "Shelf",
		"category": CATEGORY_SHELVES,
		"cost": EconomyConfigScript.WAREHOUSE_PURCHASE_PLACEHOLDER,
		"description": "Additional product shelf for the warehouse floor.",
		"delivery_type": DELIVERY_TYPE_EQUIPMENT,
		"placeable_type": "shelf",
	},
	{
		"id": ITEM_STORAGE_SHELF,
		"label": "Storage Shelf",
		"category": CATEGORY_SHELVES,
		"cost": EconomyConfigScript.WAREHOUSE_PURCHASE_PLACEHOLDER,
		"description": "Stores sealed delivery boxes until workers unpack them onto product shelves.",
		"delivery_type": DELIVERY_TYPE_EQUIPMENT,
		"placeable_type": "storage_shelf",
	},
]


static func get_orderable_items() -> Array[Dictionary]:
	return ORDERABLE_ITEMS.duplicate(true)


static func get_items_by_category(category: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for item in ORDERABLE_ITEMS:
		if String(item.get("category", "")) == category:
			matches.append(item.duplicate(true))
	return matches


static func get_item(item_id: String) -> Dictionary:
	for item in ORDERABLE_ITEMS:
		if String(item.get("id", "")) == item_id:
			return item.duplicate(true)
	return {}


static func get_cost(item_id: String) -> int:
	return int(get_item(item_id).get("cost", 0))


static func batch_order_total(item_ids: Array) -> int:
	var total := 0
	for raw in item_ids:
		total += get_cost(String(raw))
	return total


static func has_item(item_id: String) -> bool:
	return not get_item(item_id).is_empty()
