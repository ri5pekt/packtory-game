extends Node

## Drives KayKit streetlight lamp bulbs from the shared day/night lighting curve.

const LightingConfigScript = preload("res://scripts/gameplay/lighting_config.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")

const REALTIME_BLEND_SPEED := 2.5

var _lamps: Array[Light3D] = []
var _applied_factor := 0.0
var _target_factor := 0.0


func _ready() -> void:
	add_to_group("street_lamp_controller")
	call_deferred("_discover_lamps")
	call_deferred("_bind_lighting")


func _process(delta: float) -> void:
	var blend := clampf(delta * REALTIME_BLEND_SPEED, 0.0, 1.0)
	_applied_factor = lerpf(_applied_factor, _target_factor, blend)
	_apply_lamp_energy(_applied_factor)


func get_lamp_count() -> int:
	return _lamps.size()


func get_applied_factor() -> float:
	return _applied_factor


func get_target_factor() -> float:
	return _target_factor


func preview_factor(factor: float) -> void:
	_target_factor = clampf(factor, 0.0, 1.0)
	_applied_factor = _target_factor
	_apply_lamp_energy(_applied_factor)


func _discover_lamps() -> void:
	_lamps.clear()
	for prop in get_tree().get_nodes_in_group("street_lamps"):
		_append_lamp_light(prop, false)
	for prop in get_tree().get_nodes_in_group("desk_lamps"):
		_append_lamp_light(prop, true)


func _append_lamp_light(prop: Node, is_desk_lamp: bool) -> void:
	var lamp := prop.get_node_or_null("LampLight")
	if lamp is Light3D:
		lamp.set_meta("desk_lamp", is_desk_lamp)
		_lamps.append(lamp)


func _bind_lighting() -> void:
	var lighting := get_parent()
	if lighting and lighting.has_signal("lighting_updated"):
		if not lighting.lighting_updated.is_connected(_on_lighting_updated):
			lighting.lighting_updated.connect(_on_lighting_updated)
		if lighting.has_method("preview_at_minutes"):
			var sample: Dictionary = lighting.preview_at_minutes(_current_game_minutes())
			_on_lighting_updated(sample)


func _on_lighting_updated(state: Dictionary) -> void:
	_target_factor = float(state.get("street_lamp_factor", 0.0))


func _current_game_minutes() -> float:
	return GameTimeConfigScript.resolve_precise_minutes(get_node_or_null("/root/GameTimeManager"))


func _apply_lamp_energy(factor: float) -> void:
	var street_energy := LightingConfigScript.street_lamp_energy_for_factor(factor)
	var desk_energy := LightingConfigScript.desk_lamp_energy_for_factor(factor)
	for lamp in _lamps:
		if is_instance_valid(lamp):
			var energy := desk_energy if bool(lamp.get_meta("desk_lamp", false)) else street_energy
			lamp.light_energy = energy
			lamp.visible = energy > 0.02
