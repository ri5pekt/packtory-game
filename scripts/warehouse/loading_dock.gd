class_name LoadingDock
extends Node3D

## Opening delivery phase: a truck drives in from the main road, parks at the east
## dock, unloads three labelled product boxes, then drives away. Boxes stay until
## the player picks them up. The customer queue starts after boxes are cleared
## (or a fallback timer).

const DeliveryBoxScript = preload("res://scripts/gameplay/delivery_box.gd")
const EquipmentDeliveryBoxScript = preload(
	"res://scripts/gameplay/equipment_delivery_box.gd"
)
const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")
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
const UNLOAD_PAUSE_SEC := 1.2    # brief stop at dock before driving away

const BOXES := [
	{
		"id": "headphones",
		"qty": DeliveryBoxScript.UNITS_PER_BOX,
		"cell": Vector2i(24, 15),
		"label_offset": Vector3(-0.12, 0.0, 0.0),
	},
	{
		"id": "hair_dryer",
		"qty": DeliveryBoxScript.UNITS_PER_BOX,
		"cell": Vector2i(25, 15),  # moved from (25,14) which is the van's reserve spot
		"label_offset": Vector3(0.14, 0.12, 0.0),
	},
	{
		"id": "mouse",
		"qty": DeliveryBoxScript.UNITS_PER_BOX,
		"cell": Vector2i(25, 16),
		"label_offset": Vector3(0.14, 0.0, 0.08),
	},
]
const QUEUE_FALLBACK_SEC := 120.0
## Keep clear of the parked online van — row 13 (one north of the box drop zone).
const OUTBOUND_VAN_RESERVE_CELLS := [
	Vector2i(WarehouseGrid.DOCK_WEST_COL, WarehouseGrid.DOCK_NORTH_ROW - 1),
	Vector2i(WarehouseGrid.DOCK_WEST_COL + 1, WarehouseGrid.DOCK_NORTH_ROW - 1),
]
const EQUIPMENT_DROP_CELLS := [
	Vector2i(24, 17),
	Vector2i(25, 17),
	Vector2i(23, 18),
]
const PRODUCT_REORDER_DROP_CELLS := [
	Vector2i(23, 15),
	Vector2i(23, 16),
	Vector2i(23, 17),
	Vector2i(24, 17),
	Vector2i(25, 17),
	Vector2i(23, 18),
]

var _grid: WarehouseGrid
var _boxes: Array[DeliveryBox] = []
var _equipment_boxes: Array = []
var _truck: Node3D
var _truck_departed := false
var _queue_started := false


func _ready() -> void:
	add_to_group("loading_dock")
	_grid = get_node("/root/GridService") as WarehouseGrid
	_connect_day_start()


func _connect_day_start() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		_start_delivery()
		return
	if session.is_gameplay_active():
		_start_delivery()
		return
	session.day_started.connect(_start_delivery, CONNECT_ONE_SHOT)


func _start_delivery() -> void:
	var save := get_node_or_null("/root/SaveManager")
	if save and save.has_method("is_loading_save") and save.is_loading_save():
		return
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
		var offset: Vector3 = entry.get("label_offset", Vector3.ZERO)
		box.setup(entry["id"], entry["qty"], _grid.cell_to_world(entry["cell"]), 90.0, offset)
		box.emptied.connect(_on_box_emptied)
		_boxes.append(box)


func _on_box_emptied(box: DeliveryBox) -> void:
	_boxes.erase(box)
	if _boxes.is_empty():
		_start_queue()


func _start_queue() -> void:
	if _queue_started:
		return
	_queue_started = true
	var queue := get_tree().get_first_node_in_group("customer_queue")
	if queue and queue.has_method("begin_service"):
		queue.begin_service()


func is_queue_started() -> bool:
	return _queue_started


func deliver_equipment_order(delivery: Dictionary, instant: bool = false) -> void:
	if _grid == null:
		return
	var order_id := int(delivery.get("order_id", 0))
	for box in _equipment_boxes:
		if is_instance_valid(box) and box.order_id == order_id:
			return
	if instant:
		_spawn_equipment_box(delivery)
		return
	_spawn_equipment_truck(delivery)


func get_equipment_box_count() -> int:
	var count := 0
	for box in _equipment_boxes:
		if is_instance_valid(box):
			count += 1
	return count


func deliver_product_order(delivery: Dictionary, instant: bool = false) -> void:
	if _grid == null:
		return
	var order_id := int(delivery.get("order_id", 0))
	for box in _boxes:
		if is_instance_valid(box) and box.reorder_order_id == order_id:
			return
	if instant:
		_spawn_product_reorder_box(delivery)
		return
	_spawn_product_reorder_truck(delivery)


func get_reorder_box_count() -> int:
	var count := 0
	for box in _boxes:
		if is_instance_valid(box) and box.reorder_order_id > 0:
			count += 1
	return count


func _spawn_equipment_truck(delivery: Dictionary) -> void:
	var scene: PackedScene = load(TRUCK_MODEL)
	if scene == null:
		_spawn_equipment_box(delivery)
		return

	var truck := Node3D.new()
	truck.name = "EquipmentTruck"
	add_child(truck)
	var mesh: Node3D = scene.instantiate()
	mesh.scale = Vector3.ONE * TRUCK_SCALE
	truck.add_child(mesh)

	var park := _grid.cell_to_world(TRUCK_PARK_CELL)
	var route := _truck_route_inbound(park)
	_tween_truck_inbound(
		truck,
		route,
		0.65,
		UNLOAD_PAUSE_SEC * 0.5,
		func() -> void:
			_spawn_equipment_box(delivery)
			truck.queue_free()
	)


func _spawn_equipment_box(delivery: Dictionary) -> void:
	if _grid == null:
		return
	var order_id := int(delivery.get("order_id", 0))
	for box in _equipment_boxes:
		if is_instance_valid(box) and box.order_id == order_id:
			return
	var cell := _next_equipment_drop_cell()
	var box: Node3D = EquipmentDeliveryBoxScript.new()
	box.name = "EquipmentBox_%d" % order_id
	add_child(box)
	box.setup(delivery, _grid.cell_to_world(cell), 90.0)
	box.emptied.connect(_on_equipment_box_emptied)
	_equipment_boxes.append(box)


func _on_equipment_box_emptied(box: Node3D) -> void:
	_equipment_boxes.erase(box)


func _spawn_product_reorder_truck(delivery: Dictionary) -> void:
	var scene: PackedScene = load(TRUCK_MODEL)
	if scene == null:
		_spawn_product_reorder_box(delivery)
		return

	var truck := Node3D.new()
	truck.name = "ProductReorderTruck"
	add_child(truck)
	var mesh: Node3D = scene.instantiate()
	mesh.scale = Vector3.ONE * TRUCK_SCALE
	truck.add_child(mesh)

	var park := _grid.cell_to_world(TRUCK_PARK_CELL)
	var route := _truck_route_inbound(park)
	_tween_truck_inbound(
		truck,
		route,
		0.65,
		UNLOAD_PAUSE_SEC * 0.5,
		func() -> void:
			_spawn_product_reorder_box(delivery)
			truck.queue_free()
	)


func _spawn_product_reorder_box(delivery: Dictionary) -> void:
	if _grid == null:
		return
	var order_id := int(delivery.get("order_id", 0))
	for box in _boxes:
		if is_instance_valid(box) and box.reorder_order_id == order_id:
			return
	var product_id := String(delivery.get("product_id", ""))
	var quantity := int(delivery.get("quantity", 0))
	if product_id == "" or quantity <= 0:
		return
	var cell := _next_product_reorder_drop_cell()
	var box: DeliveryBox = DeliveryBoxScript.new()
	box.name = "ReorderBox_%d" % order_id
	add_child(box)
	box.setup(
		product_id,
		quantity,
		_grid.cell_to_world(cell),
		90.0,
		Vector3.ZERO,
		order_id
	)
	box.emptied.connect(_on_box_emptied)
	_boxes.append(box)


func _next_product_reorder_drop_cell() -> Vector2i:
	for cell in PRODUCT_REORDER_DROP_CELLS:
		if _is_drop_cell_blocked(cell):
			continue
		return cell
	return PRODUCT_REORDER_DROP_CELLS[0]


func _next_equipment_drop_cell() -> Vector2i:
	for cell in EQUIPMENT_DROP_CELLS:
		if _is_drop_cell_blocked(cell):
			continue
		return cell
	return EQUIPMENT_DROP_CELLS[0]


func _is_drop_cell_blocked(cell: Vector2i) -> bool:
	if cell in OUTBOUND_VAN_RESERVE_CELLS:
		return true
	for box in _boxes:
		if is_instance_valid(box) and _grid.world_to_cell(box.global_position) == cell:
			return true
	for box in _equipment_boxes:
		if is_instance_valid(box) and _grid.world_to_cell(box.global_position) == cell:
			return true
	return false


func export_save_state() -> Dictionary:
	var boxes: Array = []
	for box in _boxes:
		if not is_instance_valid(box):
			continue
		boxes.append({
			"product_id": String(box.product_id),
			"count": int(box.count),
			"cell": SaveManagerScript.vec2i_to_array(_grid.world_to_cell(box.global_position)),
			"yaw": box.rotation_degrees.y,
			"label_offset": SaveManagerScript.vec3_to_array(box.get_label_offset()) if box.has_method("get_label_offset") else [0, 0, 0],
		})
	var equipment_boxes: Array = []
	for box in _equipment_boxes:
		if not is_instance_valid(box):
			continue
		equipment_boxes.append({
			"order_id": int(box.order_id),
			"item_id": String(box.item_id),
			"placeable_type": String(box.placeable_type),
			"delivery_label": String(box.delivery_label),
			"cell": SaveManagerScript.vec2i_to_array(_grid.world_to_cell(box.global_position)),
			"yaw": box.rotation_degrees.y,
		})
	return {
		"delivery_started": not _boxes.is_empty() or not equipment_boxes.is_empty(),
		"queue_started": _queue_started,
		"boxes": boxes,
		"equipment_boxes": equipment_boxes,
	}


func apply_save_state(data: Dictionary) -> void:
	_clear_boxes()
	_clear_equipment_boxes()
	for entry in data.get("boxes", []):
		var box: DeliveryBox = DeliveryBoxScript.new()
		box.name = "Box_%s" % entry.get("product_id", "saved")
		add_child(box)
		var cell := SaveManagerScript.array_to_vec2i(entry.get("cell", [0, 0]))
		var offset := SaveManagerScript.array_to_vec3(entry.get("label_offset", [0, 0, 0]))
		box.setup(
			String(entry.get("product_id", "")),
			int(entry.get("count", 0)),
			_grid.cell_to_world(cell),
			float(entry.get("yaw", 90.0)),
			offset
		)
		box.emptied.connect(_on_box_emptied)
		_boxes.append(box)
	for entry in data.get("equipment_boxes", []):
		if not entry is Dictionary:
			continue
		var delivery := {
			"order_id": int(entry.get("order_id", 0)),
			"item_id": String(entry.get("item_id", "")),
			"placeable_type": String(entry.get("placeable_type", "")),
			"label": String(entry.get("delivery_label", "Equipment")),
		}
		var cell := SaveManagerScript.array_to_vec2i(entry.get("cell", [0, 0]))
		var equip_box: Node3D = EquipmentDeliveryBoxScript.new()
		equip_box.name = "EquipmentBox_%d" % delivery.get("order_id", 0)
		add_child(equip_box)
		equip_box.setup(delivery, _grid.cell_to_world(cell), float(entry.get("yaw", 90.0)))
		equip_box.emptied.connect(_on_equipment_box_emptied)
		_equipment_boxes.append(equip_box)
	_queue_started = bool(data.get("queue_started", false))
	if _queue_started:
		_start_queue()


func _clear_equipment_boxes() -> void:
	for box in _equipment_boxes.duplicate():
		if is_instance_valid(box):
			box.queue_free()
	_equipment_boxes.clear()


func _clear_boxes() -> void:
	for box in _boxes.duplicate():
		if is_instance_valid(box):
			box.queue_free()
	_boxes.clear()
	for box in get_tree().get_nodes_in_group("delivery_boxes"):
		if is_instance_valid(box):
			box.queue_free()


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
	var route := _truck_route_inbound(park)
	_tween_truck_inbound(
		_truck,
		route,
		1.0,
		UNLOAD_PAUSE_SEC,
		_depart_truck
	)


func _depart_truck() -> void:
	if _truck_departed or not is_instance_valid(_truck):
		return
	_truck_departed = true
	var route := _truck_route_outbound()
	_tween_truck_outbound(_truck, route, _truck.queue_free)


func _truck_route_inbound(park: Vector3) -> Dictionary:
	var junction := _grid.get_dock_road_junction_world()
	var road_y := junction.y
	return {
		"spawn": Vector3(float(_grid.total_size.x) + 4.0, road_y, junction.z),
		"corner_entry": Vector3(junction.x + 0.5, road_y, junction.z),
		"corner_exit": Vector3(junction.x, road_y, junction.z - 1.0),
		"spur_end": Vector3(junction.x, road_y, park.z + 1.0),
		"park": park,
	}


func _truck_route_outbound() -> Dictionary:
	var junction := _grid.get_dock_road_junction_world()
	var road_y := junction.y
	return {
		"corner_entry": Vector3(junction.x, road_y, junction.z - 1.0),
		"corner_exit": Vector3(junction.x + 0.5, road_y, junction.z),
		"road_exit": Vector3(float(_grid.total_size.x) + 4.0, road_y, junction.z),
	}


func _tween_truck_inbound(
	truck: Node3D,
	route: Dictionary,
	time_scale: float,
	unload_pause: float,
	on_complete: Callable
) -> void:
	truck.position = route["spawn"]
	truck.rotation_degrees.y = TRUCK_YAW_WEST

	var tween := create_tween()
	# Leg 1 — west along the main road.
	tween.tween_property(truck, "position", route["corner_entry"], LEG_MAIN_ROAD_SEC * time_scale) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Leg 2 — turn north at the junction (move + rotate together, not during leg 1).
	tween.tween_property(truck, "position", route["corner_exit"], LEG_CORNER_SEC * time_scale) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		truck, "rotation_degrees:y", TRUCK_YAW_NORTH, LEG_CORNER_SEC * time_scale
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Leg 3 — north up the spur.
	tween.tween_property(truck, "position", route["spur_end"], LEG_SPUR_SEC * time_scale) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Leg 4 — final park.
	tween.tween_property(truck, "position", route["park"], LEG_PARK_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if unload_pause > 0.0:
		tween.tween_interval(unload_pause)
	if on_complete.is_valid():
		tween.tween_callback(on_complete)


func _tween_truck_outbound(truck: Node3D, route: Dictionary, on_complete: Callable) -> void:
	var tween := create_tween()
	# Leg 1 — back down the spur.
	tween.tween_property(truck, "position", route["corner_entry"], LEG_SPUR_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Leg 2 — turn east onto the main road.
	tween.tween_property(truck, "position", route["corner_exit"], LEG_CORNER_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		truck, "rotation_degrees:y", TRUCK_YAW_EAST, LEG_CORNER_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Leg 3 — drive east off-screen.
	tween.tween_property(truck, "position", route["road_exit"], LEG_MAIN_ROAD_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if on_complete.is_valid():
		tween.tween_callback(on_complete)
