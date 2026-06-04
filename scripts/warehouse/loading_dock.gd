class_name LoadingDock
extends Node3D

## Opening delivery phase: a truck drives in from the main road, parks at the east
## dock, and drops three labelled product boxes. The customer queue is held back
## until the delivery is cleared (or a fallback timer).

const DeliveryBoxScript = preload("res://scripts/gameplay/delivery_box.gd")
const TRUCK_MODEL := "res://blender/assets/kenney_car-kit/Models/GLB format/truck.glb"
const TRUCK_SCALE := 0.5

## Yaw values confirmed from orientation test render (model forward = +Z):
##   270° → facing west (-X)   90° → facing east (+X)
##   180° → facing north (-Z)   0° → facing south (+Z)
const TRUCK_YAW_WEST := 270.0
const TRUCK_YAW_NORTH := 180.0
const TRUCK_YAW_EAST := 90.0

const TRUCK_PARK_CELL := Vector2i(WarehouseGrid.DOCK_EAST_COL + 1, 16)

## Animation timings
const LEG_MAIN_ROAD_SEC := 2.0   # driving along the main road to the junction
const LEG_CORNER_SEC := 1.0      # sweeping through the corner arc + rotation
const LEG_SPUR_SEC := 2.0        # driving up the spur to the dock
const LEG_PARK_SEC := 0.5        # final slow crawl into the parking spot

const BOXES := [
	{"id": "headphones", "qty": 10, "cell": Vector2i(24, 15)},
	{"id": "hair_dryer", "qty":  8, "cell": Vector2i(25, 14)},
	{"id": "mouse",      "qty":  6, "cell": Vector2i(25, 16)},
]
const QUEUE_FALLBACK_SEC := 120.0

var _grid: WarehouseGrid
var _boxes: Array[DeliveryBox] = []
var _truck: Node3D
var _queue_started := false


func _ready() -> void:
	add_to_group("loading_dock")
	_grid = get_node("/root/GridService") as WarehouseGrid
	_spawn_truck()
	_spawn_boxes()

	var fallback := Timer.new()
	fallback.one_shot = true
	fallback.timeout.connect(_start_queue)
	add_child(fallback)
	fallback.start(QUEUE_FALLBACK_SEC)


# ── boxes ──────────────────────────────────────────────────────────────────────

func _spawn_boxes() -> void:
	for entry in BOXES:
		var box: DeliveryBox = DeliveryBoxScript.new()
		box.name = "Box_%s" % entry["id"]
		add_child(box)
		box.setup(entry["id"], entry["qty"], _grid.cell_to_world(entry["cell"]), 90.0)
		box.emptied.connect(_on_box_emptied)
		_boxes.append(box)


func _on_box_emptied(box: DeliveryBox) -> void:
	_boxes.erase(box)
	if _boxes.is_empty():
		_depart_truck()
		_start_queue()


func _start_queue() -> void:
	if _queue_started:
		return
	_queue_started = true
	var queue := get_tree().get_first_node_in_group("customer_queue")
	if queue and queue.has_method("begin_service"):
		queue.begin_service()


# ── truck ──────────────────────────────────────────────────────────────────────

func _spawn_truck() -> void:
	var scene: PackedScene = load(TRUCK_MODEL)
	if scene == null:
		return

	_truck = Node3D.new()
	_truck.name = "Truck"
	add_child(_truck)
	var mesh: Node3D = scene.instantiate()
	mesh.scale = Vector3.ONE * TRUCK_SCALE
	_truck.add_child(mesh)

	var park := _grid.cell_to_world(TRUCK_PARK_CELL)
	var junction := _grid.get_dock_road_junction_world()
	var road_y := junction.y

	# Start well off the east edge of the visible lot so the truck drives in.
	var road_spawn := Vector3(
		float(_grid.total_size.x) + 4.0,
		road_y,
		junction.z
	)
	# Corner entry: one cell east of the junction centre, same row.
	var corner_entry := Vector3(junction.x + 0.5, road_y, junction.z)
	# Corner exit: centre of the junction, one row north.
	var corner_exit := Vector3(junction.x, road_y, junction.z - 1.0)
	# Spur end: just south of the dock parking spot.
	var spur_end := Vector3(junction.x, road_y, park.z + 1.0)

	_truck.position = road_spawn
	_truck.rotation_degrees.y = TRUCK_YAW_WEST

	var tween := create_tween()

	# Leg 1 — drive west along the main road to the corner entry.
	tween.tween_property(_truck, "position", corner_entry, LEG_MAIN_ROAD_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Leg 2 — sweep through the corner: move to exit while rotating to face north.
	# Run position and rotation in parallel for a smooth arc feel.
	tween.parallel().tween_property(_truck, "position", corner_exit, LEG_CORNER_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		_truck, "rotation_degrees:y",
		TRUCK_YAW_NORTH, LEG_CORNER_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Leg 3 — drive north up the spur to near the dock.
	tween.tween_property(_truck, "position", spur_end, LEG_SPUR_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Leg 4 — slow final park.
	tween.tween_property(_truck, "position", park, LEG_PARK_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _depart_truck() -> void:
	if not is_instance_valid(_truck):
		return

	var park := _truck.position
	var junction := _grid.get_dock_road_junction_world()
	var road_y := junction.y
	var corner_entry := Vector3(junction.x, road_y, junction.z - 1.0)
	var corner_exit := Vector3(junction.x + 0.5, road_y, junction.z)
	var road_exit := Vector3(float(_grid.total_size.x) + 4.0, road_y, junction.z)

	var tween := create_tween()

	# Reverse of arrival.
	tween.tween_property(_truck, "position", corner_entry, LEG_SPUR_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Corner turn: face east as the truck swings back onto the main road.
	tween.parallel().tween_property(_truck, "position", corner_exit, LEG_CORNER_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		_truck, "rotation_degrees:y",
		TRUCK_YAW_EAST, LEG_CORNER_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Drive east and off-screen.
	tween.tween_property(_truck, "position", road_exit, LEG_MAIN_ROAD_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_truck.queue_free)
