extends Node3D

const RoadCarScript = preload("res://scripts/warehouse/road_car.gd")
const CAR_BASE_PATH := "res://blender/assets/kenney_car-kit/Models/GLB format/"

const CAR_MODELS := [
	"sedan.glb",
	"sedan-sports.glb",
	"hatchback-sports.glb",
	"suv.glb",
	"taxi.glb",
	"van.glb",
	"delivery.glb",
	"truck.glb",
]

const MIN_SPAWN_SEC := 2.5
const MAX_SPAWN_SEC := 8.0
const MAX_ACTIVE_CARS := 4
const MIN_SPEED := 3.5
const MAX_SPEED := 6.5

var _grid: WarehouseGrid
var _spawn_timer: Timer
var _road_x_bounds: Vector2


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_road_x_bounds = _grid.get_decorative_road_x_bounds()

	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(_spawn_timer)
	_schedule_next_spawn()


func _schedule_next_spawn() -> void:
	_spawn_timer.start(randf_range(MIN_SPAWN_SEC, MAX_SPAWN_SEC))


func _on_spawn_timer() -> void:
	if _count_active_cars() < MAX_ACTIVE_CARS:
		_spawn_car()
	_schedule_next_spawn()


func _count_active_cars() -> int:
	var count := 0
	for child in get_children():
		if child.get_script() == RoadCarScript:
			count += 1
	return count


func _spawn_car() -> void:
	var direction := 1.0 if randf() > 0.5 else -1.0
	var lane_index := 0 if direction > 0.0 else 1
	var lane_position := _grid.get_decorative_road_lane_position(lane_index)

	var start_x := _road_x_bounds.x if direction > 0.0 else _road_x_bounds.y
	var end_x := _road_x_bounds.y if direction > 0.0 else _road_x_bounds.x

	var model_name: String = CAR_MODELS.pick_random()
	var car_scene: PackedScene = load(CAR_BASE_PATH + model_name)
	if car_scene == null:
		push_warning("RoadTraffic: failed to load %s" % model_name)
		return

	var car: Node3D = RoadCarScript.new()
	car.name = "Car_%s" % model_name.get_basename()
	add_child(car)
	car.setup(
		car_scene,
		start_x,
		lane_position,
		direction,
		randf_range(MIN_SPEED, MAX_SPEED),
		end_x
	)
