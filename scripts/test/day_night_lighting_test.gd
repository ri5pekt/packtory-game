extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/day_night_lighting_test.gd

const LightingConfigScript = preload("res://scripts/gameplay/lighting_config.gd")
const DayNightLightingScript = preload("res://scripts/warehouse/day_night_lighting.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")


const MAX_MINUTE_STEP_DELTA := 0.08
const SAMPLE_STEP_MINUTES := 1.0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failed := 0
	failed += _assert("full day includes all lighting periods", _test_all_periods_present())
	failed += _assert("full-day samples stay within indoor minimums", _test_indoor_usability())
	failed += _assert("minute steps have no sudden lighting jumps", _test_no_sudden_jumps())
	failed += _assert("lighting controller blends smoothly over time", _test_controller_smooth_blend())
	failed += _assert("game time updates retarget lighting smoothly", await _test_game_time_integration())
	failed += _assert("street lamp factor ramps with evening", _test_street_lamp_factor_ramp())

	if failed == 0:
		print("day_night_lighting_test: ALL PASSED")
		quit(0)
	else:
		push_error("day_night_lighting_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _test_all_periods_present() -> bool:
	var seen := {
		"night": false,
		"morning": false,
		"day": false,
		"evening": false,
	}
	for minute in range(0, LightingConfigScript.MINUTES_PER_DAY, 15):
		var period := LightingConfigScript.period_at_minutes(float(minute))
		if seen.has(period):
			seen[period] = true
	for key in seen:
		if not seen[key]:
			return false
	return true


func _test_indoor_usability() -> bool:
	for minute in range(0, LightingConfigScript.MINUTES_PER_DAY, 10):
		var sample: Dictionary = LightingConfigScript.sample_at_minutes(float(minute))
		var period := String(sample.get("period_name", ""))
		var ambient := float(sample.get("ambient_energy", 0.0))
		var fill := float(sample.get("indoor_fill_energy", 0.0))
		var sun := float(sample.get("sun_energy", 0.0))
		var interior_score := ambient + fill * 0.45 + sun * 0.15
		if interior_score < 0.52:
			return false
		if period == "night":
			if ambient + 0.001 < LightingConfigScript.INDOOR_MIN_AMBIENT:
				return false
			if fill + 0.001 < LightingConfigScript.INDOOR_MIN_FILL:
				return false
	return true


func _test_no_sudden_jumps() -> bool:
	return LightingConfigScript.max_channel_step(SAMPLE_STEP_MINUTES) <= MAX_MINUTE_STEP_DELTA


func _test_controller_smooth_blend() -> bool:
	var lighting = DayNightLightingScript.new()
	var max_delta := 0.0
	lighting._target = LightingConfigScript.sample_at_minutes(480.0)
	lighting._applied = lighting._target.duplicate(true)
	for _step in range(30):
		var before: Dictionary = lighting._applied.duplicate(true)
		lighting._target = LightingConfigScript.sample_at_minutes(1080.0)
		lighting._process(1.0 / 60.0)
		max_delta = maxf(
			max_delta,
			absf(float(lighting._applied.get("sun_energy", 0.0)) - float(before.get("sun_energy", 0.0)))
		)
	lighting.queue_free()
	return max_delta < MAX_MINUTE_STEP_DELTA * 2.0


func _test_game_time_integration() -> bool:
	var game_time: Node = GameTimeManagerScript.new()
	game_time.name = "GameTimeManager"
	root.add_child(game_time)
	game_time.reset_for_new_game()
	game_time.set_running(true)

	var warehouse := Node3D.new()
	warehouse.name = "Warehouse"
	root.add_child(warehouse)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	warehouse.add_child(sun)
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	world_env.environment = env
	warehouse.add_child(world_env)

	var lighting = DayNightLightingScript.new()
	lighting.name = "DayNightLighting"
	warehouse.add_child(lighting)
	await process_frame
	await process_frame

	var max_step := 0.0
	var prev := float(lighting._applied.get("sun_energy", 0.0))
	for _i in range(90):
		game_time.tick_real_seconds(1.0)
		lighting._process(1.0 / 60.0)
		var now := float(lighting._applied.get("sun_energy", 0.0))
		max_step = maxf(max_step, absf(now - prev))
		prev = now

	warehouse.queue_free()
	game_time.queue_free()
	return max_step <= MAX_MINUTE_STEP_DELTA * 2.0


func _test_street_lamp_factor_ramp() -> bool:
	var day := float(LightingConfigScript.sample_at_minutes(720.0).get("street_lamp_factor", 1.0))
	var evening := float(LightingConfigScript.sample_at_minutes(1200.0).get("street_lamp_factor", 0.0))
	var night := float(LightingConfigScript.sample_at_minutes(60.0).get("street_lamp_factor", 0.0))
	return day <= 0.01 and evening > 0.5 and night >= 0.95
