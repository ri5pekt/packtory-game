class_name ProductCatalog
extends RefCounted

## Definitions for all orderable products. `box_size` is used to build the 3D
## box mesh displayed on shelves; `color` tints both the box and the UI slot.

const ORDER_MAX_UNITS := 4
const HP := "res://blender/assets/Household Props 001-glb/"

const PRODUCTS := {
	"headphones": {
		"name": "Headphones",
		"color": Color(0.22, 0.65, 0.82),
		"box_size": Vector3(0.20, 0.20, 0.14),
	},
	"hair_dryer": {
		"name": "Hair Dryer",
		"color": Color(0.86, 0.42, 0.34),
		"box_size": Vector3(0.17, 0.24, 0.14),
	},
	"mouse": {
		"name": "Mouse",
		"color": Color(0.40, 0.74, 0.45),
		"box_size": Vector3(0.20, 0.12, 0.18),
	},
	"package": {
		"name": "Package",
		"color": Color(0.82, 0.58, 0.28),
		"is_package": true,
		"box_size": Vector3(0.30, 0.24, 0.24),
	},
}


static func has_id(product_id: String) -> bool:
	return PRODUCTS.has(product_id)


static func get_def(product_id: String) -> Dictionary:
	return PRODUCTS.get(product_id, {})


static func display_name(product_id: String) -> String:
	return PRODUCTS.get(product_id, {}).get("name", product_id)


static func color_of(product_id: String) -> Color:
	return PRODUCTS.get(product_id, {}).get("color", Color.GRAY)


static func box_size_of(product_id: String) -> Vector3:
	return PRODUCTS.get(product_id, {}).get("box_size", Vector3(0.18, 0.18, 0.18))


static func is_package(product_id: String) -> bool:
	return PRODUCTS.get(product_id, {}).get("is_package", false)


static func inventory_label(product_id: String, count: int = 1) -> String:
	if is_package(product_id):
		return "📦"
	if count > 1:
		return "%s\nx%d" % [display_name(product_id), count]
	return display_name(product_id)


## Count held units per product id.
static func inventory_counts(inventory: Array) -> Dictionary:
	var counts := {}
	for item in inventory:
		var id := String(item)
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


## True when every line in `order` is present in the worker's held items.
static func inventory_fulfills_order(inventory: Array, order: Dictionary) -> bool:
	if order.is_empty():
		return false
	for item in inventory:
		if is_package(String(item)):
			return false
	var held := inventory_counts(inventory)
	for product_id in order:
		if is_package(String(product_id)):
			return false
		if int(held.get(product_id, 0)) < int(order[product_id]):
			return false
	return true


static func order_unit_count(order: Dictionary) -> int:
	var total := 0
	for product_id in order:
		total += int(order[product_id])
	return total


static func orders_match(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for product_id in a:
		if int(a[product_id]) != int(b.get(product_id, 0)):
			return false
	return true


static func orderable_product_ids() -> Array:
	var ids: Array = []
	for product_id in PRODUCTS:
		if not is_package(String(product_id)):
			ids.append(product_id)
	return ids


## A random order that fits in the worker's carry capacity (max ORDER_MAX_UNITS).
static func random_order(rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = orderable_product_ids()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	var kinds := rng.randi_range(1, mini(pool.size(), ORDER_MAX_UNITS))
	var order := {}
	var remaining := ORDER_MAX_UNITS
	for i in range(kinds):
		if remaining <= 0:
			break
		var qty := rng.randi_range(1, mini(3, remaining))
		order[pool[i]] = qty
		remaining -= qty
	return order


static func order_lines(order: Dictionary) -> Array:
	var lines: Array = []
	for id in order:
		if is_package(String(id)):
			continue
		lines.append("%s  x%d" % [display_name(id), order[id]])
	return lines
