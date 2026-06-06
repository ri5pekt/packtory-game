extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/outbound_delivery_vehicle_test.gd

const GridScript = preload("res://scripts/autoload/grid_service.gd")
const OutboundDeliveryConfigScript = preload(
	"res://scripts/gameplay/outbound_delivery_config.gd"
)
const OutboundDeliveryVehicleScript = preload(
	"res://scripts/warehouse/outbound_delivery_vehicle.gd"
)
const OutboundVanSpawnScript = preload(
	"res://scripts/warehouse/outbound_delivery_vehicle_spawn.gd"
)
const WorkerScript = preload("res://scripts/worker/worker.gd")


func _init() -> void:
	var failed := 0
	var grid := _make_grid()
	OutboundDeliveryConfigScript.set_package_capacity(4)
	failed += _assert("default van capacity is 4", _test_default_capacity())
	failed += _assert("capacity is upgradeable", _test_upgrade_capacity())
	failed += _assert("van joins outbound group", _test_van_group(grid))
	failed += _assert("van parks away from supply truck", _test_park_cell_separate())
	failed += _assert("loads tagged online package", _test_load_online_package(grid))
	failed += _assert("rejects in-person package", _test_reject_in_person_package(grid))
	failed += _assert("blocks load when van is full", _test_block_when_full(grid))
	failed += _assert("tracks loaded package metadata", _test_tracks_metadata(grid))

	if failed == 0:
		print("outbound_delivery_vehicle_test: ALL PASSED")
		quit(0)
	else:
		push_error("outbound_delivery_vehicle_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _make_grid() -> WarehouseGrid:
	var grid: WarehouseGrid = GridScript.new()
	grid.name = "GridService"
	root.add_child(grid)
	return grid


func _make_worker() -> Worker:
	var worker: Worker = WorkerScript.new()
	worker.name = "Worker"
	root.add_child(worker)
	return worker


func _make_van(grid: WarehouseGrid) -> Node3D:
	var van: Node3D = OutboundDeliveryVehicleScript.new()
	root.add_child(van)
	van.setup(
		grid.cell_to_world(OutboundVanSpawnScript.VAN_PARK_CELL),
		OutboundVanSpawnScript.VAN_YAW
	)
	return van


func _give_online_package(worker: Worker, order_number: int = 1001) -> void:
	worker.add_product("package")
	worker.tag_carried_package({
		"source": "online",
		"online_order_number": order_number,
	})


func _test_default_capacity() -> bool:
	return OutboundDeliveryConfigScript.get_package_capacity() == 4


func _test_upgrade_capacity() -> bool:
	OutboundDeliveryConfigScript.set_package_capacity(6)
	var ok := OutboundDeliveryConfigScript.get_package_capacity() == 6
	OutboundDeliveryConfigScript.set_package_capacity(4)
	return ok


func _test_van_group(grid: WarehouseGrid) -> bool:
	var van := _make_van(grid)
	return van.is_in_group("outbound_delivery_vehicles")


func _test_park_cell_separate() -> bool:
	var van_cell := OutboundVanSpawnScript.VAN_PARK_CELL
	var truck_cell := Vector2i(WarehouseGrid.DOCK_EAST_COL + 1, 16)
	return van_cell != truck_cell


func _test_load_online_package(grid: WarehouseGrid) -> bool:
	var van := _make_van(grid)
	var worker := _make_worker()
	_give_online_package(worker, 1002)
	if not van.try_load_from_worker(worker):
		return false
	return (
		van.get_loaded_count() == 1
		and not worker.has_package()
		and van.get_cargo_summary() == "1 / 4 packages"
	)


func _test_reject_in_person_package(grid: WarehouseGrid) -> bool:
	var van := _make_van(grid)
	var worker := _make_worker()
	worker.add_product("package")
	var reason: String = van.get_load_block_reason(worker)
	return (
		not van.try_load_from_worker(worker)
		and reason.find("online") >= 0
		and van.get_loaded_count() == 0
	)


func _test_block_when_full(grid: WarehouseGrid) -> bool:
	OutboundDeliveryConfigScript.set_package_capacity(2)
	var van := _make_van(grid)
	var worker := _make_worker()
	for i in range(2):
		_give_online_package(worker, 1000 + i)
		if not van.try_load_from_worker(worker):
			OutboundDeliveryConfigScript.set_package_capacity(4)
			return false
	_give_online_package(worker, 1003)
	var reason: String = van.get_load_block_reason(worker)
	var blocked: bool = not van.try_load_from_worker(worker)
	OutboundDeliveryConfigScript.set_package_capacity(4)
	return blocked and reason.to_lower().find("full") >= 0 and van.get_loaded_count() == 2


func _test_tracks_metadata(grid: WarehouseGrid) -> bool:
	var van := _make_van(grid)
	var worker := _make_worker()
	_give_online_package(worker, 1001)
	if not van.try_load_from_worker(worker):
		return false
	var loaded: Array = van.get_loaded_packages()
	return (
		loaded.size() == 1
		and String(loaded[0].get("source", "")) == "online"
		and int(loaded[0].get("online_order_number", 0)) == 1001
	)
