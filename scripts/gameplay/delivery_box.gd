class_name DeliveryBox
extends Node3D

## A labelled crate of product dropped at the loading dock. Clicking it walks the
## manager over; on arrival its contents are poured straight into the inventory as
## a product stack (the box itself is not carried). Emptied boxes free themselves.

signal emptied(box: DeliveryBox)

const BOX_MODEL := "res://blender/assets/kenney_car-kit/Models/GLB format/box.glb"
const CLICK_LAYER := 1
const BOX_SCALE := 0.55

var product_id: String
var count: int = 0

var _label: ProductLabel3D


func setup(id: String, qty: int, world_position: Vector3, yaw_deg: float) -> void:
	product_id = id
	count = qty
	position = world_position
	rotation_degrees.y = yaw_deg
	add_to_group("delivery_boxes")

	_build_mesh()
	_build_click_area()
	_build_label()


func get_approach_position() -> Vector3:
	# Approach from the west (the back-door side).
	return global_position + Vector3(-1.0, 0.0, 0.0)


func get_face_target() -> Vector3:
	return global_position + Vector3(0.0, 0.4, 0.0)


## Move as many units as fit into `worker`; free the box if it empties.
func unload_into(worker: Worker) -> int:
	var moved := worker.add_products(product_id, count)
	if moved > 0:
		count -= moved
		_update_label()
	if count <= 0:
		emptied.emit(self)
		queue_free()
	return moved


func _build_mesh() -> void:
	var scene: PackedScene = load(BOX_MODEL)
	if scene == null:
		return
	var mesh: Node3D = scene.instantiate()
	mesh.name = "Mesh"
	mesh.scale = Vector3.ONE * BOX_SCALE
	add_child(mesh)


func _build_click_area() -> void:
	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = CLICK_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.45, 0.45)
	shape.shape = box
	shape.position = Vector3(0.0, 0.22, 0.0)
	area.add_child(shape)
	add_child(area)


func _build_label() -> void:
	_label = ProductLabel3D.new()
	_label.name = "BoxLabel"
	_label.position = Vector3(0.0, 0.66, 0.0)
	add_child(_label)
	_update_label()


func _update_label() -> void:
	if _label:
		_label.set_product(product_id, count)
