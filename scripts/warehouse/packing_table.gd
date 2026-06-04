class_name PackingTable
extends Node3D

## Interactive packing desk. The worker packs the active order here when they are
## carrying every required product.

const HP := "res://blender/assets/Household Props 001-glb/"
const TABLE_MODEL := HP + "Table.glb"
const CLICK_LAYER := 1
const TABLE_SCALE := 1.15
const APPROACH_Z := 0.85
const FACE_Z := 0.35
# Sized to match the scaled Table.glb footprint (blocks pathfinding + visual clip).
const OBSTACLE_SIZE := Vector3(1.25, 0.88, 1.08)
const OBSTACLE_CENTER := Vector3(0.0, 0.44, 0.0)
# Extra grid cells covered by the table width (anchor cell is always included).
const FOOTPRINT_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(0, 0),
	Vector2i(1, 0),
]


func setup(world_position: Vector3, yaw_deg: float) -> void:
	position = world_position
	rotation_degrees.y = yaw_deg
	_build_mesh()
	_build_obstacle_collision()
	_build_click_area()


func get_footprint_cells(anchor_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in FOOTPRINT_OFFSETS:
		cells.append(anchor_cell + offset)
	return cells


func get_approach_position() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.0, APPROACH_Z)


func get_face_target() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.75, FACE_Z)


func _build_mesh() -> void:
	var scene: PackedScene = load(TABLE_MODEL)
	if scene == null:
		push_error("PackingTable: failed to load %s" % TABLE_MODEL)
		return
	var table: Node3D = scene.instantiate()
	table.name = "Mesh"
	table.scale = Vector3.ONE * TABLE_SCALE
	add_child(table)


func _build_obstacle_collision() -> void:
	StaticCollision.add_box(self, OBSTACLE_SIZE, OBSTACLE_CENTER)


func _build_click_area() -> void:
	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = CLICK_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.9, 1.0)
	shape.shape = box
	shape.position = Vector3(0.0, 0.45, 0.0)
	area.add_child(shape)
	add_child(area)
