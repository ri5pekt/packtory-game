class_name ComputerScreenFeedback
extends RefCounted

## Status line + AlertMessages toast for computer terminal purchase screens.


static func notify(message: String, status_label: Label, warn: bool = false) -> void:
	if status_label != null:
		status_label.text = message
	var alerts := _alerts()
	if alerts == null:
		return
	if warn and alerts.has_method("warn"):
		alerts.warn(message)
	elif alerts.has_method("info"):
		alerts.info(message)


static func _alerts() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("AlertMessages")
