class_name ReceptionTable
extends Node3D

## Reception counter where the customer queue starts. Queue slots follow child
## markers on this node — moving the desk in edit mode moves the line automatically.

const MODEL := (
	"res://blender/assets/kenney_mini-market/Models/GLB format/cash-register.glb"
)

const MODEL_SCALE := 1.05
const SLOT_SPACING := 0.78
const MAX_QUEUE := 6
const EXIT_LANE_OFFSET := 1.0
const CLICK_LAYER := 1
const QUEUE_LANE_TOLERANCE := 0.38

var _queue_start: Marker3D
var _queue_entry: Marker3D
var _grid: WarehouseGrid
var _anchor_cell := Vector2i.ZERO
var _body_obstacle: WarehouseObstacle
var _built := false
var _resolved_slots: Array[Vector3] = []
var _slots_resolved := false


func _ready() -> void:
	add_to_group("reception_tables")
	add_to_group("warehouse_placeables")


func setup(world_position: Vector3, yaw_deg: float) -> void:
	_ensure_grid()
	_anchor_cell = _grid.world_to_cell(world_position) if _grid else Vector2i.ZERO
	if not _built:
		_build_mesh()
		_build_markers()
		_build_obstacle()
		_build_click_area()
		_built = true
	apply_placement(_anchor_cell, yaw_deg)


func use_grid(grid: WarehouseGrid) -> void:
	_grid = grid


func get_anchor_cell() -> Vector2i:
	return _anchor_cell


func get_placement_yaw() -> float:
	return rotation_degrees.y


func get_placeable_label() -> String:
	return "Reception Table"


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
	_release_body_obstacle()
	_anchor_cell = anchor_cell
	position = _grid.cell_to_world(anchor_cell)
	rotation_degrees.y = yaw_deg
	_bind_body_obstacle()
	_invalidate_slots()
	_bind_navigation_refresh()
	QueueAreaLayout.bind(self)


func release_placement_cells() -> void:
	_release_body_obstacle()


func _bind_body_obstacle() -> void:
	if _body_obstacle == null:
		_body_obstacle = WarehouseObstacle.new()
		_body_obstacle.name = "BodyGridObstacle"
		add_child(_body_obstacle)
	_body_obstacle.occupy([_anchor_cell])


func _release_body_obstacle() -> void:
	if _body_obstacle:
		_body_obstacle.release()


func get_queue_start_world() -> Vector3:
	return _marker_world(_queue_start)


func get_queue_entry_world() -> Vector3:
	return _marker_world(_queue_entry)


func get_line_direction() -> Vector3:
	var delta := get_queue_entry_world() - get_queue_start_world()
	delta.y = 0.0
	if delta.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	return delta.normalized()


func get_customer_face_direction() -> Vector3:
	return -get_line_direction()


func get_slot(index: int) -> Vector3:
	_ensure_resolved_slots()
	if _resolved_slots.is_empty():
		return get_queue_start_world()
	return _resolved_slots[clampi(index, 0, _resolved_slots.size() - 1)]


func get_exit_lane_x() -> float:
	return get_queue_start_world().x + EXIT_LANE_OFFSET


func is_queue_lane_at(world: Vector3) -> bool:
	_ensure_resolved_slots()
	var flat := Vector2(world.x, world.z)
	for slot in _resolved_slots:
		if flat.distance_to(Vector2(slot.x, slot.z)) <= QUEUE_LANE_TOLERANCE:
			return true
	for i in range(_resolved_slots.size() - 1):
		var a := _resolved_slots[i]
		var b := _resolved_slots[i + 1]
		if _distance_to_segment(flat, Vector2(a.x, a.z), Vector2(b.x, b.z)) <= QUEUE_LANE_TOLERANCE:
			return true
	return false


func _build_mesh() -> void:
	var scene: PackedScene = load(MODEL)
	if scene == null:
		push_error("ReceptionTable: failed to load %s" % MODEL)
		return
	var mesh: Node3D = scene.instantiate()
	mesh.name = "Mesh"
	mesh.scale = Vector3.ONE * MODEL_SCALE
	add_child(mesh)


func _build_markers() -> void:
	_queue_start = Marker3D.new()
	_queue_start.name = "QueueStartPoint"
	_queue_start.position = Vector3(0.0, 0.0, 1.05)
	add_child(_queue_start)

	_queue_entry = Marker3D.new()
	_queue_entry.name = "QueueEntryPoint"
	_queue_entry.position = Vector3(0.0, 0.0, 5.5)
	add_child(_queue_entry)


func _build_obstacle() -> void:
	StaticCollision.add_box(self, Vector3(0.95, 0.95, 0.55), Vector3(0.0, 0.48, 0.0))


func _build_click_area() -> void:
	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = CLICK_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.05, 1.0, 0.75)
	shape.shape = box
	shape.position = Vector3(0.0, 0.5, 0.0)
	area.add_child(shape)
	add_child(area)


func _ensure_grid() -> void:
	if _grid != null:
		return
	if is_inside_tree():
		_grid = get_tree().root.get_node_or_null("GridService") as WarehouseGrid
	if _grid == null:
		_grid = get_node_or_null("/root/GridService") as WarehouseGrid


func _marker_world(marker: Marker3D) -> Vector3:
	if marker == null:
		if is_inside_tree():
			return global_position
		return position
	if is_inside_tree():
		return to_global(marker.position)
	return position + transform.basis * marker.position


func _invalidate_slots() -> void:
	_slots_resolved = false
	_resolved_slots.clear()


func _ensure_resolved_slots() -> void:
	if _slots_resolved:
		return
	_resolved_slots = _compute_resolved_slots()
	_slots_resolved = true


func _compute_resolved_slots() -> Array[Vector3]:
	var slots: Array[Vector3] = []
	var start := get_queue_start_world()
	var primary := get_line_direction()
	var lateral := Vector3(-primary.z, 0.0, primary.x)
	var pf := _pathfinding()
	var open_side := _open_lateral_side(start, lateral, pf)

	for i in range(MAX_QUEUE):
		var ideal := start + primary * SLOT_SPACING * float(i)
		var pos := ideal
		# Keep the line straight beside the counter; only bend when a wall blocks the slot cell.
		if i > 0 and pf != null and _ideal_slot_blocked_by_wall(ideal, pf):
			pos = _fallback_slot(slots[i - 1], primary, lateral, open_side, slots, pf)
		slots.append(_snap_to_surface(pos))
	return slots


func _ideal_slot_blocked_by_wall(world: Vector3, pf: Pathfinding) -> bool:
	if _grid == null:
		return not pf.is_world_walkable(world)
	var cell := _grid.world_to_cell(world)
	if not _grid.is_warehouse_cell(cell):
		return true
	return not pf.is_walkable(cell)


func _fallback_slot(
	current: Vector3,
	primary: Vector3,
	lateral: Vector3,
	open_side: int,
	existing: Array[Vector3],
	pf: Pathfinding
) -> Vector3:
	var side := open_side if open_side != 0 else 1
	var candidates: Array[Vector3] = [
		current + lateral * float(side) * SLOT_SPACING,
		current - lateral * float(side) * SLOT_SPACING,
		current + (primary + lateral * float(side)).normalized() * SLOT_SPACING,
		current + primary * SLOT_SPACING * 0.65,
	]
	var best := current + primary * SLOT_SPACING
	var best_sep := -1.0
	for candidate in candidates:
		if pf != null and _ideal_slot_blocked_by_wall(candidate, pf):
			continue
		var sep := _min_separation(candidate, existing)
		if sep > best_sep:
			best_sep = sep
			best = candidate
	return best


func _min_separation(pos: Vector3, slots: Array[Vector3]) -> float:
	var min_dist := INF
	for slot in slots:
		min_dist = minf(
			min_dist,
			Vector2(pos.x, pos.z).distance_to(Vector2(slot.x, slot.z))
		)
	return min_dist


func _open_lateral_side(from: Vector3, lateral: Vector3, pf: Pathfinding) -> int:
	if pf == null:
		return 1
	var left_open := not _ideal_slot_blocked_by_wall(from + lateral * 0.55, pf)
	var right_open := not _ideal_slot_blocked_by_wall(from - lateral * 0.55, pf)
	if left_open and not right_open:
		return 1
	if right_open and not left_open:
		return -1
	return 1 if left_open else 0


func _snap_to_surface(world: Vector3) -> Vector3:
	if _grid == null:
		return world
	var cell := _grid.world_to_cell(world)
	return Vector3(world.x, _grid.walk_surface_y(cell), world.z)


func _pathfinding() -> Pathfinding:
	_ensure_grid()
	if _grid == null:
		return null
	return _grid.pathfinding


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _bind_navigation_refresh() -> void:
	_ensure_grid()
	if _grid == null:
		return
	if not _grid.navigation_changed.is_connected(_on_navigation_changed):
		_grid.navigation_changed.connect(_on_navigation_changed)


func _on_navigation_changed() -> void:
	_invalidate_slots()
	if not is_inside_tree():
		return
	var queue := get_tree().get_first_node_in_group("customer_queue")
	if queue and queue.has_method("refresh_queue_layout"):
		queue.refresh_queue_layout()
