class_name ProductShelf
extends Node3D

## An interactive shelf that accepts any product type. When empty, any product
## can be stocked on it. Products are displayed as labelled cardboard boxes
## sized and textured per the product catalog. Becomes unassigned when emptied.

const SHELF_MODEL := "res://blender/assets/kenney_mini-market/Models/GLB format/shelf-end.glb"
const CLICK_LAYER := 1
const MAX_STOCK := 10

const LEVEL_Y := [0.175, 0.55]
const PRODUCT_Z := -0.08
const APPROACH_Z := 0.85
const FACE_Z := 0.15
# Per-level columns and spacing (derived from box width + padding).
const COLS_PER_LEVEL := 3
const COL_SPACING := 0.24

## Empty string means the shelf is unassigned and accepts any product.
var product_id: String = ""
var count: int = 0

var _products_root: Node3D
var _label: ProductLabel3D


func setup(world_position: Vector3, yaw_deg: float) -> void:
	position = world_position
	rotation_degrees.y = yaw_deg
	_build_shelf()
	_build_click_area()
	_build_label()
	_products_root = Node3D.new()
	_products_root.name = "Products"
	add_child(_products_root)
	_refresh()


## Legacy entry point used by spawners that pre-assign a product and start count.
func setup_with_product(id: String, world_position: Vector3, yaw_deg: float,
		start_count: int = 0) -> void:
	setup(world_position, yaw_deg)
	if id != "" and start_count > 0:
		stock_product(id, start_count)


func is_empty_shelf() -> bool:
	return product_id == ""


func can_take() -> bool:
	return count > 0


func can_return() -> bool:
	return count < MAX_STOCK


func can_receive(id: String) -> bool:
	return (product_id == "" or product_id == id) and not ProductCatalog.is_package(id) and count < MAX_STOCK


func take_one() -> bool:
	if not can_take():
		return false
	count -= 1
	if count == 0:
		product_id = ""
	_refresh()
	return true


func add_one() -> bool:
	if not can_return():
		return false
	count += 1
	_refresh()
	return true


## Stock `amount` units of `id` onto this shelf. Returns how many were actually added.
func stock_product(id: String, amount: int) -> int:
	if not can_receive(id):
		return 0
	if product_id == "":
		product_id = id
	var moved := mini(maxi(amount, 0), MAX_STOCK - count)
	count += moved
	if moved > 0:
		_refresh()
	return moved


func take(amount: int) -> int:
	var moved := mini(maxi(amount, 0), count)
	count -= moved
	if count == 0:
		product_id = ""
	if moved > 0:
		_refresh()
	return moved


func add(amount: int) -> int:
	var moved := mini(maxi(amount, 0), MAX_STOCK - count)
	count += moved
	if moved > 0:
		_refresh()
	return moved


func free_space() -> int:
	return MAX_STOCK - count


func get_approach_position() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.0, APPROACH_Z)


func get_face_target() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.45, FACE_Z)


# ── build ─────────────────────────────────────────────────────────────────────

func _build_shelf() -> void:
	var shelf: Node3D = (load(SHELF_MODEL) as PackedScene).instantiate()
	shelf.name = "Mesh"
	_strip_baked_products(shelf)
	add_child(shelf)


func _strip_baked_products(root: Node) -> void:
	var frame := _first_mesh(root)
	if frame == null:
		return
	for child in frame.get_children():
		if child is MeshInstance3D:
			child.queue_free()
		else:
			_strip_baked_products(child)


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh(child)
		if found:
			return found
	return null


func _build_click_area() -> void:
	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = CLICK_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.9, 0.55)
	shape.shape = box
	shape.position = Vector3(0.0, 0.45, 0.0)
	area.add_child(shape)
	add_child(area)


func _build_label() -> void:
	_label = ProductLabel3D.new()
	_label.name = "ShelfLabel"
	_label.position = Vector3(0.0, 1.05, 0.0)
	add_child(_label)


# ── refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_update_label()
	_rebuild_products()


func _update_label() -> void:
	if product_id == "":
		_label.set_empty("Empty")
	else:
		_label.set_product(product_id, count, "/%d" % MAX_STOCK)


func _rebuild_products() -> void:
	for child in _products_root.get_children():
		child.queue_free()

	if product_id == "" or count == 0:
		return

	var capacity := COLS_PER_LEVEL * LEVEL_Y.size()
	var visible := mini(count, capacity)
	var box_sz := ProductCatalog.box_size_of(product_id)

	for i in range(visible):
		var level := i / COLS_PER_LEVEL
		var col := i % COLS_PER_LEVEL
		var item := _make_product_box(product_id, box_sz)
		item.position = Vector3(
			(float(col) - float(COLS_PER_LEVEL - 1) * 0.5) * COL_SPACING,
			LEVEL_Y[level] + box_sz.y * 0.5,
			PRODUCT_Z
		)
		_products_root.add_child(item)


## Build a cardboard-box MeshInstance3D sized to the product with its icon on the front.
func _make_product_box(id: String, sz: Vector3) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = sz
	mesh_inst.mesh = box_mesh

	# Base material: product color tinted toward cardboard.
	var mat := StandardMaterial3D.new()
	var base_color := ProductCatalog.color_of(id).lerp(Color(0.92, 0.84, 0.70), 0.55)
	mat.albedo_color = base_color
	mat.roughness = 0.85
	mesh_inst.material_override = mat

	# Front-face icon as a Sprite3D sitting just in front of the box.
	var icon_tex := IconRegistry.product_icon(id)
	if icon_tex:
		var sprite := Sprite3D.new()
		sprite.texture = icon_tex
		sprite.pixel_size = 0.00115
		sprite.no_depth_test = false
		sprite.position = Vector3(0.0, 0.0, sz.z * 0.5 + 0.002)
		mesh_inst.add_child(sprite)

	return mesh_inst
