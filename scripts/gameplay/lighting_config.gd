class_name LightingConfig
extends RefCounted

## Day/night lighting keyframes — smooth interpolation across a full 24-hour cycle.

enum Period { NIGHT, MORNING, DAY, EVENING }

const PERIOD_NAMES := {
	Period.NIGHT: "night",
	Period.MORNING: "morning",
	Period.DAY: "day",
	Period.EVENING: "evening",
}

const MINUTES_PER_DAY := 24 * 60
const INDOOR_MIN_AMBIENT := 0.30
const INDOOR_MIN_FILL := 0.85
const STREET_LAMP_MAX_ENERGY := 1.35
const STREET_LAMP_LIGHT_HEIGHT := 2.75
const STREET_LAMP_RANGE := 9.0
const DESK_LAMP_MAX_ENERGY := 1.05

# minute, period, sun_energy, sun_color, sky_color, ambient_energy, indoor_fill_energy, sun_pitch_deg
const KEYFRAMES: Array[Dictionary] = [
	{
		"minute": 0.0,
		"period": Period.NIGHT,
		"sun_energy": 0.12,
		"sun_color": Color(0.62, 0.72, 0.95),
		"sky_color": Color(0.06, 0.08, 0.16),
		"ambient_energy": INDOOR_MIN_AMBIENT,
		"indoor_fill_energy": 1.15,
		"sun_pitch_deg": -35.0,
		"street_lamp_factor": 1.0,
	},
	{
		"minute": 300.0,
		"period": Period.NIGHT,
		"sun_energy": 0.08,
		"sun_color": Color(0.55, 0.65, 0.9),
		"sky_color": Color(0.04, 0.05, 0.12),
		"ambient_energy": INDOOR_MIN_AMBIENT,
		"indoor_fill_energy": 1.2,
		"sun_pitch_deg": -50.0,
		"street_lamp_factor": 1.0,
	},
	{
		"minute": 360.0,
		"period": Period.MORNING,
		"sun_energy": 0.45,
		"sun_color": Color(1.0, 0.82, 0.62),
		"sky_color": Color(0.72, 0.58, 0.48),
		"ambient_energy": 0.34,
		"indoor_fill_energy": 0.95,
		"sun_pitch_deg": -18.0,
		"street_lamp_factor": 0.0,
	},
	{
		"minute": 480.0,
		"period": Period.DAY,
		"sun_energy": 1.25,
		"sun_color": Color(1.0, 0.972549, 0.941176),
		"sky_color": Color(0.45, 0.58, 0.72),
		"ambient_energy": 0.4,
		"indoor_fill_energy": 0.55,
		"sun_pitch_deg": -8.0,
		"street_lamp_factor": 0.0,
	},
	{
		"minute": 720.0,
		"period": Period.DAY,
		"sun_energy": 1.35,
		"sun_color": Color(1.0, 0.99, 0.94),
		"sky_color": Color(0.5, 0.66, 0.82),
		"ambient_energy": 0.42,
		"indoor_fill_energy": 0.5,
		"sun_pitch_deg": -2.0,
		"street_lamp_factor": 0.0,
	},
	{
		"minute": 1080.0,
		"period": Period.EVENING,
		"sun_energy": 0.55,
		"sun_color": Color(1.0, 0.72, 0.45),
		"sky_color": Color(0.52, 0.34, 0.28),
		"ambient_energy": 0.32,
		"indoor_fill_energy": 0.75,
		"sun_pitch_deg": -12.0,
		"street_lamp_factor": 0.25,
	},
	{
		"minute": 1200.0,
		"period": Period.EVENING,
		"sun_energy": 0.28,
		"sun_color": Color(0.95, 0.55, 0.38),
		"sky_color": Color(0.2, 0.16, 0.26),
		"ambient_energy": 0.3,
		"indoor_fill_energy": 0.95,
		"sun_pitch_deg": -22.0,
		"street_lamp_factor": 0.85,
	},
	{
		"minute": 1320.0,
		"period": Period.NIGHT,
		"sun_energy": 0.14,
		"sun_color": Color(0.6, 0.7, 0.92),
		"sky_color": Color(0.08, 0.1, 0.18),
		"ambient_energy": INDOOR_MIN_AMBIENT,
		"indoor_fill_energy": 1.1,
		"sun_pitch_deg": -32.0,
		"street_lamp_factor": 1.0,
	},
]


static func wrap_minutes(minutes: float) -> float:
	var wrapped := fmod(minutes, float(MINUTES_PER_DAY))
	if wrapped < 0.0:
		wrapped += float(MINUTES_PER_DAY)
	return wrapped


static func period_name(period: int) -> String:
	return String(PERIOD_NAMES.get(period, "day"))


static func sample_at_minutes(minutes: float) -> Dictionary:
	var wrapped := wrap_minutes(minutes)
	var frame_count := KEYFRAMES.size()
	for i in range(frame_count):
		var start: Dictionary = KEYFRAMES[i]
		var end: Dictionary = KEYFRAMES[(i + 1) % frame_count]
		var start_min := float(start.get("minute", 0.0))
		var end_min := float(end.get("minute", 0.0))
		if end_min < start_min:
			end_min += float(MINUTES_PER_DAY)
		var sample_min := wrapped
		if sample_min < start_min:
			sample_min += float(MINUTES_PER_DAY)
		if sample_min >= start_min and sample_min < end_min:
			var span := end_min - start_min
			var t := 0.0 if span <= 0.0 else (sample_min - start_min) / span
			return _lerp_frames(start, end, t)
	return _frame_to_state(KEYFRAMES[0])


static func period_at_minutes(minutes: float) -> String:
	return period_name(int(sample_at_minutes(minutes).get("period", Period.DAY)))


static func max_channel_step(step_minutes: float) -> float:
	var max_delta := 0.0
	var prev := sample_at_minutes(0.0)
	var steps := int(ceil(float(MINUTES_PER_DAY) / step_minutes))
	for i in range(1, steps + 1):
		var minute := float(i) * step_minutes
		var next := sample_at_minutes(minute)
		max_delta = maxf(max_delta, absf(float(next.get("sun_energy", 0.0)) - float(prev.get("sun_energy", 0.0))))
		max_delta = maxf(max_delta, absf(float(next.get("ambient_energy", 0.0)) - float(prev.get("ambient_energy", 0.0))))
		max_delta = maxf(max_delta, absf(float(next.get("indoor_fill_energy", 0.0)) - float(prev.get("indoor_fill_energy", 0.0))))
		max_delta = maxf(
			max_delta,
			absf(float(next.get("street_lamp_factor", 0.0)) - float(prev.get("street_lamp_factor", 0.0)))
		)
		var sky_a: Color = prev.get("sky_color", Color.BLACK)
		var sky_b: Color = next.get("sky_color", Color.BLACK)
		max_delta = maxf(max_delta, absf(sky_a.r - sky_b.r))
		max_delta = maxf(max_delta, absf(sky_a.g - sky_b.g))
		max_delta = maxf(max_delta, absf(sky_a.b - sky_b.b))
		prev = next
	return max_delta


static func _lerp_frames(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var blend := clampf(t, 0.0, 1.0)
	var period := int(a.get("period", Period.DAY)) if blend < 0.5 else int(b.get("period", Period.DAY))
	return {
		"period": period,
		"period_name": period_name(period),
		"sun_energy": lerpf(float(a.get("sun_energy", 0.0)), float(b.get("sun_energy", 0.0)), blend),
		"sun_color": (a.get("sun_color", Color.WHITE) as Color).lerp(b.get("sun_color", Color.WHITE), blend),
		"sky_color": (a.get("sky_color", Color.BLACK) as Color).lerp(b.get("sky_color", Color.BLACK), blend),
		"ambient_energy": lerpf(float(a.get("ambient_energy", 0.0)), float(b.get("ambient_energy", 0.0)), blend),
		"indoor_fill_energy": lerpf(
			float(a.get("indoor_fill_energy", 0.0)),
			float(b.get("indoor_fill_energy", 0.0)),
			blend
		),
		"sun_pitch_deg": lerpf(float(a.get("sun_pitch_deg", 0.0)), float(b.get("sun_pitch_deg", 0.0)), blend),
		"street_lamp_factor": lerpf(
			float(a.get("street_lamp_factor", 0.0)),
			float(b.get("street_lamp_factor", 0.0)),
			blend
		),
	}


static func _frame_to_state(frame: Dictionary) -> Dictionary:
	var period := int(frame.get("period", Period.DAY))
	return {
		"period": period,
		"period_name": period_name(period),
		"sun_energy": float(frame.get("sun_energy", 1.0)),
		"sun_color": frame.get("sun_color", Color.WHITE),
		"sky_color": frame.get("sky_color", Color.BLACK),
		"ambient_energy": float(frame.get("ambient_energy", 0.4)),
		"indoor_fill_energy": float(frame.get("indoor_fill_energy", 0.5)),
		"sun_pitch_deg": float(frame.get("sun_pitch_deg", -8.0)),
		"street_lamp_factor": float(frame.get("street_lamp_factor", 0.0)),
	}


static func street_lamp_energy_for_factor(factor: float) -> float:
	return clampf(factor, 0.0, 1.0) * STREET_LAMP_MAX_ENERGY


static func desk_lamp_energy_for_factor(factor: float) -> float:
	return clampf(factor, 0.0, 1.0) * DESK_LAMP_MAX_ENERGY
