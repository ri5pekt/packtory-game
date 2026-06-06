extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/online_order_activation_test.gd

const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const OnlineOrderCatalogScript = preload("res://scripts/gameplay/online_order_catalog.gd")
const ComputerInterfaceUIScript = preload("res://scripts/ui/computer_interface_ui.gd")
const ComputerOnlineOrdersScreenScript = preload(
	"res://scripts/ui/computer_online_orders_screen.gd"
)
const ComputerOnlineOrderDetailScreenScript = preload(
	"res://scripts/ui/computer_online_order_detail_screen.gd"
)


func _init() -> void:
	var failed := 0
	failed += _assert("catalog maps order 1001 items", _test_catalog_mapping())
	failed += _assert("activate online order sets source", _test_activate_online())
	failed += _assert("active order blocks second activation", _test_block_duplicate())
	failed += _assert("cancel clears online active order", _test_cancel_online())
	failed += _assert("detail screen exposes order number", _test_detail_screen())
	failed += _assert("orders list opens detail view", _test_list_to_detail())
	failed += _assert("fulfilled online orders leave catalog", _test_fulfilled_removed_from_catalog())

	if failed == 0:
		print("online_order_activation_test: ALL PASSED")
		quit(0)
	else:
		push_error("online_order_activation_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _make_queue() -> Node:
	var queue: Node = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	return queue


func _test_catalog_mapping() -> bool:
	var order: Dictionary = OnlineOrderCatalogScript.get_order_by_number(1001)
	var fulfillment: Dictionary = OnlineOrderCatalogScript.to_fulfillment_order(order)
	return int(fulfillment.get("mouse", 0)) == 1 and fulfillment.size() == 1


func _test_activate_online() -> bool:
	var queue := _make_queue()
	var order: Dictionary = OnlineOrderCatalogScript.get_order_by_number(1001)
	if not queue.activate_online_order(order):
		return false
	return (
		queue.get_order_source() == "online"
		and queue.get_online_order_number() == 1001
		and not queue.get_active_order().is_empty()
		and int(queue.get_active_order().get("mouse", 0)) == 2
	)


func _test_block_duplicate() -> bool:
	var queue := _make_queue()
	var first: Dictionary = OnlineOrderCatalogScript.get_order_by_number(1001)
	var second: Dictionary = OnlineOrderCatalogScript.get_order_by_number(1002)
	if not queue.activate_online_order(first):
		return false
	return not queue.activate_online_order(second)


func _test_cancel_online() -> bool:
	var queue := _make_queue()
	var order: Dictionary = OnlineOrderCatalogScript.get_order_by_number(1001)
	queue.activate_online_order(order)
	queue.cancel_order()
	return queue.get_active_order().is_empty() and queue.get_order_source() == ""


func _test_detail_screen() -> bool:
	var order: Dictionary = OnlineOrderCatalogScript.get_order_by_number(1001)
	var screen: VBoxContainer = ComputerOnlineOrderDetailScreenScript.new()
	screen.setup(order)
	root.add_child(screen)
	return screen.get_order_number() == 1001


func _test_fulfilled_removed_from_catalog() -> bool:
	var queue := _make_queue()
	queue.notify_online_package_shipped({"online_order_number": 1002})
	var available: Array = OnlineOrderCatalogScript.get_available_orders(queue.get_fulfilled_online_orders())
	for order in available:
		if int(order.get("order_number", 0)) == 1002:
			return false
	return available.size() == OnlineOrderCatalogScript.MOCK_ORDERS.size() - 1


func _test_list_to_detail() -> bool:
	var list: VBoxContainer = ComputerOnlineOrdersScreenScript.new()
	root.add_child(list)
	list.ensure_ready()
	var order: Dictionary = OnlineOrderCatalogScript.get_order_by_number(1001)
	list.show_order_detail(order)
	return list.is_showing_detail()
