class_name PackingTable
extends Node3D

const WarehousePlaceableScript = preload("res://scripts/warehouse/warehouse_placeable.gd")

## Interactive packing desk. The worker packs the active order here when they are
## carrying every required product.

const HP := "res://blender/assets/Household Props 001-glb/"
const TABLE_MODEL := HP + "Table.glb"
const PACKAGE_BOX_MODEL := (
	"res://blender/assets/kenney_car-kit/Models/GLB format/box.glb"
)
const CLICK_LAYER := 1
const TABLE_SCALE := 1.15
const PACKAGE_BOX_SCALE := 0.44
const TABLE_SURFACE_FALLBACK_Y := 0.72
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

var _grid: WarehouseGrid
var _anchor_cell := Vector2i.ZERO
var _grid_obstacle: WarehouseObstacle
var _table_mesh: Node3D
var _packing_box: Node3D
var _packing_visual_active := false


func setup(world_position: Vector3, yaw_deg: float) -> void:
	_ensure_grid()
	_anchor_cell = _grid.world_to_cell(world_position) if _grid else Vector2i.ZERO
	position = world_position
	rotation_degrees.y = yaw_deg
	if get_child_count() == 0:
		_build_mesh()
		_build_obstacle_collision()
		_build_click_area()
	else:
		_sync_click_area_layer()
	add_to_group("warehouse_placeables")
	_bind_grid_obstacle()


func get_anchor_cell() -> Vector2i:
	return _anchor_cell


func get_placement_yaw() -> float:
	return rotation_degrees.y


func get_placeable_label() -> String:
	return "Packing Table"


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


func get_footprint_cells(anchor_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in FOOTPRINT_OFFSETS:
		cells.append(anchor_cell + offset)
	return cells


func get_approach_position() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.0, APPROACH_Z)


func get_face_target() -> Vector3:
	return global_position + global_transform.basis * Vector3(0.0, 0.75, FACE_Z)


func begin_packing_visual() -> void:
	_ensure_packing_box()
	if _packing_box == null:
		return
	_packing_visual_active = true
	_packing_box.visible = true
	update_packing_visual(0.0)


func update_packing_visual(progress: float) -> void:
	if not _packing_visual_active or _packing_box == null:
		return
	var t := clampf(progress, 0.0, 1.0)
	var scale_factor := lerpf(0.35, 1.0, t)
	_apply_packing_box_transform(scale_factor)


func end_packing_visual() -> void:
	_packing_visual_active = false
	if _packing_box != null:
		_packing_box.visible = false


func _build_mesh() -> void:
	var scene: PackedScene = load(TABLE_MODEL)
	if scene == null:
		push_error("PackingTable: failed to load %s" % TABLE_MODEL)
		return
	var table: Node3D = scene.instantiate()
	table.name = "Mesh"
	table.scale = Vector3.ONE * TABLE_SCALE
	add_child(table)
	_table_mesh = table


func _ensure_packing_box() -> void:
	if _packing_box != null:
		return
	var scene: PackedScene = load(PACKAGE_BOX_MODEL)
	if scene == null:
		push_warning("PackingTable: failed to load %s" % PACKAGE_BOX_MODEL)
		return
	_packing_box = scene.instantiate()
	_packing_box.name = "PackingBoxVisual"
	_packing_box.visible = false
	add_child(_packing_box)
	_apply_packing_box_transform(0.35)


func _apply_packing_box_transform(scale_factor: float) -> void:
	if _packing_box == null:
		return
	var combined_scale := PACKAGE_BOX_SCALE * scale_factor
	var surface_y := _measure_table_surface_y()
	var box_height := _measure_mesh_height(_packing_box) * combined_scale
	_packing_box.scale = Vector3.ONE * combined_scale
	_packing_box.position = Vector3(0.0, surface_y + box_height * 0.5, 0.06)


func _measure_table_surface_y() -> float:
	if _table_mesh == null:
		_table_mesh = get_node_or_null("Mesh") as Node3D
	if _table_mesh == null:
		return TABLE_SURFACE_FALLBACK_Y
	return _measure_local_mesh_top(_table_mesh)


func _measure_local_mesh_top(root: Node3D) -> float:
	var mesh_instance := _find_mesh_instance(root)
	if mesh_instance == null or mesh_instance.mesh == null:
		return TABLE_SURFACE_FALLBACK_Y
	var aabb := mesh_instance.mesh.get_aabb()
	return (aabb.position.y + aabb.size.y) * mesh_instance.scale.y


func _measure_mesh_height(root: Node3D) -> float:
	var mesh_instance := _find_mesh_instance(root)
	if mesh_instance == null or mesh_instance.mesh == null:
		return 0.4
	var aabb := mesh_instance.mesh.get_aabb()
	return aabb.size.y * mesh_instance.scale.y


func _find_mesh_instance(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null


func _build_obstacle_collision() -> void:
	StaticCollision.add_box(self, OBSTACLE_SIZE, OBSTACLE_CENTER)


func _build_click_area() -> void:
	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = CLICK_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.65, 1.0, 1.35)
	shape.shape = box
	shape.position = Vector3(0.0, 0.48, 0.0)
	area.add_child(shape)
	add_child(area)
