class_name EquipmentDeliveryMarker
extends Node3D

## Dock crate for an incoming equipment order (shelves, future upgrades).

const BOX_MODEL := "res://blender/assets/kenney_car-kit/Models/GLB format/box.glb"
const CLICK_LAYER := 1
const BOX_SCALE := 0.55

var order_id: int = 0
var item_id: String = ""
var delivery_label: String = ""

var _label: ProductLabel3D


func setup(delivery: Dictionary, world_position: Vector3, yaw_deg: float) -> void:
	order_id = int(delivery.get("order_id", 0))
	item_id = String(delivery.get("item_id", ""))
	delivery_label = String(delivery.get("label", "Equipment"))
	position = world_position
	rotation_degrees.y = yaw_deg
	add_to_group("incoming_equipment_deliveries")
	_build_mesh()
	_build_click_area()
	_build_label()


func get_approach_position() -> Vector3:
	return global_position + Vector3(-1.0, 0.0, 0.0)


func get_face_target() -> Vector3:
	return global_position + Vector3(0.0, 0.4, 0.0)


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
	_label.name = "Label"
	_label.text = "%s\ndelivery" % delivery_label
	add_child(_label)
	_label.position = Vector3(0.0, 0.62, 0.0)
