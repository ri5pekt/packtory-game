extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/customer_pedestrian_test.gd

const CustomerScript = preload("res://scripts/gameplay/customer.gd")
const CustomerQueueScript = preload("res://scripts/gameplay/customer_queue.gd")
const CustomerPedestrianScript = preload("res://scripts/warehouse/customer_pedestrian.gd")
const SidewalkPedestrianScript = preload("res://scripts/warehouse/sidewalk_pedestrian.gd")
const PedestrianRolesScript = preload("res://scripts/gameplay/pedestrian_roles.gd")
const ProductCatalogScript = preload("res://scripts/gameplay/product_catalog.gd")
const CustomerStatusScript = preload("res://scripts/gameplay/customer_status.gd")
const SidewalkPedestriansScript = preload("res://scripts/warehouse/sidewalk_pedestrians.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_ensure_grid_service()
	var failed := 0
	failed += _assert("decorative pedestrians never have orders", _test_decorative_has_no_order())
	failed += _assert("customer pedestrians carry order data", _test_customer_pedestrian_has_order())
	failed += _assert("approaching shoppers are not warehouse customers", _test_approach_not_identifiable())
	failed += _assert("admission links order to queue customer", await _test_admission_links_order())
	failed += _assert("admission keeps pedestrian position", await _test_admission_keeps_position())
	failed += _assert("approach path starts off the lot", await _test_approach_starts_off_map())
	failed += _assert("decorative pedestrians never join queue", await _test_decorative_never_joins_queue())
	failed += _assert("decorative routes avoid entrance walkway", await _test_decorative_routes_avoid_walkway())
	failed += _assert("warehouse customer only identifiable after entry", _test_entry_gate())

	if failed == 0:
		print("customer_pedestrian_test: ALL PASSED")
		quit(0)
	else:
		push_error("customer_pedestrian_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _ensure_grid_service() -> void:
	if root.get_node_or_null("GridService") != null:
		return
	var grid_script: Script = load("res://scripts/autoload/grid_service.gd") as Script
	var grid: Node = grid_script.new()
	grid.name = "GridService"
	root.add_child(grid)


func _test_decorative_has_no_order() -> bool:
	var pedestrian = SidewalkPedestrianScript.new()
	root.add_child(pedestrian)
	pedestrian.setup(
		_dummy_character_scene(),
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		1.5
	)
	var ok := (
		pedestrian.is_decorative()
		and not pedestrian.has_order()
		and pedestrian.get_order().is_empty()
		and PedestrianRolesScript.is_decorative(pedestrian)
	)
	pedestrian.queue_free()
	return ok


func _test_customer_pedestrian_has_order() -> bool:
	var order: Dictionary = {"mouse": 2}
	var pedestrian = CustomerPedestrianScript.new()
	root.add_child(pedestrian)
	pedestrian.setup(
		_dummy_character_scene(),
		order,
		[Vector3(0.0, 0.0, 10.0), Vector3(0.0, 0.0, 0.0)],
		1.4
	)
	var ok := (
		not pedestrian.is_decorative()
		and pedestrian.has_order()
		and ProductCatalogScript.orders_match(pedestrian.get_order(), order)
		and PedestrianRolesScript.is_customer_approach(pedestrian)
		and not PedestrianRolesScript.is_warehouse_customer(pedestrian)
	)
	pedestrian.queue_free()
	return ok


func _test_approach_not_identifiable() -> bool:
	var pedestrian = CustomerPedestrianScript.new()
	root.add_child(pedestrian)
	pedestrian.setup(
		_dummy_character_scene(),
		{"headphones": 1},
		[Vector3(0.0, 0.0, 5.0), Vector3(0.0, 0.0, 4.0)],
		2.0
	)
	var ok := (
		not pedestrian.is_in_group(PedestrianRolesScript.GROUP_WAREHOUSE_CUSTOMER)
		and not PedestrianRolesScript.is_warehouse_customer(pedestrian)
	)
	pedestrian.queue_free()
	return ok


func _test_admission_links_order() -> bool:
	var source_order: Dictionary = {"hair_dryer": 1, "mouse": 1}
	var pedestrian = CustomerPedestrianScript.new()
	root.add_child(pedestrian)
	pedestrian.setup(
		_dummy_character_scene(),
		source_order,
		[Vector3(0.0, 0.0, 8.0), Vector3(0.0, 0.0, 0.0)],
		1.5
	)

	var queue = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	await process_frame

	queue._admit_customer_pedestrian(pedestrian)
	await process_frame

	if queue.get_customer_count() != 1:
		queue.queue_free()
		return false
	var customer: Customer = queue._customers[0]
	var linked := ProductCatalogScript.orders_match(customer.order, source_order)
	var still_approaching: bool = queue.get_approaching_pedestrian_count() == 0
	queue.queue_free()
	return linked and still_approaching and customer.has_entered_warehouse()


func _test_admission_keeps_position() -> bool:
	var pedestrian = CustomerPedestrianScript.new()
	root.add_child(pedestrian)
	pedestrian.setup(
		_dummy_character_scene(),
		{"mouse": 1},
		[Vector3(4.0, 0.0, 12.0), Vector3(4.0, 0.0, 10.0)],
		1.5
	)
	pedestrian.global_position = Vector3(16.5, 0.07, 18.25)

	var queue = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	await process_frame

	queue._admit_customer_pedestrian(pedestrian)
	await process_frame

	if queue.get_customer_count() != 1:
		queue.queue_free()
		return false
	var customer: Customer = queue._customers[0]
	var kept := customer.global_position.distance_to(Vector3(16.5, 0.07, 18.25)) < 0.05
	queue.queue_free()
	return kept


func _test_approach_starts_off_map() -> bool:
	var queue = CustomerQueueScript.new()
	queue.name = "CustomerQueue"
	root.add_child(queue)
	await process_frame
	var waypoints: Array[Vector3] = queue._build_customer_approach_waypoints()
	queue.queue_free()
	if waypoints.is_empty():
		return false
	var grid: WarehouseGrid = root.get_node("GridService") as WarehouseGrid
	return waypoints[0].z > float(grid.total_size.y)


func _test_decorative_never_joins_queue() -> bool:
	var queue = CustomerQueueScript.new()
	root.add_child(queue)
	await process_frame
	var pedestrian = SidewalkPedestrianScript.new()
	root.add_child(pedestrian)
	pedestrian.setup(
		_dummy_character_scene(),
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 1.0),
		1.2
	)
	await process_frame
	var ok: bool = queue._customers.is_empty() and queue.get_approaching_pedestrian_count() == 0
	pedestrian.queue_free()
	queue.queue_free()
	return ok


func _test_decorative_routes_avoid_walkway() -> bool:
	var grid: WarehouseGrid = root.get_node("GridService") as WarehouseGrid
	var spawner: Node3D = SidewalkPedestriansScript.new()
	spawner.name = "SidewalkPedestrians"
	root.add_child(spawner)
	await process_frame
	var routes: Array = spawner.call("_build_routes")
	spawner.queue_free()
	var walkway_x: float = grid.get_walkway_x()
	for route_variant in routes:
		var route: Dictionary = route_variant
		var a: Vector3 = route["a"]
		var b: Vector3 = route["b"]
		if is_equal_approx(a.x, walkway_x) or is_equal_approx(b.x, walkway_x):
			return false
	return routes.size() == 2


func _test_entry_gate() -> bool:
	var customer: Customer = CustomerScript.new()
	root.add_child(customer)
	customer.setup(
		"",
		[Vector3(1.0, 0.0, 1.0), Vector3(2.0, 0.0, 2.0)],
		{"mouse": 1},
		Vector3(2.0, 0.0, 2.0),
		false
	)
	var hidden := not customer.has_entered_warehouse() and not customer.is_queue_status_visible()
	customer.mark_entered_warehouse()
	customer.set_queue_status(CustomerStatusScript.Kind.WAITING)
	var visible_after_entry := (
		customer.has_entered_warehouse() and customer.is_queue_status_visible()
	)
	customer.queue_free()
	return hidden and visible_after_entry


func _dummy_character_scene() -> PackedScene:
	var root_node := Node3D.new()
	root_node.name = "Model"
	var scene := PackedScene.new()
	scene.pack(root_node)
	root_node.free()
	return scene
