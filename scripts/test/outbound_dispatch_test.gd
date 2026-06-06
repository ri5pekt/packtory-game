extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/outbound_dispatch_test.gd

const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const EconomyConfigScript = preload("res://scripts/gameplay/economy_config.gd")
const EconomyManagerScript = preload("res://scripts/gameplay/economy_manager.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const OutboundDeliveryVehicleScript = preload(
	"res://scripts/warehouse/outbound_delivery_vehicle.gd"
)
const OutboundVanSpawnScript = preload(
	"res://scripts/warehouse/outbound_delivery_vehicle_spawn.gd"
)
const OutboundDispatchConfigScript = preload(
	"res://scripts/gameplay/outbound_dispatch_config.gd"
)
const OutboundTruckStatsScript = preload("res://scripts/gameplay/outbound_truck_stats.gd")
const WorkerScript = preload("res://scripts/worker/worker.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	OutboundTruckStatsScript.reset_to_defaults()
	var failed := 0
	failed += _assert("dispatch fee is 1 coin", _test_dispatch_fee_config())
	failed += _assert("dispatch deducts fee", _test_dispatch_deducts_fee())
	failed += _assert("insufficient coins block dispatch", _test_insufficient_coins_blocked())
	failed += _assert("load does not grant reward", _test_load_no_reward())
	failed += _assert("dispatch departs and becomes unavailable", _test_dispatch_departure())
	failed += _assert("route progress tracks remaining time", _test_route_progress())
	failed += _assert("dispatch completion grants rewards", _test_rewards_after_completion())
	failed += _assert("van returns after route finishes", _test_van_returns())
	failed += _assert("delayed route completes via game time", await _test_delayed_route_completion())

	if failed == 0:
		print("outbound_dispatch_test: ALL PASSED")
		quit(0)
	else:
		push_error("outbound_dispatch_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_autoloads() -> void:
	if root.get_node_or_null("GridService") == null:
		var grid: WarehouseGrid = GridScript.new()
		grid.name = "GridService"
		root.add_child(grid)
	if root.get_node_or_null("EconomyManager") == null:
		var economy: Node = EconomyManagerScript.new()
		economy.name = "EconomyManager"
		root.add_child(economy)
	if root.get_node_or_null("GameTimeManager") == null:
		var time: Node = GameTimeManagerScript.new()
		time.name = "GameTimeManager"
		root.add_child(time)


func _economy() -> Node:
	return root.get_node("EconomyManager")


func _time() -> Node:
	return root.get_node("GameTimeManager")


func _make_queue() -> Node:
	for child in root.get_children():
		if child.is_in_group("customer_queue"):
			child.queue_free()
	var queue: Node = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	queue.add_to_group("customer_queue")
	root.add_child(queue)
	if _economy().has_method("_connect_queue"):
		_economy()._connect_queue(queue)
	return queue


func _make_grid() -> WarehouseGrid:
	var grid: WarehouseGrid = GridScript.new()
	if root.get_node_or_null("GridService") == null:
		grid.name = "GridService"
		root.add_child(grid)
	else:
		grid = root.get_node("GridService")
	return grid


func _make_van(grid: WarehouseGrid) -> Node:
	for child in root.get_children():
		if child.is_in_group("outbound_delivery_vehicles"):
			child.queue_free()
	var van: Node = OutboundDeliveryVehicleScript.new()
	van.name = "OutboundVan"
	root.add_child(van)
	van.setup(
		grid.cell_to_world(OutboundVanSpawnScript.VAN_PARK_CELL),
		OutboundVanSpawnScript.VAN_YAW
	)
	return van


func _make_worker() -> Worker:
	var worker: Worker = WorkerScript.new()
	worker.name = "Worker"
	root.add_child(worker)
	return worker


func _load_online_package(van: Node, order_number: int = 1001) -> void:
	if van.has_method("load_test_package"):
		van.load_test_package({
			"source": "online",
			"online_order_number": order_number,
		})
		return
	var worker := _make_worker()
	worker.add_product("package")
	worker.tag_carried_package({
		"source": "online",
		"online_order_number": order_number,
	})
	van.try_load_from_worker(worker)
	worker.queue_free()


func _reset_economy(coins: int) -> void:
	_economy().set_coins(coins)


func _test_dispatch_fee_config() -> bool:
	return OutboundDispatchConfigScript.dispatch_fee() == EconomyConfigScript.OUTBOUND_DISPATCH_FEE \
		and EconomyConfigScript.OUTBOUND_DISPATCH_FEE == 1


func _test_dispatch_deducts_fee() -> bool:
	_make_queue()
	var grid := _make_grid()
	var van := _make_van(grid)
	_reset_economy(50)
	_load_online_package(van)
	var before: int = _economy().get_coins()
	var result: Dictionary = van.try_dispatch(true)
	var fee: int = OutboundDispatchConfigScript.dispatch_fee()
	return bool(result.get("ok", false)) and _economy().get_coins() == before - fee


func _test_insufficient_coins_blocked() -> bool:
	_make_queue()
	var grid := _make_grid()
	var van := _make_van(grid)
	_reset_economy(0)
	_load_online_package(van)
	var result: Dictionary = van.try_dispatch(true)
	return (
		not bool(result.get("ok", false))
		and String(result.get("reason", "")) == "insufficient_coins"
		and van.get_loaded_count() == 1
		and _economy().get_coins() == 0
	)


func _test_load_no_reward() -> bool:
	_make_queue()
	var grid := _make_grid()
	var van := _make_van(grid)
	_reset_economy(0)
	_load_online_package(van)
	return _economy().get_coins() == 0 and van.get_loaded_count() == 1


func _test_dispatch_departure() -> bool:
	_make_queue()
	var grid := _make_grid()
	var van := _make_van(grid)
	_reset_economy(50)
	_load_online_package(van)
	var result: Dictionary = van.try_dispatch(true)
	return (
		bool(result.get("ok", false))
		and van.is_on_route()
		and not van.is_available()
		and van.get_loaded_count() == 0
		and not van.visible
	)


func _test_route_progress() -> bool:
	_make_queue()
	var grid := _make_grid()
	var van := _make_van(grid)
	_reset_economy(50)
	_load_online_package(van)
	van.try_dispatch(true)
	var progress: Dictionary = van.get_route_progress()
	return (
		van.is_on_route()
		and float(progress.get("remaining_minutes", 0.0)) > 0.0
		and is_equal_approx(
			float(progress.get("total_minutes", 0.0)),
			OutboundTruckStatsScript.route_duration_minutes(1)
		)
	)


func _test_rewards_after_completion() -> bool:
	var queue := _make_queue()
	var grid := _make_grid()
	var van := _make_van(grid)
	_reset_economy(50)
	_load_online_package(van, 1001)
	van.try_dispatch(true)
	if not van.force_complete_route():
		return false
	var reward: int = EconomyConfigScript.ONLINE_ORDER_REWARD
	return _economy().get_coins() == 50 - OutboundDispatchConfigScript.dispatch_fee() + reward


func _test_van_returns() -> bool:
	_make_queue()
	var grid := _make_grid()
	var van := _make_van(grid)
	_reset_economy(50)
	_load_online_package(van)
	van.try_dispatch(true)
	van.force_complete_route()
	return not van.is_on_route() and van.is_available() and van.visible


func _test_delayed_route_completion() -> bool:
	_make_queue()
	var grid := _make_grid()
	var van := _make_van(grid)
	_reset_economy(50)
	_time().set_time(1, 480)
	_load_online_package(van)
	van.try_dispatch(true)
	var progress: Dictionary = van.get_route_progress()
	var remaining: float = float(progress.get("remaining_minutes", 0.0))
	_time().advance_by_game_minutes(remaining + 1.0)
	van.process_route_due()
	await process_frame
	return not van.is_on_route() and van.is_available()
