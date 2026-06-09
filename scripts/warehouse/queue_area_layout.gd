class_name QueueAreaLayout
extends RefCounted

## Resolves customer queue geometry from the scene's ReceptionTable anchor.
## Falls back to legacy constants only if no reception table is bound yet.

const FLOOR_Y := WarehouseGrid.WAREHOUSE_FLOOR_SURFACE_Y
const LEGACY_QUEUE_X := 16.5
const LEGACY_QUEUE_FRONT_Z := 16.5
const QUEUE_SLOT_SPACING := 0.78
const MAX_QUEUE := 6
const LEGACY_ENTRY_Z := 21.0
const LEGACY_EXIT_LANE_X := 17.5

static var _reception: Node3D = null


static func bind(reception: Node3D) -> void:
	_reception = reception


static func get_reception() -> Node3D:
	return _reception


static func get_slot(index: int) -> Vector3:
	if _reception != null and is_instance_valid(_reception):
		return _reception.get_slot(index)
	return Vector3(
		LEGACY_QUEUE_X,
		FLOOR_Y,
		LEGACY_QUEUE_FRONT_Z + float(index) * QUEUE_SLOT_SPACING
	)


static func get_entry_point() -> Vector3:
	if _reception != null and is_instance_valid(_reception):
		return _reception.get_queue_entry_world()
	return Vector3(LEGACY_QUEUE_X, FLOOR_Y, LEGACY_ENTRY_Z)


static func get_customer_face_direction() -> Vector3:
	if _reception != null and is_instance_valid(_reception):
		return _reception.get_customer_face_direction()
	return Vector3(0.0, 0.0, -1.0)


static func get_exit_lane_x() -> float:
	if _reception != null and is_instance_valid(_reception):
		return _reception.get_exit_lane_x()
	return LEGACY_EXIT_LANE_X


static func is_queue_slot(world: Vector3) -> bool:
	if _reception != null and is_instance_valid(_reception):
		return _reception.is_queue_lane_at(world)
	return is_equal_approx(world.x, LEGACY_QUEUE_X)
