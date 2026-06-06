extends Node3D

## Smooth outdoor + indoor lighting driven by accelerated game time.

signal lighting_updated(state: Dictionary)

const LightingConfigScript = preload("res://scripts/gameplay/lighting_config.gd")
const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")

const INDOOR_FILL_POSITION := Vector3(12.0, 4.5, 14.0)
const INDOOR_FILL_RANGE := 24.0
const StreetLampControllerScript = preload("res://scripts/warehouse/street_lamp_controller.gd")

const REALTIME_BLEND_SPEED := 2.5

var _sun: DirectionalLight3D
var _world_environment: WorldEnvironment
var _environment: Environment
var _indoor_fill: OmniLight3D
var _applied: Dictionary = {}
var _target: Dictionary = {}
var _sun_base_basis: Basis


func _ready() -> void:
	add_to_group("day_night_lighting")
	_resolve_scene_lights()
	_create_indoor_fill()
	_capture_sun_basis()
	_duplicate_environment()
	_target = LightingConfigScript.sample_at_minutes(_current_game_minutes())
	_applied = _target.duplicate(true)
	_apply_state(_applied)
	_ensure_street_lamp_controller()
	call_deferred("_bind_game_time")


func _process(delta: float) -> void:
	if _target.is_empty():
		return
	var blend := clampf(delta * REALTIME_BLEND_SPEED, 0.0, 1.0)
	_applied = _lerp_states(_applied, _target, blend)
	_apply_state(_applied)


func preview_at_minutes(minutes: float) -> Dictionary:
	return LightingConfigScript.sample_at_minutes(minutes)


func get_current_period() -> String:
	return String(_applied.get("period_name", "day"))


func _bind_game_time() -> void:
	var game_time := get_node_or_null("/root/GameTimeManager")
	if game_time == null:
		_target = LightingConfigScript.sample_at_minutes(_current_game_minutes())
		return
	_on_game_time_changed(game_time.get_precise_minutes(), game_time.get_day())
	if not game_time.time_changed.is_connected(_on_game_time_changed):
		game_time.time_changed.connect(_on_game_time_changed)


func _on_game_time_changed(_minute: int, _day: int) -> void:
	var game_time := get_node_or_null("/root/GameTimeManager")
	var precise: float = game_time.get_precise_minutes() if game_time else float(_current_game_minutes())
	_target = LightingConfigScript.sample_at_minutes(precise)
	lighting_updated.emit(_target.duplicate(true))


func _current_game_minutes() -> float:
	return GameTimeConfigScript.resolve_precise_minutes(get_node_or_null("/root/GameTimeManager"))


func _resolve_scene_lights() -> void:
	var root := get_parent()
	if root == null:
		return
	_sun = root.get_node_or_null("Sun") as DirectionalLight3D
	_world_environment = root.get_node_or_null("WorldEnvironment") as WorldEnvironment


func _create_indoor_fill() -> void:
	var root := get_parent()
	if root == null:
		return
	_indoor_fill = root.get_node_or_null("WarehouseIndoorFill") as OmniLight3D
	if _indoor_fill:
		return
	_indoor_fill = OmniLight3D.new()
	_indoor_fill.name = "WarehouseIndoorFill"
	_indoor_fill.position = INDOOR_FILL_POSITION
	_indoor_fill.light_color = Color(1.0, 0.95, 0.88)
	_indoor_fill.omni_range = INDOOR_FILL_RANGE
	_indoor_fill.shadow_enabled = false
	_indoor_fill.light_energy = 0.55
	root.add_child(_indoor_fill)


func _capture_sun_basis() -> void:
	if _sun:
		_sun_base_basis = _sun.transform.basis


func _duplicate_environment() -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	_environment = _world_environment.environment.duplicate(true)
	_world_environment.environment = _environment


func _apply_state(state: Dictionary) -> void:
	if _sun:
		_sun.light_energy = float(state.get("sun_energy", _sun.light_energy))
		_sun.light_color = state.get("sun_color", _sun.light_color)
		_apply_sun_pitch(float(state.get("sun_pitch_deg", -8.0)))
	if _environment:
		_environment.background_color = state.get("sky_color", _environment.background_color)
		_environment.ambient_light_energy = maxf(
			float(state.get("ambient_energy", _environment.ambient_light_energy)),
			LightingConfigScript.INDOOR_MIN_AMBIENT
		)
	if _indoor_fill:
		_indoor_fill.light_energy = maxf(
			float(state.get("indoor_fill_energy", _indoor_fill.light_energy)),
			LightingConfigScript.INDOOR_MIN_FILL
		)


func _apply_sun_pitch(pitch_deg: float) -> void:
	if _sun == null:
		return
	var yaw_basis := _sun_base_basis
	var pitch := deg_to_rad(pitch_deg)
	_sun.transform.basis = Basis(Vector3.RIGHT, pitch) * yaw_basis


func _lerp_states(from_state: Dictionary, to_state: Dictionary, t: float) -> Dictionary:
	var blend := clampf(t, 0.0, 1.0)
	var from_color: Color = from_state.get("sun_color", Color.WHITE)
	var to_color: Color = to_state.get("sun_color", Color.WHITE)
	var from_sky: Color = from_state.get("sky_color", Color.BLACK)
	var to_sky: Color = to_state.get("sky_color", Color.BLACK)
	return {
		"period": to_state.get("period", from_state.get("period", LightingConfigScript.Period.DAY)),
		"period_name": to_state.get("period_name", from_state.get("period_name", "day")),
		"sun_energy": lerpf(float(from_state.get("sun_energy", 0.0)), float(to_state.get("sun_energy", 0.0)), blend),
		"sun_color": from_color.lerp(to_color, blend),
		"sky_color": from_sky.lerp(to_sky, blend),
		"ambient_energy": lerpf(
			float(from_state.get("ambient_energy", 0.0)),
			float(to_state.get("ambient_energy", 0.0)),
			blend
		),
		"indoor_fill_energy": lerpf(
			float(from_state.get("indoor_fill_energy", 0.0)),
			float(to_state.get("indoor_fill_energy", 0.0)),
			blend
		),
		"sun_pitch_deg": lerpf(
			float(from_state.get("sun_pitch_deg", 0.0)),
			float(to_state.get("sun_pitch_deg", 0.0)),
			blend
		),
		"street_lamp_factor": lerpf(
			float(from_state.get("street_lamp_factor", 0.0)),
			float(to_state.get("street_lamp_factor", 0.0)),
			blend
		),
	}


func _ensure_street_lamp_controller() -> void:
	if get_node_or_null("StreetLampController"):
		return
	var controller = StreetLampControllerScript.new()
	controller.name = "StreetLampController"
	add_child(controller)
