extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/outbound_truck_stats_test.gd

const EconomyManagerScript = preload("res://scripts/gameplay/economy_manager.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")
const OutboundDeliveryVehicleScript = preload(
	"res://scripts/warehouse/outbound_delivery_vehicle.gd"
)
const OutboundVanSpawnScript = preload(
	"res://scripts/warehouse/outbound_delivery_vehicle_spawn.gd"
)
const OutboundTruckStatsScript = preload("res://scripts/gameplay/outbound_truck_stats.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_autoloads()
	OutboundTruckStatsScript.reset_to_defaults()
	var failed := 0
	failed += _assert("default route for one order", _test_default_single_order())
	failed += _assert("larger loads increase route duration", _test_load_scaling_formula())
	failed += _assert("speed multiplier reduces route duration", _test_speed_formula())
	failed += _assert("van route scales with package count", _test_van_multi_package_duration())
	failed += _assert("van route shortens with speed upgrade", _test_van_speed_upgrade())
	failed += _assert("truck stats persist in van save state", _test_stats_save_roundtrip())

	if failed == 0:
		print("outbound_truck_stats_test: ALL PASSED")
		quit(0)
	else:
		push_error("outbound_truck_stats_test: %d FAILED" % failed)
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


func _make_van() -> Node:
	for child in root.get_children():
		if child.is_in_group("outbound_delivery_vehicles"):
			child.queue_free()
	var grid: WarehouseGrid = root.get_node("GridService")
	var van: Node = OutboundDeliveryVehicleScript.new()
	van.name = "OutboundVan"
	root.add_child(van)
	van.setup(
		grid.cell_to_world(OutboundVanSpawnScript.VAN_PARK_CELL),
		OutboundVanSpawnScript.VAN_YAW
	)
	return van


func _load_packages(van: Node, count: int) -> void:
	for i in range(count):
		van.load_test_package({
			"source": "online",
			"online_order_number": 1000 + i,
		})


func _dispatch_route_total(van: Node) -> float:
	root.get_node("EconomyManager").set_coins(100)
	var result: Dictionary = van.try_dispatch(true)
	if not bool(result.get("ok", false)):
		return -1.0
	var progress: Dictionary = van.get_route_progress()
	return float(progress.get("total_minutes", 0.0))


func _test_default_single_order() -> bool:
	OutboundTruckStatsScript.reset_to_defaults()
	return is_equal_approx(
		OutboundTruckStatsScript.route_duration_minutes(1),
		60.0
	)


func _test_load_scaling_formula() -> bool:
	OutboundTruckStatsScript.reset_to_defaults()
	var one := OutboundTruckStatsScript.route_duration_minutes(1)
	var two := OutboundTruckStatsScript.route_duration_minutes(2)
	var three := OutboundTruckStatsScript.route_duration_minutes(3)
	return (
		is_equal_approx(one, 60.0)
		and is_equal_approx(two, 120.0)
		and is_equal_approx(three, 180.0)
		and two > one
		and three > two
	)


func _test_speed_formula() -> bool:
	OutboundTruckStatsScript.reset_to_defaults()
	var baseline := OutboundTruckStatsScript.route_duration_minutes(2)
	OutboundTruckStatsScript.set_speed_multiplier(2.0)
	var faster := OutboundTruckStatsScript.route_duration_minutes(2)
	return (
		is_equal_approx(baseline, 120.0)
		and is_equal_approx(faster, 60.0)
		and faster < baseline
	)


func _test_van_multi_package_duration() -> bool:
	OutboundTruckStatsScript.reset_to_defaults()
	var van_one := _make_van()
	_load_packages(van_one, 1)
	var single_total := _dispatch_route_total(van_one)
	van_one.force_complete_route()

	var van_two := _make_van()
	_load_packages(van_two, 2)
	var double_total := _dispatch_route_total(van_two)
	return (
		is_equal_approx(single_total, 60.0)
		and is_equal_approx(double_total, 120.0)
		and double_total > single_total
	)


func _test_van_speed_upgrade() -> bool:
	OutboundTruckStatsScript.reset_to_defaults()
	var van_slow := _make_van()
	_load_packages(van_slow, 2)
	var slow_total := _dispatch_route_total(van_slow)
	van_slow.force_complete_route()

	OutboundTruckStatsScript.set_speed_multiplier(2.0)
	var van_fast := _make_van()
	_load_packages(van_fast, 2)
	var fast_total := _dispatch_route_total(van_fast)
	return (
		is_equal_approx(slow_total, 120.0)
		and is_equal_approx(fast_total, 60.0)
		and fast_total < slow_total
	)


func _test_stats_save_roundtrip() -> bool:
	OutboundTruckStatsScript.reset_to_defaults()
	OutboundTruckStatsScript.set_speed_multiplier(1.5)
	OutboundTruckStatsScript.set_capacity(6)
	OutboundTruckStatsScript.set_operating_cost(12)
	var van := _make_van()
	var exported: Dictionary = van.export_save_state()
	OutboundTruckStatsScript.reset_to_defaults()
	van.apply_save_state(exported)
	return (
		is_equal_approx(OutboundTruckStatsScript.get_speed_multiplier(), 1.5)
		and OutboundTruckStatsScript.get_capacity() == 6
		and OutboundTruckStatsScript.get_operating_cost() == 12
	)
