extends Node3D

## Kenney mini-market fence barriers forming a customer queue corral.
## Each segment registers its own grid cells so player-placed barriers use the same API.

const FENCE_MODEL := (
	"res://blender/assets/kenney_mini-market/Models/GLB format/fence.glb"
)
const WarehouseObstacleScript = preload("res://scripts/warehouse/warehouse_obstacle.gd")
# Kenney fence.glb rail span is ~0.48 m along local X.
const FENCE_RAIL_ALONG_X := Vector3(0.48, 0.42, 0.12)
const FENCE_RAIL_ALONG_Z := Vector3(0.12, 0.42, 0.48)


func _ready() -> void:
	for entry in QueueAreaLayout.get_fence_placements():
		_spawn_fence(entry["position"], entry["yaw"])


func _spawn_fence(world_position: Vector3, yaw_deg: float) -> void:
	var scene: PackedScene = load(FENCE_MODEL)
	if scene == null:
		push_error("QueueAreaSpawn: failed to load %s" % FENCE_MODEL)
		return

	var root := Node3D.new()
	root.name = "Fence"
	root.position = world_position
	root.rotation_degrees.y = yaw_deg
	add_child(root)

	var obstacle: WarehouseObstacle = WarehouseObstacleScript.new()
	obstacle.name = "GridObstacle"
	root.add_child(obstacle)
	obstacle.occupy(QueueAreaLayout.cells_for_fence(world_position, yaw_deg))

	var mesh: Node3D = scene.instantiate()
	root.add_child(mesh)

	var along_z := is_equal_approx(yaw_deg, 90.0)
	var rail_size := FENCE_RAIL_ALONG_Z if along_z else FENCE_RAIL_ALONG_X
	StaticCollision.add_box(root, rail_size)
	StaticCollision.add_box(root, Vector3(0.14, 0.42, 0.14))
