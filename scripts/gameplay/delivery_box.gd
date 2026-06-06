class_name DeliveryBox
extends Node3D

## A labelled crate of product dropped at the loading dock. Picking it up adds one
## boxed inventory entry; contents unpack onto a shelf when stocked there.

signal emptied(box: DeliveryBox)

const BOX_MODEL := "res://blender/assets/kenney_car-kit/Models/GLB format/box.glb"
const CLICK_LAYER := 1
const BOX_SCALE := 0.55
## Sealed product crates always hold this many units (opening stock and reorders).
const UNITS_PER_BOX := 6

var product_id: String
var count: int = 0
var reorder_order_id: int = 0

var _label: ProductLabel3D
var _label_offset := Vector3.ZERO


func setup(
	id: String,
	qty: int,
	world_position: Vector3,
	yaw_deg: float,
	label_offset: Vector3 = Vector3.ZERO,
	order_id: int = 0
) -> void:
	product_id = id
	count = qty
	reorder_order_id = order_id
	position = world_position
	rotation_degrees.y = yaw_deg
	_label_offset = label_offset
	add_to_group("delivery_boxes")

	_build_mesh()
	_build_click_area()
	_build_label()


func get_approach_position() -> Vector3:
	# Approach from the south so the worker comes from the warehouse entrance,
	# not from the van's parking spot on the west side of the dock.
	return global_position + Vector3(0.0, 0.0, 1.2)


func get_face_target() -> Vector3:
	return global_position + Vector3(0.0, 0.4, 0.0)


## Carry the sealed box in `worker` inventory (one slot). Frees the world box on success.
func pickup_into(worker: Worker) -> bool:
	if count <= 0:
		return false
	if worker.add_delivery_box(product_id, count):
		if reorder_order_id > 0:
			var manager := get_node_or_null("/root/IncomingDeliveryManager")
			if manager != null and manager.has_method("complete_order"):
				manager.complete_order(reorder_order_id)
		emptied.emit(self)
		queue_free()
		return true
	return false


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
	_label.position = Vector3(0.0, 0.58, 0.0) + _label_offset
	add_child(_label)
	_update_label()


func _update_label() -> void:
	if _label:
		_label.set_product(product_id, count)
