class_name InteractableRaycast
extends RefCounted

## Screen-to-world raycasts for gameplay taps (interactables + warehouse floor).

const MAX_RAY_HITS := 16


static func pick_interactable(
	camera: Camera3D,
	screen_position: Vector2,
	collision_mask: int
) -> Node:
	var hits := _collect_interactable_hits(camera, screen_position, collision_mask)
	if hits.is_empty():
		return null
	return _select_best_hit(hits)


static func interactable_priority(node: Node) -> int:
	if node is Worker or node is Customer:
		return 100
	if node is DeliveryBox:
		return 90
	if node is Node3D and node.is_in_group("equipment_delivery_boxes"):
		return 90
	if node is ProductShelf or node is StorageShelf or node is PackingTable:
		return 80
	if node is Node3D and node.is_in_group("computer_workstations"):
		return 80
	if node is Node3D and node.is_in_group("floor_garbage"):
		return 70
	# Large click volume — prefer dock boxes that sit visually behind the van.
	if node is Node3D and node.is_in_group("outbound_delivery_vehicles"):
		return 50
	return 0


static func resolve_interactable(node: Node) -> Node:
	var current := node
	while current:
		if (
			current is Worker
			or current is ProductShelf
			or current is StorageShelf
			or current is Customer
			or current is PackingTable
			or (current is Node3D and current.is_in_group("computer_workstations"))
			or current is DeliveryBox
			or (current is Node3D and current.is_in_group("floor_garbage"))
			or (current is Node3D and current.is_in_group("equipment_delivery_boxes"))
			or (current is Node3D and current.is_in_group("outbound_delivery_vehicles"))
		):
			return current
		current = current.get_parent()
	return null


static func pick_warehouse_floor(
	camera: Camera3D,
	grid: WarehouseGrid,
	screen_position: Vector2
) -> Vector3:
	if camera == null or grid == null:
		return Vector3.INF
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return Vector3.INF

	var plane_y := WarehouseGrid.WAREHOUSE_FLOOR_SURFACE_Y
	var t := (plane_y - origin.y) / direction.y
	if t <= 0.0:
		return Vector3.INF

	var hit := origin + direction * t
	var cell := grid.world_to_cell(hit)
	if not grid.is_warehouse_cell(cell):
		return Vector3.INF

	return Vector3(hit.x, grid.walk_surface_y(cell), hit.z)


## Screen ray onto the lot ground plane (y = 0); returns invalid cell if off-map.
static func pick_lot_cell(
	camera: Camera3D,
	grid: WarehouseGrid,
	screen_position: Vector2
) -> Vector2i:
	const INVALID := Vector2i(-9999, -9999)
	if camera == null or grid == null:
		return INVALID
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return INVALID
	var t := -origin.y / direction.y
	if t <= 0.0:
		return INVALID
	var hit := origin + direction * t
	var cell := grid.world_to_cell(hit)
	if not grid.is_in_bounds(cell):
		return INVALID
	return cell


static func _collect_interactable_hits(
	camera: Camera3D,
	screen_position: Vector2,
	collision_mask: int
) -> Array:
	if camera == null:
		return []
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var space := camera.get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var exclude: Array[RID] = []
	var hits: Array = []
	for _i in range(MAX_RAY_HITS):
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			break
		var collider: Object = hit.get("collider")
		if collider is CollisionObject3D:
			exclude.append((collider as CollisionObject3D).get_rid())
		var interactable := resolve_interactable(collider as Node)
		if interactable != null:
			var distance := origin.distance_to(hit.get("position", origin))
			hits.append({
				"node": interactable,
				"distance": distance,
				"priority": interactable_priority(interactable),
			})
	return hits


static func _select_best_hit(hits: Array) -> Node:
	var best: Dictionary = hits[0]
	for i in range(1, hits.size()):
		var candidate: Dictionary = hits[i]
		if int(candidate.get("priority", 0)) > int(best.get("priority", 0)):
			best = candidate
		elif (
			int(candidate.get("priority", 0)) == int(best.get("priority", 0))
			and float(candidate.get("distance", 0.0)) < float(best.get("distance", 0.0))
		):
			best = candidate
	return best.get("node") as Node
