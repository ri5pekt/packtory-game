extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/computer_online_orders_test.gd

const ComputerInterfaceUIScript = preload("res://scripts/ui/computer_interface_ui.gd")
const ComputerOnlineOrdersScreenScript = preload(
	"res://scripts/ui/computer_online_orders_screen.gd"
)
const OnlineOrderCatalogScript = preload("res://scripts/gameplay/online_order_catalog.gd")


func _init() -> void:
	var failed := 0
	failed += _assert("mock catalog has order 1001", _test_mock_catalog())
	failed += _assert("home screen starts on open", _test_home_screen_on_open())
	failed += _assert("navigate to online orders list", _test_navigate_online_orders())
	failed += _assert("order items are shown", _test_order_items_visible())
	failed += _assert("back returns to home screen", _test_back_navigation())
	failed += _assert("close resets to home screen", _test_close_resets_home())

	if failed == 0:
		print("computer_online_orders_test: ALL PASSED")
		quit(0)
	else:
		push_error("computer_online_orders_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _make_ui() -> Control:
	var ui: Control = ComputerInterfaceUIScript.new()
	ui.set_size(Vector2(720.0, 520.0))
	root.add_child(ui)
	ui.open()
	return ui


func _test_mock_catalog() -> bool:
	var orders := OnlineOrderCatalogScript.get_orders()
	if orders.is_empty():
		return false
	return int(orders[0].get("order_number", 0)) == 1001


func _test_home_screen_on_open() -> bool:
	var ui := _make_ui()
	return ui.get_active_screen() == "home"


func _test_navigate_online_orders() -> bool:
	var ui := _make_ui()
	ui.navigate_to("online_orders")
	if ui.get_active_screen() != "online_orders":
		return false
	var screen: VBoxContainer = ui.get_online_orders_screen()
	if screen == null or not screen.has_method("get_order_card_count"):
		return false
	return screen.get_order_card_count() >= 3


func _test_order_items_visible() -> bool:
	var orders: Array = OnlineOrderCatalogScript.get_orders()
	var block: String = OnlineOrderCatalogScript.format_items_block(orders[0])
	if not block.contains("computer mouse"):
		return false
	var screen: VBoxContainer = ComputerOnlineOrdersScreenScript.new()
	root.add_child(screen)
	screen.ensure_ready()
	var titles: PackedStringArray = screen.get_order_titles()
	var items_text: String = screen.get_first_order_items_text()
	return (
		titles.size() >= 1
		and titles[0] == "Online Order #1001"
		and items_text.contains("computer mouse")
	)


func _test_back_navigation() -> bool:
	var ui := _make_ui()
	ui.navigate_to("online_orders")
	ui.navigate_to("home")
	return ui.get_active_screen() == "home"


func _test_close_resets_home() -> bool:
	var ui := _make_ui()
	ui.navigate_to("online_orders")
	ui.close()
	ui.open()
	return ui.get_active_screen() == "home"
