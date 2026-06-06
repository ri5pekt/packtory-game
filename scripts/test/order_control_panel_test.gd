extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/order_control_panel_test.gd

const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const OnlineOrderCatalogScript = preload("res://scripts/gameplay/online_order_catalog.gd")
const ActiveOrderUIScript = preload("res://scripts/ui/active_order_ui.gd")
func _init() -> void:
	var failed := 0
	failed += _assert("online order highlights online section", _test_online_section_active())
	failed += _assert("in-person order highlights in-person section", _test_in_person_section_active())
	failed += _assert("inactive section tray is hidden", _test_inactive_section_tray_hidden())
	failed += _assert("panel lists separate section statuses", _test_panel_section_statuses())

	if failed == 0:
		print("order_control_panel_test: ALL PASSED")
		quit(0)
	else:
		push_error("order_control_panel_test: %d FAILED" % failed)
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


func _make_ui(queue: Node) -> Control:
	var ui: Control = ActiveOrderUIScript.new()
	ui.set_size(Vector2(720.0, 520.0))
	root.add_child(ui)
	ui.bind_queue_for_test(queue)
	return ui


func _test_online_section_active() -> bool:
	var queue := _make_queue()
	var ui := _make_ui(queue)
	var order: Dictionary = OnlineOrderCatalogScript.get_order_by_number(1001)
	if not queue.activate_online_order(order):
		return false
	ui.bind_queue_for_test(queue)
	return (
		ui.get_active_order_source() == "online"
		and ui.is_section_active("online")
		and not ui.is_section_active("in_person")
		and ui.get_section_status_text("online").contains("Online Order #1001")
	)


func _test_in_person_section_active() -> bool:
	var queue := _make_queue()
	var ui := _make_ui(queue)
	queue.set("_active_order", {"headphones": 1})
	queue.set("_order_source", "in_person")
	queue.active_order_changed.emit({"headphones": 1})
	ui.bind_queue_for_test(queue)
	return (
		ui.get_active_order_source() == "in_person"
		and ui.is_section_active("in_person")
		and not ui.is_section_active("online")
		and ui.get_section_status_text("in_person") == "Customer queue order"
	)


func _test_inactive_section_tray_hidden() -> bool:
	var queue := _make_queue()
	var ui := _make_ui(queue)
	var order: Dictionary = OnlineOrderCatalogScript.get_order_by_number(1001)
	queue.activate_online_order(order)
	ui.bind_queue_for_test(queue)
	return (
		not ui.is_section_tray_visible("in_person")
		and ui.is_section_tray_visible("online")
	)


func _test_panel_section_statuses() -> bool:
	var queue := _make_queue()
	var ui := _make_ui(queue)
	var order: Dictionary = OnlineOrderCatalogScript.get_order_by_number(1002)
	queue.activate_online_order(order)
	ui.bind_queue_for_test(queue)
	ui._open_panel()
	var online_status: String = ui.get_section_status_text("online")
	return online_status.contains("Online Order #1002")
