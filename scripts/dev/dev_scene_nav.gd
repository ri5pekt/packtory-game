extends Node

## Developer-only scene switcher. Press F9 to toggle main game ↔ character showcase.

const MAIN_SCENE := "res://scenes/main/main.tscn"
const SHOWCASE_SCENE := "res://scenes/dev/character_showcase.tscn"

var _switching := false


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if _switching:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_F9:
		return
	get_viewport().set_input_as_handled()
	_toggle_scene()


func _toggle_scene() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var target := SHOWCASE_SCENE if _is_main_scene() else MAIN_SCENE
	_switching = true
	tree.change_scene_to_file(target)
	_switching = false


func _is_main_scene() -> bool:
	var path := _current_scene_path()
	return path.ends_with("main.tscn") or path.ends_with("main/main.tscn")


func _current_scene_path() -> String:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return ""
	return tree.current_scene.scene_file_path
