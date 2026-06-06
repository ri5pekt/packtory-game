extends SceneTree

## Run with:
## godot --headless --path . --script res://scripts/test/street_lamp_test.gd

const LightingConfigScript = preload("res://scripts/gameplay/lighting_config.gd")
const StreetLampControllerScript = preload("res://scripts/warehouse/street_lamp_controller.gd")
const DayNightLightingScript = preload("res://scripts/warehouse/day_night_lighting.gd")
const GameTimeManagerScript = preload("res://scripts/gameplay/game_time_manager.gd")

const MAX_FACTOR_STEP := 0.08


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failed := 0
	failed += _assert("street lamps off during day", _test_lamps_off_during_day())
	failed += _assert("street lamps on during night", _test_lamps_on_at_night())
	failed += _assert("street lamps fade in during evening", _test_lamps_evening_ramp())
	failed += _assert("lamp controller activates automatically", await _test_controller_auto_activation())
	failed += _assert("evening outdoor darkens smoothly", _test_evening_darkens_naturally())
	failed += _assert("indoor lighting stays usable at night", _test_indoor_usable_at_night())

	if failed == 0:
		print("street_lamp_test: ALL PASSED")
		quit(0)
	else:
		push_error("street_lamp_test: %d FAILED" % failed)
		quit(1)


func _assert(label: String, ok: bool) -> int:
	if ok:
		print("  OK  ", label)
		return 0
	push_error("  FAIL ", label)
	return 1


func _test_lamps_off_during_day() -> bool:
	var noon := LightingConfigScript.sample_at_minutes(720.0)
	return float(noon.get("street_lamp_factor", 1.0)) <= 0.01


func _test_lamps_on_at_night() -> bool:
	var midnight := LightingConfigScript.sample_at_minutes(60.0)
	var late := LightingConfigScript.sample_at_minutes(1320.0)
	return (
		float(midnight.get("street_lamp_factor", 0.0)) >= 0.95
		and float(late.get("street_lamp_factor", 0.0)) >= 0.95
		and LightingConfigScript.street_lamp_energy_for_factor(
			float(midnight.get("street_lamp_factor", 0.0))
		) > 1.0
	)


func _test_lamps_evening_ramp() -> bool:
	var dusk := LightingConfigScript.sample_at_minutes(1080.0)
	var evening := LightingConfigScript.sample_at_minutes(1200.0)
	var day := LightingConfigScript.sample_at_minutes(720.0)
	return (
		float(day.get("street_lamp_factor", 1.0)) < float(dusk.get("street_lamp_factor", 0.0))
		and float(dusk.get("street_lamp_factor", 0.0)) < float(evening.get("street_lamp_factor", 0.0))
		and float(evening.get("street_lamp_factor", 0.0)) < 1.0
	)


func _test_controller_auto_activation() -> bool:
	var warehouse := Node3D.new()
	root.add_child(warehouse)

	var lamp_prop := Node3D.new()
	lamp_prop.name = "Streetlight_Test"
	lamp_prop.add_to_group("street_lamps")
	warehouse.add_child(lamp_prop)
	var lamp := OmniLight3D.new()
	lamp.name = "LampLight"
	lamp_prop.add_child(lamp)

	var lighting = DayNightLightingScript.new()
	lighting.name = "DayNightLighting"
	warehouse.add_child(lighting)
	var controller = StreetLampControllerScript.new()
	controller.name = "StreetLampController"
	lighting.add_child(controller)

	await process_frame
	await process_frame

	lighting._on_game_time_changed(720, 1)
	controller._process(0.5)
	var day_energy := lamp.light_energy
	var day_visible := lamp.visible

	lighting._target = LightingConfigScript.sample_at_minutes(1200.0)
	lighting.lighting_updated.emit(lighting._target)
	for _i in range(40):
		controller._process(1.0 / 60.0)
	var evening_energy := lamp.light_energy
	var evening_visible := lamp.visible

	warehouse.queue_free()
	return day_energy <= 0.02 and not day_visible and evening_energy > 0.4 and evening_visible


func _test_evening_darkens_naturally() -> bool:
	var day := LightingConfigScript.sample_at_minutes(720.0)
	var evening := LightingConfigScript.sample_at_minutes(1200.0)
	var max_step := 0.0
	var prev_factor := float(LightingConfigScript.sample_at_minutes(1020.0).get("street_lamp_factor", 0.0))
	var prev_sun := float(LightingConfigScript.sample_at_minutes(1020.0).get("sun_energy", 0.0))
	for minute in range(1021, 1231):
		var sample := LightingConfigScript.sample_at_minutes(float(minute))
		var factor := float(sample.get("street_lamp_factor", 0.0))
		var sun := float(sample.get("sun_energy", 0.0))
		max_step = maxf(max_step, absf(factor - prev_factor))
		max_step = maxf(max_step, absf(sun - prev_sun))
		prev_factor = factor
		prev_sun = sun
	return (
		float(evening.get("sun_energy", 1.0)) < float(day.get("sun_energy", 0.0))
		and max_step <= MAX_FACTOR_STEP
	)


func _test_indoor_usable_at_night() -> bool:
	for minute in [1200.0, 0.0, 1320.0]:
		var sample := LightingConfigScript.sample_at_minutes(minute)
		var ambient := float(sample.get("ambient_energy", 0.0))
		var fill := float(sample.get("indoor_fill_energy", 0.0))
		var interior_score := ambient + fill * 0.45
		if interior_score < 0.55:
			return false
	return true
