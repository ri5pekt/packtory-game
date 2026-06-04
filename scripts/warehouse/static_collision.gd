class_name StaticCollision
extends RefCounted

## Physics layer for walls, shelves, and other static obstacles.
const OBSTACLE_LAYER := 2


static func add_box(
	parent: Node3D,
	size: Vector3,
	center: Vector3 = Vector3.ZERO,
	rotation_y_deg: float = 0.0
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = OBSTACLE_LAYER
	body.collision_mask = 0
	body.position = center
	body.rotation_degrees.y = rotation_y_deg

	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)
	parent.add_child(body)
	return body


static func add_mesh_aabb(parent: Node3D, mesh: Mesh, transform: Transform3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = OBSTACLE_LAYER
	body.collision_mask = 0
	body.transform = transform

	var aabb := mesh.get_aabb()
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size
	shape_node.position = aabb.get_center()
	shape_node.shape = box
	body.add_child(shape_node)
	parent.add_child(body)
	return body
