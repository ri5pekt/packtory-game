class_name WorkerTaskConfig
extends RefCounted

## Task categories for hired workers. Storage and cleaning automation are implemented.

const CATEGORY_STORAGE := "storage"
const CATEGORY_FULFILLMENT := "fulfillment"
const CATEGORY_CLEANING := "cleaning"


static func default_tasks() -> Dictionary:
	return {
		CATEGORY_STORAGE: false,
		CATEGORY_FULFILLMENT: false,
		CATEGORY_CLEANING: false,
	}


static func categories() -> Array:
	return [
		{"id": CATEGORY_STORAGE, "label": "Storage"},
		{"id": CATEGORY_FULFILLMENT, "label": "Fulfillment"},
		{"id": CATEGORY_CLEANING, "label": "Cleaning"},
	]


static func display_label(category_id: String) -> String:
	for entry in categories():
		if String(entry.get("id", "")) == category_id:
			return String(entry.get("label", category_id))
	return category_id


static func is_valid_category(category_id: String) -> bool:
	for entry in categories():
		if String(entry.get("id", "")) == category_id:
			return true
	return false
