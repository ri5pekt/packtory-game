class_name SettingsMenuConfig
extends RefCounted

## Tuning for the settings menu and manual End Day availability.

const GameTimeConfigScript = preload("res://scripts/gameplay/game_time_config.gd")

# End Day becomes available once evening store hours begin (6:00 PM).
const END_DAY_AVAILABLE_FROM_MINUTES := 1020.0

# Show a gentle evening reminder in settings during late store hours.
const EVENING_REMINDER_FROM_MINUTES := 1020.0

const REASON_GAME_NOT_STARTED := "Start the day before ending it."
const REASON_ALREADY_ENDED := "Today's payroll is already settled."
const REASON_TOO_EARLY := "End Day opens in the evening."
const EVENING_REMINDER_TEXT := (
	"Evening hours — wrap up orders and end the day when you're ready."
)
