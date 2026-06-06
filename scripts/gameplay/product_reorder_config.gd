class_name ProductReorderConfig
extends RefCounted

## Product restock orders — logistics fee now; unit costs can be enabled later.

const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")
const EquipmentOrderConfigScript = preload("res://scripts/gameplay/equipment_order_config.gd")
const DeliveryBoxScript = preload("res://scripts/gameplay/delivery_box.gd")

const MIN_QUANTITY := 1
const MAX_QUANTITY := DeliveryBoxScript.UNITS_PER_BOX
const DEFAULT_QUANTITY := DeliveryBoxScript.UNITS_PER_BOX


static func delivery_delay_minutes() -> float:
	return EquipmentOrderConfigScript.DELIVERY_DELAY_GAME_MINUTES


static func logistics_fee() -> int:
	return EconomyConfigScript.DELIVERY_FEE_PLACEHOLDER


static func unit_cost(product_id: String) -> int:
	return ProductCatalogScript.unit_cost_of(product_id)


static func order_total(product_id: String, quantity: int) -> int:
	var qty := clampi(quantity, MIN_QUANTITY, MAX_QUANTITY)
	return logistics_fee() + unit_cost(product_id) * qty


static func batch_order_total(lines: Array) -> int:
	if lines.is_empty():
		return 0
	var total := logistics_fee()
	for line in lines:
		if line is Dictionary:
			var product_id := String(line.get("product_id", ""))
			var qty := clamp_quantity(int(line.get("quantity", 0)))
			total += unit_cost(product_id) * qty
	return total


static func clamp_quantity(quantity: int) -> int:
	return clampi(quantity, MIN_QUANTITY, MAX_QUANTITY)
