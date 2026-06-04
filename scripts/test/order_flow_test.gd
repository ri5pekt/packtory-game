extends SceneTree

## Run with: godot --headless --path . --script res://scripts/test/order_flow_test.gd
## Validates order/inventory rules without loading the full scene.

const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")


func _init() -> void:
	var failed := 0
	failed += _assert("orderable ids exclude package", _test_orderable_ids())
	failed += _assert("random orders fit capacity", _test_random_order_capacity())
	failed += _assert("fulfillment rejects package in hand", _test_package_blocks_fulfill())
	failed += _assert("orders_match is symmetric", _test_orders_match())
	failed += _assert("partial inventory fails", _test_partial_inventory())
	failed += _assert("exact inventory passes", _test_exact_inventory())

	if failed == 0:
		print("order_flow_test: ALL PASSED")
		quit(0)
	else:
		push_error("order_flow_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _test_orderable_ids() -> bool:
	var ids: Array = ProductCatalogScript.orderable_product_ids()
	return not ids.has("package") and ids.size() == 3


func _test_random_order_capacity() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in range(50):
		var order: Dictionary = ProductCatalogScript.random_order(rng)
		if ProductCatalogScript.order_unit_count(order) > ProductCatalogScript.ORDER_MAX_UNITS:
			return false
		if order.is_empty():
			return false
	return true


func _test_package_blocks_fulfill() -> bool:
	var order := {"book": 1}
	var inv := ["package", "book"]
	return not ProductCatalogScript.inventory_fulfills_order(inv, order)


func _test_orders_match() -> bool:
	var a := {"book": 2, "mouse": 1}
	var b := {"mouse": 1, "book": 2}
	var c := {"book": 1, "mouse": 1}
	return ProductCatalogScript.orders_match(a, b) and not ProductCatalogScript.orders_match(a, c)


func _test_partial_inventory() -> bool:
	var order := {"book": 2}
	var inv := ["book"]
	return not ProductCatalogScript.inventory_fulfills_order(inv, order)


func _test_exact_inventory() -> bool:
	var order := {"book": 2, "mouse": 1}
	var inv := ["book", "book", "mouse"]
	return ProductCatalogScript.inventory_fulfills_order(inv, order)
