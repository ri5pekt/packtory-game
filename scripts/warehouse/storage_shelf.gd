class_name StorageShelf
extends Node3D

## Holds sealed delivery boxes for later unpacking onto product shelves.

const SHELF_MODEL := "res://blender/assets/kenney_mini-market/Models/GLB format/shelf-end.glb"
const BOX_MODEL := "res://blender/assets/kenney_car-kit/Models/GLB format/box.glb"
const CLICK_LAYER := 1
const LEVEL_Y := [0.175, 0.55]
const PRODUCT_Z := -0.08
const APPROACH_Z := 0.85
const FACE_Z := 0.15
const COLS_PER_LEVEL := 3
const SHELF_ROWS := 2
const COL_SPACING := 0.24
const MAX_BOX_SLOTS := 6
const BOX_SCALE := 0.42

var _stored_boxes: Array = []
var _next_box_id := 1

var _boxes_root: Node3D
var _label: ProductLabel3D
var _grid: WarehouseGrid
var _anchor_cell := Vector2i.ZERO
var _grid_obstacle: WarehouseObstacle


func _ready() -> void:
	add_to_group("storage_shelves")
	add_to_group("warehouse_placeables")


func setup(world_position: Vector3, yaw_deg: float) -> void:
	_ensure_grid()
	_anchor_cell = _grid.world_to_cell(world_position) if _grid else Vector2i.ZERO
	position = world_position
	rotation_degrees.y = yaw_deg
	if get_child_count() == 0:
		_build_shelf()
		_build_click_area()
		_build_label()
		_boxes_root = Node3D.new()
		_boxes_root.name = "StoredBoxes"
		add_child(_boxes_root)
	else:
		_sync_click_area_layer()
	_refresh()
	_bind_grid_obstacle()


func get_anchor_cell() -> Vector2i:
	return _anchor_cell


func get_placement_yaw() -> float:
	return rotation_degrees.y


func get_placeable_label() -> String:
	return "Storage Shelf"


func get_footprint_cells_at(anchor_cell: Vector2i, _yaw_deg: float) -> Array[Vector2i]:
	return [anchor_cell]


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


func get_stored_boxes() -> Array:
	return _stored_boxes.duplicate(true)


func get_box_count() -> int:
	return _stored_boxes.size()


func free_slots() -> int:
	return MAX_BOX_SLOTS - _stored_boxes.size()


func can_store_box() -> bool:
	return free_slots() > 0


func can_withdraw_box() -> bool:
	return not _stored_boxes.is_empty()


func find_box_index(box_id: int) -> int:
	for i in range(_stored_boxes.size()):
		if int(_stored_boxes[i].get("id", -1)) == box_id:
			return i
	return -1


func store_box(product_id: String, count: int) -> bool:
	if not can_store_box() or product_id == "" or count <= 0:
		return false
	_stored_boxes.append({
		"id": _next_box_id,
		"product_id": product_id,
		"count": count,
	})
	_next_box_id += 1
	_refresh()
	return true


func withdraw_box(box_id: int) -> Dictionary:
	var index := find_box_index(box_id)
	if index < 0:
		return {}
	var box: Dictionary = _stored_boxes[index].duplicate()
	_stored_boxes.remove_at(index)
	_refresh()
	return box


func export_boxes_state() -> Array:
	return _stored_boxes.duplicate(true)


func get_next_box_id() -> int:
	return _next_box_id


func apply_boxes_state(boxes: Array, next_id: int = 1) -> void:
	_stored_boxes.clear()
	_next_box_id = maxi(1, next_id)
	for entry in boxes:
		if entry is Dictionary:
			_stored_boxes.append(entry.duplicate())
			_next_box_id = maxi(_next_box_id, int(entry.get("id", 0)) + 1)
	_refresh()


func get_approach_position() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.0, APPROACH_Z)


func get_face_target() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.45, FACE_Z)


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
	_label.position = Vector3(0.0, 1.12, 0.0)
	add_child(_label)


func _refresh() -> void:
	_update_label()
	_rebuild_boxes()


func _update_label() -> void:
	if _stored_boxes.is_empty():
		_label.set_empty("Storage")
	else:
		_label.set_empty("%d box(es)" % _stored_boxes.size())


func _rebuild_boxes() -> void:
	if _boxes_root == null:
		return
	for child in _boxes_root.get_children():
		child.queue_free()
	for i in range(_stored_boxes.size()):
		var box_data: Dictionary = _stored_boxes[i]
		var product_id := String(box_data.get("product_id", ""))
		var count := int(box_data.get("count", 0))
		var level := i / COLS_PER_LEVEL
		var col := i % COLS_PER_LEVEL
		var item := _make_sealed_box(product_id, count)
		item.position = Vector3(
			(float(col) - float(COLS_PER_LEVEL - 1) * 0.5) * COL_SPACING,
			LEVEL_Y[mini(level, SHELF_ROWS - 1)] + 0.12,
			PRODUCT_Z
		)
		_boxes_root.add_child(item)


func _make_sealed_box(product_id: String, count: int) -> Node3D:
	var root := Node3D.new()
	var scene: PackedScene = load(BOX_MODEL)
	if scene != null:
		var mesh: Node3D = scene.instantiate()
		mesh.scale = Vector3.ONE * BOX_SCALE
		root.add_child(mesh)
	var icon_tex := IconRegistry.product_icon(product_id)
	if icon_tex:
		var sprite := Sprite3D.new()
		sprite.texture = icon_tex
		sprite.pixel_size = 0.0012
		sprite.position = Vector3(0.0, 0.12, 0.12)
		root.add_child(sprite)
	var qty := Label3D.new()
	qty.text = "×%d" % count
	qty.font_size = 28
	qty.position = Vector3(0.0, 0.22, 0.0)
	root.add_child(qty)
	return root
