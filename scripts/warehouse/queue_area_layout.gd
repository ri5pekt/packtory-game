class_name QueueAreaLayout
extends RefCounted

## Customer queue zone. A single-file lane in cell column 16 (lined up with the
## door / walkway at x16). The front slot is at the north end (toward the work
## zone, where the manager serves); shoppers fill from the front backwards toward
## the door, so entering never crosses an occupied slot. Side rails on cells 15 and
## 17 mark the lane visually but leave the north (manager) and south (entry) open.

const FLOOR_Y := 0.1
const QUEUE_X := 16.5
const QUEUE_FRONT_Z := 16.5
const QUEUE_SLOT_SPACING := 0.7   # shoppers stand close together
const MAX_QUEUE := 6

# Rails sit one cell out from the lane (cells 14 & 18), leaving a free cell on each
# side of the line (15 & 17) so a served shopper can slip past the queue to leave.
const RAIL_WEST_X := 14.5
const RAIL_EAST_X := 18.5
const RAIL_FIRST_Z := 16
const RAIL_LAST_Z := 21
const RAIL_STEP := 0.5
const ENTRY_Z := 21.0
# Departing shoppers step into the east side lane to bypass the queue.
const EXIT_LANE_X := 17.5


static func get_slot(index: int) -> Vector3:
	return Vector3(QUEUE_X, 0.0, QUEUE_FRONT_Z + float(index) * QUEUE_SLOT_SPACING)


static func get_entry_point() -> Vector3:
	return Vector3(QUEUE_X, 0.0, ENTRY_Z)


static func is_queue_slot(world: Vector3) -> bool:
	return is_equal_approx(world.x, QUEUE_X)


static func cells_for_fence(world_position: Vector3, _yaw_deg: float) -> Array[Vector2i]:
	# Rails run along Z; each segment occupies the cell under its centre.
	return [Vector2i(floori(world_position.x), floori(world_position.z))]


static func get_fence_placements() -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	var z := float(RAIL_FIRST_Z)
	while z <= float(RAIL_LAST_Z) + 0.6:
		placements.append({"position": Vector3(RAIL_WEST_X, FLOOR_Y, z), "yaw": 90.0})
		placements.append({"position": Vector3(RAIL_EAST_X, FLOOR_Y, z), "yaw": 90.0})
		z += RAIL_STEP
	return placements
