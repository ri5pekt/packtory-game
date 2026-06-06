extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/computer_workstation_test.gd

const ComputerSectionsConfigScript = preload("res://scripts/gameplay/computer_sections_config.gd")
const ComputerTerminalFlowScript = preload("res://scripts/shared/computer_terminal_flow.gd")
const ComputerWorkstationScript = preload("res://scripts/warehouse/computer_workstation.gd")
const ComputerInterfaceUIScript = preload("res://scripts/ui/computer_interface_ui.gd")
const InteractableRaycastScript = preload("res://scripts/shared/interactable_raycast.gd")
const GridScript = preload("res://scripts/autoload/grid_service.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failed := 0
	var grid := _make_grid()
	failed += _assert("workstation spawns in warehouse group", _test_workstation_group(grid))
	failed += _assert("workstation has approach and face targets", _test_approach_targets(grid))
	failed += _assert("workstation is warehouse placeable", _test_placeable_contract(grid))
	failed += _assert("raycast resolves computer workstation", _test_raycast_resolution(grid))
	failed += _assert("section registry includes all modules", _test_section_registry())
	failed += _assert("home screen lists all configured sections", _test_home_sections())
	failed += _assert("hire workers opens implemented screen", _test_hire_workers_screen())
	failed += _assert("computer UI opens and closes", _test_computer_ui())
	failed += _assert("computer UI closes on outside tap", _test_ui_close_on_outside_tap())
	failed += _assert("computer UI ignores taps while closed", _test_ui_tap_blocking())
	failed += _assert("terminal flow waits for walk before opening", _test_terminal_flow_walk_gate())
	failed += _assert("terminal flow opens UI after arrival", await _test_terminal_flow_opens_on_arrival())

	if failed == 0:
		print("computer_workstation_test: ALL PASSED")
		quit(0)
	else:
		push_error("computer_workstation_test: %d FAILED" % failed)
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


func _make_workstation(grid: WarehouseGrid) -> Node3D:
	var ws: Node3D = ComputerWorkstationScript.new()
	root.add_child(ws)
	ws.setup(grid.cell_to_world(Vector2i(12, 14)), 0.0)
	return ws


func _make_ui() -> Control:
	var ui: Control = ComputerInterfaceUIScript.new()
	ui.set_size(Vector2(720.0, 520.0))
	root.add_child(ui)
	return ui


func _test_workstation_group(grid: WarehouseGrid) -> bool:
	var ws := _make_workstation(grid)
	return ws.is_in_group("computer_workstations")


func _test_approach_targets(grid: WarehouseGrid) -> bool:
	var ws := _make_workstation(grid)
	var approach: Vector3 = ws.get_approach_position()
	var face: Vector3 = ws.get_face_target()
	return approach.distance_to(ws.global_position) > 0.2 and face.y > ws.global_position.y


func _test_placeable_contract(grid: WarehouseGrid) -> bool:
	var ws := _make_workstation(grid)
	return (
		ws.is_in_group("warehouse_placeables")
		and ws.has_method("apply_placement")
		and ws.get_placeable_label() == "Computer Desk"
	)


func _test_raycast_resolution(grid: WarehouseGrid) -> bool:
	var ws := _make_workstation(grid)
	var click_area := ws.get_node_or_null("ClickArea") as Area3D
	if click_area == null:
		return false
	var resolved: Node = InteractableRaycastScript.resolve_interactable(click_area)
	return resolved == ws


func _test_section_registry() -> bool:
	var ids := ComputerSectionsConfigScript.get_section_ids()
	return (
		ids.has(ComputerSectionsConfigScript.SECTION_ONLINE_ORDERS)
		and ids.has(ComputerSectionsConfigScript.SECTION_ORDER_EQUIPMENT)
		and ids.has(ComputerSectionsConfigScript.SECTION_REORDER_PRODUCTS)
		and ids.has(ComputerSectionsConfigScript.SECTION_HIRE_WORKERS)
		and not ComputerSectionsConfigScript.is_placeholder(
			ComputerSectionsConfigScript.SECTION_ORDER_EQUIPMENT
		)
		and not ComputerSectionsConfigScript.is_placeholder(
			ComputerSectionsConfigScript.SECTION_REORDER_PRODUCTS
		)
		and not ComputerSectionsConfigScript.is_placeholder(
			ComputerSectionsConfigScript.SECTION_HIRE_WORKERS
		)
	)


func _test_home_sections() -> bool:
	var ui := _make_ui()
	ui.open()
	var labels: PackedStringArray = ui.get_home_section_labels()
	ui.close()
	return (
		labels.size() == ComputerSectionsConfigScript.get_sections().size()
		and labels.has("Online Orders")
		and labels.has("Order Equipment")
		and labels.has("Reorder Products")
		and labels.has("Hire Workers")
	)


func _test_hire_workers_screen() -> bool:
	var ui := _make_ui()
	ui.open()
	ui.navigate_to(ComputerSectionsConfigScript.SECTION_HIRE_WORKERS)
	var ok: bool = (
		ui.get_active_screen() == ComputerSectionsConfigScript.SECTION_HIRE_WORKERS
		and ui.get_hire_workers_screen() != null
		and ui.get_placeholder_screen() == null
	)
	ui.navigate_to("home")
	ui.close()
	return ok


func _test_computer_ui() -> bool:
	var ui := _make_ui()
	ui.open()
	var opened: bool = ui.is_open()
	ui.close()
	return opened and not ui.is_open() and ui.get_active_screen() == "home"


func _test_ui_close_on_outside_tap() -> bool:
	var ui := _make_ui()
	ui.open()
	var consumed: bool = ui.notify_world_tap(Vector2(8.0, 8.0))
	return consumed and not ui.is_open()


func _test_ui_tap_blocking() -> bool:
	var ui := _make_ui()
	return not ui.notify_world_tap(Vector2(8.0, 8.0))


func _test_terminal_flow_walk_gate() -> bool:
	var grid := _make_grid()
	var ws := _make_workstation(grid)
	var ui := _make_ui()
	var actor := _MockWorker.new()
	root.add_child(actor)

	var started := ComputerTerminalFlowScript.begin_enter(actor, ws, ui)
	return started and not ui.is_open() and actor.is_moving()


func _test_terminal_flow_opens_on_arrival() -> bool:
	var grid := _make_grid()
	var ws := _make_workstation(grid)
	var ui := _make_ui()
	var actor := _MockWorker.new()
	root.add_child(actor)

	var result := {"opened": false}
	ComputerTerminalFlowScript.begin_enter(
		actor,
		ws,
		ui,
		Callable(),
		func(success: bool) -> void:
			result.opened = success
	)
	actor.simulate_arrive()
	await process_frame
	return ui.is_open() and bool(result.opened) and actor.faced_monitor


class _MockWorker:
	extends Node3D

	var faced_monitor := false
	var _moving := false
	var _arrive_callback: Callable = Callable()

	func walk_to_world(_world_position: Vector3, on_arrive: Callable = Callable()) -> void:
		_moving = true
		_arrive_callback = on_arrive

	func simulate_arrive() -> void:
		_moving = false
		if _arrive_callback.is_valid():
			_arrive_callback.call()

	func face_world(_target: Vector3) -> void:
		faced_monitor = true

	func is_moving() -> bool:
		return _moving

	func is_packing() -> bool:
		return false
