extends SceneTree

## Temporary tool: loads the main game scene, waits for it to build, captures a
## screenshot to res://_shot.png, then quits. Run with:
##   Godot --script res://tools/screenshot_runner.gd

func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	get_root().add_child(scene)
	current_scene = scene

	await create_timer(1.0).timeout

	# Start the day so the welcome popup clears and the world populates.
	var session := scene.get_node_or_null("/root/GameSession")
	if session and session.has_method("start_day"):
		session.start_day()
	elif session and session.has_method("begin_day"):
		session.begin_day()

	# Hide the whole UI CanvasLayer so popups/HUD don't block the 3D view.
	var ui := scene.find_child("UI", true, false)
	if ui:
		ui.visible = false

	# Let walls, floor, deliveries and customers build.
	await create_timer(5.0).timeout

	var rig := scene.find_child("IsoCameraRig", true, false)
	if rig and rig.has_method("get_camera"):
		var cam: Camera3D = rig.get_camera()
		if cam:
			cam.size = 5.0
			rig.global_position = rig.global_position + Vector3(7.0, 0.0, 4.0)


	# Ensure a couple of rendered frames before grabbing the image.
	await process_frame
	await process_frame

	var vp := get_root()
	var img := vp.get_texture().get_image()
	if img != null:
		img.save_png("res://_shot.png")
		print("SCREENSHOT_SAVED")
	else:
		print("SCREENSHOT_FAILED")
	quit()
