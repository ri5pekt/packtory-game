extends Node3D

## Spawns pedestrians on the road-side sidewalks (east-west) and the entrance
## walkway (north-south), in both directions, so foot traffic moves every way.

const PedestrianScript = preload("res://scripts/warehouse/sidewalk_pedestrian.gd")
const CHARACTER_BASE_PATH := (
	"res://blender/assets/kenney_mini-characters/Models/GLB format/"
)

const CHARACTER_MODELS := [
	"character-female-a.glb",
	"character-female-b.glb",
	"character-female-c.glb",
	"character-female-d.glb",
	"character-female-e.glb",
	"character-female-f.glb",
	"character-male-a.glb",
	"character-male-b.glb",
	"character-male-c.glb",
	"character-male-d.glb",
	"character-male-e.glb",
	"character-male-f.glb",
]

const MIN_SPAWN_SEC := 2.5
const MAX_SPAWN_SEC := 7.0
const MAX_ACTIVE_PEDESTRIANS := 8
const MIN_SPEED := 1.1
const MAX_SPEED := 2.3

var _grid: WarehouseGrid
var _spawn_timer: Timer
var _routes: Array = []


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_routes = _build_routes()

	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(_spawn_timer)
	_schedule_next_spawn()


func _build_routes() -> Array:
	var routes: Array = []
	var y := WarehouseGrid.DECORATIVE_SIDEWALK_SURFACE_Y
	var x_bounds := _grid.get_decorative_road_x_bounds()

	# East-west road sidewalks (both sides).
	for side in [0, 1]:
		var z := _grid.get_decorative_sidewalk_z(side)
		routes.append({"a": Vector3(x_bounds.x, y, z), "b": Vector3(x_bounds.y, y, z)})

	# North-south entrance walkway.
	var wx := _grid.get_walkway_x()
	var z_bounds := _grid.get_walkway_z_bounds()
	routes.append({"a": Vector3(wx, y, z_bounds.x), "b": Vector3(wx, y, z_bounds.y)})

	return routes


func _schedule_next_spawn() -> void:
	_spawn_timer.start(randf_range(MIN_SPAWN_SEC, MAX_SPAWN_SEC))


func _on_spawn_timer() -> void:
	if _count_active_pedestrians() < MAX_ACTIVE_PEDESTRIANS:
		_spawn_pedestrian()
	_schedule_next_spawn()


func _count_active_pedestrians() -> int:
	var count := 0
	for child in get_children():
		if child.get_script() == PedestrianScript:
			count += 1
	return count


func _spawn_pedestrian() -> void:
	var route: Dictionary = _routes.pick_random()
	var start: Vector3 = route["a"]
	var end: Vector3 = route["b"]
	if randf() > 0.5:
		var swap := start
		start = end
		end = swap

	var model_name: String = CHARACTER_MODELS.pick_random()
	var character_scene: PackedScene = load(CHARACTER_BASE_PATH + model_name)
	if character_scene == null:
		push_warning("SidewalkPedestrians: failed to load %s" % model_name)
		return

	var pedestrian: Node3D = PedestrianScript.new()
	pedestrian.name = "Pedestrian_%s" % model_name.get_basename()
	add_child(pedestrian)
	pedestrian.setup(character_scene, start, end, randf_range(MIN_SPEED, MAX_SPEED))
