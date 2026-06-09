class_name ComputerWorkstation
extends Node3D

const WarehousePlaceableScript = preload("res://scripts/warehouse/warehouse_placeable.gd")

## Office desk with monitor and PC. Opens the computer interface when used.

const HP := "res://blender/assets/Household Props 001-glb/"
const DESK_MODEL := HP + "Desk.glb"
const MONITOR_MODEL := HP + "Monitor.glb"
const COMPUTER_MODEL := HP + "Computer.glb"
const MOUSE_MODEL := HP + "Mouse.glb"
const CHAIR_MODEL := HP + "Chair.glb"
const DESK_LAMP_MODEL := HP + "Desk Lamp.glb"

const CLICK_LAYER := 1
const DESK_SCALE := 1.05
const PROP_SCALE := 0.92
const APPROACH_Z := 0.9
const FACE_Z := 0.35
const FACE_MONITOR_Y := 0.58
const DESK_SURFACE_FALLBACK_Y := 0.433
const DESK_LAMP_LIGHT_HEIGHT := 0.78
const DESK_LAMP_RANGE := 4.0
const FOOTPRINT_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(0, 0),
	Vector2i(1, 0),
]
const OBSTACLE_SIZE := Vector3(2.65, 0.82, 1.05)
const OBSTACLE_CENTER := Vector3(0.0, 0.41, -0.02)

var _grid: WarehouseGrid
var _anchor_cell := Vector2i.ZERO
var _grid_obstacle: WarehouseObstacle


func _ready() -> void:
	_register_groups()


func setup(world_position: Vector3, yaw_deg: float) -> void:
	_ensure_grid()
	_anchor_cell = _grid.world_to_cell(world_position) if _grid else Vector2i.ZERO
	position = world_position
	rotation_degrees.y = yaw_deg
	if get_child_count() == 0:
		_build_workstation()
		_build_obstacle_collision()
		_build_click_area()
	else:
		_sync_click_area_layer()
	_register_groups()
	_bind_grid_obstacle()


func _register_groups() -> void:
	add_to_group("computer_workstations")
	add_to_group("warehouse_placeables")


func get_anchor_cell() -> Vector2i:
	return _anchor_cell


func get_placement_yaw() -> float:
	return rotation_degrees.y


func get_placeable_label() -> String:
	return "Computer Desk"


func get_footprint_cells_at(anchor_cell: Vector2i, yaw_deg: float) -> Array[Vector2i]:
	return WarehousePlaceableScript.rotated_footprint(anchor_cell, FOOTPRINT_OFFSETS, yaw_deg)


func get_ignore_cells() -> Array[Vector2i]:
	return get_footprint_cells_at(_anchor_cell, rotation_degrees.y)


func preview_placement(anchor_cell: Vector2i, yaw_deg: float) -> void:
	_ensure_grid()
	if _grid == null:
		return
	position = _grid.cell_to_world(anchor_cell)
	rotation_degrees.y = yaw_deg


func apply_placement(anchor_cell: Vector2i, yaw_deg: float) -> void:
	_ensure_grid()
	if _grid == null:
		return
	_release_grid_obstacle()
	_anchor_cell = anchor_cell
	setup(_grid.cell_to_world(anchor_cell), yaw_deg)
	_bind_grid_obstacle()


func release_placement_cells() -> void:
	_release_grid_obstacle()


func get_approach_position() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.0, APPROACH_Z)


func get_face_target() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, FACE_MONITOR_Y, FACE_Z)


func _ensure_grid() -> void:
	if _grid != null:
		return
	if is_inside_tree():
		_grid = get_tree().root.get_node_or_null("GridService") as WarehouseGrid
	if _grid == null:
		_grid = get_node_or_null("/root/GridService") as WarehouseGrid


func _bind_grid_obstacle() -> void:
	if _grid == null:
		return
	if _grid_obstacle == null:
		_grid_obstacle = WarehouseObstacle.new()
		_grid_obstacle.name = "GridObstacle"
		add_child(_grid_obstacle)
	_grid_obstacle.occupy(get_footprint_cells_at(_anchor_cell, rotation_degrees.y))


func _release_grid_obstacle() -> void:
	if _grid_obstacle:
		_grid_obstacle.release()


func _sync_click_area_layer() -> void:
	var area := get_node_or_null("ClickArea") as Area3D
	if area:
		area.collision_layer = CLICK_LAYER


func _build_workstation() -> void:
	var desk := _load_prop(DESK_MODEL, "Desk", DESK_SCALE)
	add_child(desk)
	var surface_y := _measure_local_mesh_top(desk)

	var props := Node3D.new()
	props.name = "Props"
	desk.add_child(props)

	var monitor := _load_prop(MONITOR_MODEL, "Monitor", PROP_SCALE)
	monitor.position = Vector3(0.0, surface_y, -0.18)
	props.add_child(monitor)

	var tower := _load_prop(COMPUTER_MODEL, "Computer", PROP_SCALE * 0.95)
	tower.position = Vector3(0.38, 0.02, 0.12)
	props.add_child(tower)

	var mouse := _load_prop(MOUSE_MODEL, "Mouse", PROP_SCALE * 0.85)
	mouse.position = Vector3(0.12, surface_y, -0.04)
	props.add_child(mouse)

	var lamp := _load_prop(DESK_LAMP_MODEL, "DeskLamp", PROP_SCALE)
	lamp.position = Vector3(-0.42, surface_y, 0.06)  # on the desk surface
	props.add_child(lamp)
	_build_desk_lamp_light(lamp)

	# Glowing screen quad on the monitor face
	var screen := MeshInstance3D.new()
	screen.name = "MonitorScreen"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.38, 0.24)
	screen.mesh = quad
	var screen_mat := StandardMaterial3D.new()
	screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_mat.albedo_color = Color(0.10, 0.55, 0.90)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.08, 0.40, 0.72)
	screen_mat.emission_energy_multiplier = 0.8
	screen.material_override = screen_mat
	screen.position = Vector3(0.0, surface_y + 0.18, -0.26)
	screen.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	props.add_child(screen)

	var chair := _load_prop(CHAIR_MODEL, "Chair", PROP_SCALE)
	chair.position = Vector3(0.0, 0.0, 0.62)
	chair.rotation_degrees.y = 180.0
	add_child(chair)


func _build_desk_lamp_light(lamp: Node3D) -> void:
	lamp.add_to_group("desk_lamps")
	var lamp_light := OmniLight3D.new()
	lamp_light.name = "LampLight"
	lamp_light.position = Vector3(0.0, DESK_LAMP_LIGHT_HEIGHT, 0.0)
	lamp_light.light_color = Color(1.0, 0.93, 0.78)
	lamp_light.omni_range = DESK_LAMP_RANGE
	lamp_light.omni_attenuation = 1.15
	lamp_light.shadow_enabled = false
	lamp_light.light_energy = 0.0
	lamp_light.visible = false
	lamp.add_child(lamp_light)


func _measure_local_mesh_top(root: Node3D) -> float:
	var mesh_instance := _find_mesh_instance(root)
	if mesh_instance == null or mesh_instance.mesh == null:
		return DESK_SURFACE_FALLBACK_Y
	var aabb := mesh_instance.mesh.get_aabb()
	return (aabb.position.y + aabb.size.y) * mesh_instance.scale.y


func _find_mesh_instance(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null


func _load_prop(path: String, node_name: String, scale_factor: float) -> Node3D:
	var scene: PackedScene = load(path)
	if scene == null:
		push_error("ComputerWorkstation: failed to load %s" % path)
		var fallback := Node3D.new()
		fallback.name = node_name
		return fallback
	var node: Node3D = scene.instantiate()
	node.name = node_name
	node.scale = Vector3.ONE * scale_factor
	return node


func _build_obstacle_collision() -> void:
	StaticCollision.add_box(self, OBSTACLE_SIZE, OBSTACLE_CENTER)


func _build_click_area() -> void:
	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = CLICK_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.85, 1.05, 1.55)
	shape.shape = box
	shape.position = Vector3(0.0, 0.5, 0.08)
	area.add_child(shape)
	add_child(area)
