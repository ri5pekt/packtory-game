class_name ComputerSectionsConfig
extends RefCounted

## Registry of computer terminal sections. Add entries here to expose new modules.

const SECTION_ONLINE_ORDERS := "online_orders"
const SECTION_ORDER_EQUIPMENT := "order_equipment"
const SECTION_REORDER_PRODUCTS := "reorder_products"
const SECTION_HIRE_WORKERS := "hire_workers"

const SECTIONS: Array[Dictionary] = [
	{
		"id": SECTION_ONLINE_ORDERS,
		"label": "Online Orders",
		"placeholder": false,
		"description": "Review and activate online store orders.",
	},
	{
		"id": SECTION_ORDER_EQUIPMENT,
		"label": "Order Equipment",
		"placeholder": false,
		"description": "Purchase shelves, decorations, equipment, and warehouse upgrades.",
	},
	{
		"id": SECTION_REORDER_PRODUCTS,
		"label": "Reorder Products",
		"placeholder": false,
		"description": "Restock catalog products and manage supplier deliveries.",
	},
	{
		"id": SECTION_HIRE_WORKERS,
		"label": "Hire Workers",
		"placeholder": false,
		"description": "Recruit helpers to automate storage runs and floor cleaning.",
	},
]


static func get_sections() -> Array[Dictionary]:
	return SECTIONS.duplicate(true)


static func get_section(section_id: String) -> Dictionary:
	for section in SECTIONS:
		if String(section.get("id", "")) == section_id:
			return section.duplicate(true)
	return {}


static func get_section_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for section in SECTIONS:
		ids.append(String(section.get("id", "")))
	return ids


static func is_placeholder(section_id: String) -> bool:
	return bool(get_section(section_id).get("placeholder", false))


static func get_implemented_section_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for section in SECTIONS:
		if not bool(section.get("placeholder", false)):
			ids.append(String(section.get("id", "")))
	return ids
