extends Node

@onready var touch_input: Node = $TouchInput
@onready var camera_rig: Node3D = $IsoCameraRig


func _ready() -> void:
	touch_input.pan_drag.connect(camera_rig.pan_screen_delta)
	touch_input.zoom.connect(camera_rig.zoom_by)
	touch_input.reset_view_requested.connect(camera_rig.reset_view)
