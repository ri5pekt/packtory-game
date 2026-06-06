class_name OnlineOrderCatalog
extends RefCounted

## Mock online order feed for the computer terminal.
## Intentionally separate from in-person CustomerQueue / ActiveOrderUI data.

const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")

const MOCK_ORDERS: Array[Dictionary] = [
	{
		"order_number": 1001,
		"items": [
			{"quantity": 1, "name": "computer mouse", "product_id": "mouse"},
		],
	},
	{
		"order_number": 1002,
		"items": [
			{"quantity": 1, "name": "headphones", "product_id": "headphones"},
		],
	},
	{
		"order_number": 1003,
		"items": [
			{"quantity": 1, "name": "hair dryer", "product_id": "hair_dryer"},
			{"quantity": 1, "name": "computer mouse", "product_id": "mouse"},
		],
	},
]

const NAME_TO_PRODUCT := {
	"computer mice": "mouse",
	"computer mouse": "mouse",
	"mouse": "mouse",
	"mice": "mouse",
	"hair dryer": "hair_dryer",
	"headphones": "headphones",
}


static func get_orders() -> Array[Dictionary]:
	return get_available_orders([])


static func get_available_orders(fulfilled_order_numbers: Array = []) -> Array[Dictionary]:
	var fulfilled := {}
	for num in fulfilled_order_numbers:
		fulfilled[int(num)] = true
	var orders: Array[Dictionary] = []
	for entry in MOCK_ORDERS:
		var order_number := int(entry.get("order_number", 0))
		if fulfilled.has(order_number):
			continue
		orders.append(entry.duplicate(true))
	return orders


static func get_order_by_number(order_number: int) -> Dictionary:
	for entry in MOCK_ORDERS:
		if int(entry.get("order_number", 0)) == order_number:
			return entry.duplicate(true)
	return {}


static func format_order_title(order_number: int) -> String:
	return "Online Order #%d" % order_number


static func format_item_line(item: Dictionary) -> String:
	var qty: int = maxi(1, int(item.get("quantity", 1)))
	var name: String = String(item.get("name", ""))
	if name == "":
		name = display_item_name(item)
	if qty == 1:
		return "1 %s" % name
	return "%d %s" % [qty, name]


static func display_item_name(item: Dictionary) -> String:
	var product_id := resolve_product_id(item)
	if product_id != "":
		return ProductCatalogScript.display_name(product_id)
	return String(item.get("name", "item"))


static func format_items_block(order: Dictionary) -> String:
	var lines: PackedStringArray = []
	for item in order.get("items", []):
		lines.append(format_item_line(item))
	if lines.is_empty():
		return "No items listed."
	return "Items: " + ", ".join(lines)


static func resolve_product_id(item: Dictionary) -> String:
	var explicit := String(item.get("product_id", ""))
	if explicit != "" and ProductCatalogScript.has_id(explicit):
		return explicit
	var normalized := String(item.get("name", "")).strip_edges().to_lower()
	return String(NAME_TO_PRODUCT.get(normalized, ""))


static func to_fulfillment_order(online_order: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item in online_order.get("items", []):
		var product_id := resolve_product_id(item)
		if product_id == "":
			continue
		var qty: int = maxi(1, int(item.get("quantity", 1)))
		result[product_id] = int(result.get(product_id, 0)) + qty
	return result
