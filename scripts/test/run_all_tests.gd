extends SceneTree

## Run full headless test suite (spawns one Godot process per test):
## godot --headless --path . --script res://scripts/test/run_all_tests.gd

const TEST_SCRIPTS: PackedStringArray = [
	"res://scripts/test/order_flow_test.gd",
	"res://scripts/test/economy_test.gd",
	"res://scripts/test/economy_balance_test.gd",
	"res://scripts/test/progression_test.gd",
	"res://scripts/test/reputation_test.gd",
	"res://scripts/test/game_time_test.gd",
	"res://scripts/test/save_load_test.gd",
	"res://scripts/test/main_menu_day_start_test.gd",
	"res://scripts/test/reception_queue_test.gd",
	"res://scripts/test/customer_patience_test.gd",
	"res://scripts/test/customer_anger_reputation_test.gd",
	"res://scripts/test/customer_traffic_test.gd",
	"res://scripts/test/customer_status_bubble_test.gd",
	"res://scripts/test/customer_pedestrian_test.gd",
	"res://scripts/test/hud_top_panel_test.gd",
	"res://scripts/test/inventory_capacity_test.gd",
	"res://scripts/test/order_control_panel_test.gd",
	"res://scripts/test/interactable_raycast_test.gd",
	"res://scripts/test/computer_workstation_test.gd",
	"res://scripts/test/computer_online_orders_test.gd",
	"res://scripts/test/online_order_activation_test.gd",
	"res://scripts/test/product_reorder_test.gd",
	"res://scripts/test/equipment_order_test.gd",
	"res://scripts/test/equipment_delivery_flow_test.gd",
	"res://scripts/test/hire_workers_test.gd",
	"res://scripts/test/worker_task_assignment_test.gd",
	"res://scripts/test/storage_worker_test.gd",
	"res://scripts/test/worker_cleaning_test.gd",
	"res://scripts/test/daily_payroll_test.gd",
	"res://scripts/test/day_end_summary_test.gd",
	"res://scripts/test/garbage_drop_test.gd",
	"res://scripts/test/garbage_reputation_test.gd",
	"res://scripts/test/outbound_dispatch_test.gd",
	"res://scripts/test/outbound_delivery_vehicle_test.gd",
	"res://scripts/test/outbound_truck_stats_test.gd",
	"res://scripts/test/delivery_box_test.gd",
	"res://scripts/test/storage_shelf_test.gd",
	"res://scripts/test/product_unlock_test.gd",
	"res://scripts/test/warehouse_edit_test.gd",
	"res://scripts/test/settings_menu_test.gd",
	"res://scripts/test/day_night_lighting_test.gd",
	"res://scripts/test/street_lamp_test.gd",
]


func _init() -> void:
	var godot_exe := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var failed: Array[String] = []

	print("run_all_tests: %d suites via %s" % [TEST_SCRIPTS.size(), godot_exe])
	for script_path in TEST_SCRIPTS:
		var args := PackedStringArray([
			"--headless",
			"--path",
			project_path,
			"--script",
			script_path,
		])
		var output: Array = []
		var exit_code := OS.execute(godot_exe, args, output, true, false)
		var joined := "\n".join(output)
		# Some Windows headless runs report a bad exit code despite printing ALL PASSED.
		if joined.contains("ALL PASSED"):
			print("  PASS  %s" % script_path.get_file())
		else:
			failed.append(script_path.get_file())
			push_error("  FAIL  %s (exit %d)" % [script_path.get_file(), exit_code])
			if not joined.is_empty():
				print(joined)

	print("")
	if failed.is_empty():
		print("run_all_tests: ALL %d SUITES PASSED" % TEST_SCRIPTS.size())
		quit(0)
	else:
		push_error("run_all_tests: %d FAILED — %s" % [failed.size(), ", ".join(failed)])
		quit(1)
