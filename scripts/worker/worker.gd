class_name Worker
extends Node3D

signal inventory_changed(stacks: Array)
signal task_assignments_changed(tasks: Dictionary)

const CharacterAnimationUtilsScript = preload(
	"res://scripts/shared/character_animation_utils.gd"
)
const CharacterCatalogScript = preload("res://scripts/dev/character_catalog.gd")
const WorkerHireConfigScript = preload("res://scripts/gameplay/worker_hire_config.gd")
const WorkerTaskConfigScript = preload("res://scripts/gameplay/worker_task_config.gd")

const WALK_SPEED := 3.5
const APPROACH_OFFSET := Vector3(0.0, 0.0, 0.85)
const ARRIVE_DISTANCE := 0.05
const MAX_CARRIED_ENTRIES := 6
const PACK_DURATION := 3.5
const PACK_BAR_WIDTH := 0.58
const PACK_BAR_Y := 1.38

var _grid: WarehouseGrid
var _pathfinding: Pathfinding
var _anim: AnimationPlayer
var _walk_anim_name: String = ""
var _idle_anim_name: String = ""
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _moving: bool = false
var _packing: bool = false
var _pack_progress: float = 0.0
var _pack_callback: Callable = Callable()
var _pending_pack_callback: Callable = Callable()
var _packing_table: PackingTable = null
var _arrive_callback: Callable = Callable()
var _stacks: Dictionary = {}
var _stack_order: Array[String] = []
var _carried_boxes: Array = []
var _carried_placeables: Array = []
var _next_box_id: int = 1
var _next_placeable_box_id: int = 1
var _package_meta: Dictionary = {}
var _worker_id := "manager"
var _display_name := "Manager"
var _daily_salary := 0
var _specialization := WorkerHireConfigScript.SPECIALIZATION_GENERAL
var _is_manager := true
var _model_file := "character-male-d.glb"
var _task_assignments: Dictionary = WorkerTaskConfigScript.default_tasks()

var _pack_bar_root: Node3D
var _pack_bar_fill: MeshInstance3D

var selection_ring: MeshInstance3D


func _ready() -> void:
	selection_ring = get_node_or_null("SelectionRing") as MeshInstance3D
	_grid = get_node("/root/GridService") as WarehouseGrid
	_anim = CharacterAnimationUtilsScript.find_animation_player(self)
	_walk_anim_name = CharacterAnimationUtilsScript.resolve_anim_name(
		_anim, ["walk", "Walk", "run"]
	)
	_idle_anim_name = CharacterAnimationUtilsScript.resolve_anim_name(
		_anim, ["idle", "Idle", "static"]
	)
	add_to_group("workers")
	set_selected(false)
	_strip_model_accessories()
	_build_pack_bar()
	_play_idle()
	call_deferred("_bind_pathfinding")


func _bind_pathfinding() -> void:
	_pathfinding = _grid.pathfinding


func _process(delta: float) -> void:
	if _packing:
		_update_pack_bar_billboard()
		_advance_packing(delta)
		return
	if not _moving:
		return
	_ensure_walk_playing()
	_advance_along_path(delta)


func set_selected(is_selected: bool) -> void:
	if is_instance_valid(selection_ring):
		selection_ring.visible = is_selected


func get_worker_id() -> String:
	return _worker_id


func get_display_name() -> String:
	return _display_name


func get_daily_salary() -> int:
	return _daily_salary


func get_specialization() -> String:
	return _specialization


func is_manager() -> bool:
	return _is_manager


func get_approach_position() -> Vector3:
	return global_position + APPROACH_OFFSET


func get_face_target() -> Vector3:
	return global_position + Vector3(0.0, 0.75, 0.0)


func get_task_assignments() -> Dictionary:
	return _task_assignments.duplicate()


func is_task_enabled(category_id: String) -> bool:
	return bool(_task_assignments.get(category_id, false))


func set_task_enabled(category_id: String, enabled: bool) -> void:
	if not WorkerTaskConfigScript.is_valid_category(category_id):
		return
	_task_assignments[category_id] = enabled
	task_assignments_changed.emit(get_task_assignments())


func toggle_task(category_id: String) -> void:
	set_task_enabled(category_id, not is_task_enabled(category_id))


func apply_task_assignments(data: Dictionary) -> void:
	var defaults := WorkerTaskConfigScript.default_tasks()
	for key in defaults:
		_task_assignments[key] = bool(data.get(key, defaults[key]))
	task_assignments_changed.emit(get_task_assignments())


func get_roster_summary() -> Dictionary:
	return {
		"worker_id": _worker_id,
		"display_name": _display_name,
		"daily_salary": _daily_salary,
		"specialization": _specialization,
		"is_manager": _is_manager,
		"tasks": get_task_assignments(),
	}


func apply_roster_profile(data: Dictionary) -> void:
	_worker_id = String(data.get("worker_id", _worker_id))
	_display_name = String(data.get("display_name", _display_name))
	_daily_salary = int(data.get("daily_salary", data.get("salary", _daily_salary)))
	_specialization = String(
		data.get("specialization", WorkerHireConfigScript.SPECIALIZATION_GENERAL)
	)
	_is_manager = bool(data.get("is_manager", _is_manager))
	var model := String(data.get("model", ""))
	if model != "" and model != _model_file:
		_model_file = model
		_swap_character_model(_model_file)
	name = _display_name if _display_name != "" else _worker_id


func is_moving() -> bool:
	return _moving


func is_packing() -> bool:
	return _packing


func get_model_file() -> String:
	return _model_file


func walk_to_world(world_position: Vector3, on_arrive: Callable = Callable()) -> void:
	if _packing:
		return

	_arrive_callback = on_arrive

	if _pathfinding == null:
		_fire_arrive()
		return

	var target := _clamp_to_warehouse(world_position)
	var target_cell := _grid.world_to_cell(target)
	target.y = _grid.walk_surface_y(target_cell)

	var path_points := _pathfinding.find_path_world(global_position, target)
	if path_points.is_empty():
		_fire_arrive()
		return

	_path = path_points
	while _path.size() > 1:
		var first := _path[0]
		var flat_offset := Vector3(first.x - global_position.x, 0.0, first.z - global_position.z)
		if flat_offset.length() <= ARRIVE_DISTANCE:
			_path.remove_at(0)
		else:
			break

	if _path.is_empty():
		_fire_arrive()
		return

	_path_index = 0
	_moving = true
	_play_walk()


func start_packing(on_complete: Callable = Callable(), packing_table: PackingTable = null) -> bool:
	if _packing:
		if on_complete.is_valid():
			on_complete.call(false)
		return false
	_packing_table = packing_table
	if _moving:
		_pending_pack_callback = on_complete
		return true
	_begin_packing(on_complete)
	return true


func _begin_packing(on_complete: Callable) -> void:
	_packing = true
	_pack_progress = 0.0
	_pack_callback = on_complete
	_set_pack_bar_visible(true)
	_update_pack_bar()
	_play_idle()
	if _packing_table != null and is_instance_valid(_packing_table):
		_packing_table.begin_packing_visual()


func face_world(target: Vector3) -> void:
	var direction := target - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	rotation.y = atan2(direction.x, direction.z)


func get_inventory() -> Array:
	var items: Array = []
	for product_id in _stack_order:
		for _i in _stacks[product_id]:
			items.append(product_id)
	return items


func get_inventory_stacks() -> Array:
	var stacks: Array = []
	for product_id in _stack_order:
		stacks.append({"id": product_id, "count": int(_stacks[product_id]), "is_box": false})
	for box in _carried_boxes:
		stacks.append({
			"id": String(box.get("product_id", "")),
			"count": int(box.get("count", 0)),
			"is_box": true,
			"box_id": int(box.get("id", -1)),
		})
	for placeable in _carried_placeables:
		stacks.append({
			"id": String(placeable.get("item_id", "")),
			"count": 1,
			"is_placeable_box": true,
			"placeable_box_id": int(placeable.get("id", -1)),
			"placeable_type": String(placeable.get("placeable_type", "")),
			"label": String(placeable.get("label", "")),
			"order_id": int(placeable.get("order_id", 0)),
		})
	return stacks


func get_carried_boxes() -> Array:
	return _carried_boxes.duplicate(true)


func get_carried_placeables() -> Array:
	return _carried_placeables.duplicate(true)


## Loose product units plus sealed delivery boxes (each box = one entry).
func used_inventory_slots() -> int:
	return get_total_units() + _carried_boxes.size() + _carried_placeables.size()


func free_carry_capacity() -> int:
	return maxi(0, MAX_CARRIED_ENTRIES - used_inventory_slots())


func can_carry_box() -> bool:
	if has_package():
		return false
	return free_carry_capacity() > 0


func add_delivery_box(product_id: String, count: int) -> bool:
	if not can_carry_box() or product_id == "" or count <= 0:
		return false
	_carried_boxes.append({
		"id": _next_box_id,
		"product_id": product_id,
		"count": count,
	})
	_next_box_id += 1
	_emit_inventory_changed()
	return true


func add_placeable_box(
	order_id: int,
	placeable_type: String,
	item_id: String,
	label: String
) -> bool:
	if not can_carry_placeable_box() or placeable_type == "":
		return false
	_carried_placeables.append({
		"id": _next_placeable_box_id,
		"order_id": order_id,
		"placeable_type": placeable_type,
		"item_id": item_id,
		"label": label,
	})
	_next_placeable_box_id += 1
	_emit_inventory_changed()
	return true


func can_carry_placeable_box() -> bool:
	if has_package():
		return false
	return free_carry_capacity() > 0


func find_placeable_box_index(box_id: int) -> int:
	for i in range(_carried_placeables.size()):
		if int(_carried_placeables[i].get("id", -1)) == box_id:
			return i
	return -1


func remove_placeable_box(box_id: int) -> Dictionary:
	var index := find_placeable_box_index(box_id)
	if index < 0:
		return {}
	var entry: Dictionary = _carried_placeables[index].duplicate()
	_carried_placeables.remove_at(index)
	_emit_inventory_changed()
	return entry


func find_box_index_by_id(box_id: int) -> int:
	for i in range(_carried_boxes.size()):
		if int(_carried_boxes[i].get("id", -1)) == box_id:
			return i
	return -1


func count_box_product(product_id: String) -> int:
	var total := 0
	for box in _carried_boxes:
		if String(box.get("product_id", "")) == product_id:
			total += int(box.get("count", 0))
	return total


func deposit_box_to_storage(worker_box_id: int, storage: Node) -> bool:
	if storage == null or not storage.has_method("store_box"):
		return false
	var box_index := find_box_index_by_id(worker_box_id)
	if box_index < 0:
		return false
	var box: Dictionary = _carried_boxes[box_index]
	var product_id := String(box.get("product_id", ""))
	var count := int(box.get("count", 0))
	if product_id == "" or count <= 0:
		return false
	if not storage.can_store_box():
		return false
	if not storage.store_box(product_id, count):
		return false
	_carried_boxes.remove_at(box_index)
	_emit_inventory_changed()
	return true


func withdraw_box_to_inventory(storage: Node, storage_box_id: int) -> bool:
	if storage == null or not storage.has_method("withdraw_box"):
		return false
	if not can_carry_box():
		return false
	var box: Dictionary = storage.withdraw_box(storage_box_id)
	if box.is_empty():
		return false
	var product_id := String(box.get("product_id", ""))
	var count := int(box.get("count", 0))
	if not add_delivery_box(product_id, count):
		if storage.has_method("store_box"):
			storage.store_box(product_id, count)
		return false
	return true


## Unpack a carried delivery box onto `shelf`. Returns units stocked.
func stock_from_box_id(box_id: int, shelf: ProductShelf, amount: int) -> int:
	var box_index := find_box_index_by_id(box_id)
	if box_index < 0:
		return 0
	var box: Dictionary = _carried_boxes[box_index]
	var product_id := String(box.get("product_id", ""))
	var box_count := int(box.get("count", 0))
	if product_id == "" or box_count <= 0:
		return 0
	if not shelf.can_receive(product_id):
		return 0
	var to_move := mini(maxi(1, amount), mini(box_count, shelf.free_space()))
	if to_move <= 0:
		return 0
	var stocked := shelf.stock_product(product_id, to_move)
	if stocked <= 0:
		return 0
	box_count -= stocked
	if box_count <= 0:
		_carried_boxes.remove_at(box_index)
	else:
		box["count"] = box_count
		_carried_boxes[box_index] = box
	_emit_inventory_changed()
	return stocked


func get_total_units() -> int:
	var total := 0
	for product_id in _stacks:
		total += int(_stacks[product_id])
	return total


func count_product(product_id: String) -> int:
	return int(_stacks.get(product_id, 0))


func is_inventory_full() -> bool:
	return free_carry_capacity() <= 0


func has_product(product_id: String) -> bool:
	return count_product(product_id) > 0


func has_package() -> bool:
	return has_product("package")


func is_online_package() -> bool:
	return has_package() and String(_package_meta.get("source", "")) == "online"


func get_package_meta() -> Dictionary:
	return _package_meta.duplicate()


func tag_carried_package(meta: Dictionary) -> void:
	_package_meta = meta.duplicate()


func clear_package_meta() -> void:
	_package_meta = {}


func add_product(product_id: String) -> bool:
	if has_package() and product_id != "package":
		return false
	if is_inventory_full():
		return false
	if not _stacks.has(product_id):
		_stack_order.append(product_id)
	_stacks[product_id] = count_product(product_id) + 1
	_emit_inventory_changed()
	return true


func remove_product(product_id: String) -> bool:
	if not has_product(product_id):
		return false
	_stacks[product_id] = count_product(product_id) - 1
	if _stacks[product_id] <= 0:
		_stacks.erase(product_id)
		_stack_order.erase(product_id)
	if product_id == "package":
		clear_package_meta()
	_emit_inventory_changed()
	return true


func free_capacity() -> int:
	return 2147483647


## Add up to `amount` units of a product; returns how many were actually added.
func add_products(product_id: String, amount: int) -> int:
	var added := 0
	while added < amount and add_product(product_id):
		added += 1
	return added


## Remove up to `amount` units of a product; returns how many were actually removed.
func remove_products(product_id: String, amount: int) -> int:
	var removed := 0
	while removed < amount and remove_product(product_id):
		removed += 1
	return removed


func _emit_inventory_changed() -> void:
	inventory_changed.emit(get_inventory_stacks())


## Remove every unit listed in `order`, then add one packed package.
func consume_order_and_pack(order: Dictionary) -> bool:
	if order.is_empty() or has_package():
		return false
	if not ProductCatalog.inventory_fulfills_order(get_inventory(), order):
		return false
	var saved_order := _stack_order.duplicate()
	var saved_stacks := _stacks.duplicate()
	for product_id in order:
		var qty := int(order[product_id])
		for _i in range(qty):
			if not remove_product(String(product_id)):
				_stack_order = saved_order
				_stacks = saved_stacks
				_emit_inventory_changed()
				return false
	if not add_product("package"):
		_stack_order = saved_order
		_stacks = saved_stacks
		_emit_inventory_changed()
		return false
	return true


## Undo a successful pack when queue state changed before delivery was registered.
func restore_packed_order(order: Dictionary) -> void:
	if has_package():
		remove_product("package")
	clear_package_meta()
	for product_id in order:
		for _i in range(int(order[product_id])):
			add_product(String(product_id))


func _advance_packing(delta: float) -> void:
	_pack_progress = minf(_pack_progress + delta / PACK_DURATION, 1.0)
	_update_pack_bar()
	if _packing_table != null and is_instance_valid(_packing_table):
		_packing_table.update_packing_visual(_pack_progress)
	if _pack_progress >= 1.0:
		_finish_packing()


func _finish_packing() -> void:
	_packing = false
	_pack_progress = 0.0
	_set_pack_bar_visible(false)
	if _packing_table != null and is_instance_valid(_packing_table):
		_packing_table.end_packing_visual()
	_packing_table = null
	var callback := _pack_callback
	_pack_callback = Callable()
	if callback.is_valid():
		callback.call()


func _build_pack_bar() -> void:
	_pack_bar_root = Node3D.new()
	_pack_bar_root.name = "PackBar"
	_pack_bar_root.position = Vector3(0.0, PACK_BAR_Y, 0.0)
	_pack_bar_root.visible = false
	add_child(_pack_bar_root)

	var bg := MeshInstance3D.new()
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(PACK_BAR_WIDTH, 0.08, 0.02)
	bg.mesh = bg_mesh
	bg.material_override = _make_bar_material(Color(0.12, 0.14, 0.18, 0.92))
	_pack_bar_root.add_child(bg)

	_pack_bar_fill = MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(PACK_BAR_WIDTH, 0.065, 0.025)
	_pack_bar_fill.mesh = fill_mesh
	_pack_bar_fill.material_override = _make_bar_material(Color(0.22, 0.82, 0.48, 1.0))
	_pack_bar_root.add_child(_pack_bar_fill)
	_update_pack_bar()


func _make_bar_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.render_priority = 5
	return mat


func _set_pack_bar_visible(visible: bool) -> void:
	if _pack_bar_root == null:
		return
	_pack_bar_root.visible = visible
	_pack_bar_root.top_level = visible
	if visible:
		_update_pack_bar_billboard()


func _update_pack_bar_billboard() -> void:
	if _pack_bar_root == null or not _pack_bar_root.visible:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	_pack_bar_root.global_position = global_position + Vector3(0.0, PACK_BAR_Y, 0.0)
	var to_camera := camera.global_position - _pack_bar_root.global_position
	if to_camera.length_squared() < 0.0001:
		return
	_pack_bar_root.look_at(_pack_bar_root.global_position + to_camera, Vector3.UP)


func _update_pack_bar() -> void:
	if _pack_bar_fill == null:
		return
	var t := clampf(_pack_progress, 0.001, 1.0)
	_pack_bar_fill.scale.x = t
	_pack_bar_fill.position.x = PACK_BAR_WIDTH * (t - 1.0) * 0.5


func _fire_arrive() -> void:
	var callback := _arrive_callback
	_arrive_callback = Callable()
	if callback.is_valid():
		callback.call()


func _advance_along_path(delta: float) -> void:
	if _path_index >= _path.size():
		_finish_walk()
		return

	var waypoint := _path[_path_index]
	var offset := waypoint - global_position
	offset.y = 0.0

	if offset.length() <= ARRIVE_DISTANCE:
		global_position = waypoint
		_path_index += 1
		if _path_index >= _path.size():
			_finish_walk()
		return

	var step := minf(WALK_SPEED * delta, offset.length())
	global_position += offset.normalized() * step
	_face_direction(offset)


func _finish_walk() -> void:
	_moving = false
	_path = PackedVector3Array()
	_path_index = 0
	_play_idle()
	_fire_arrive()
	if _pending_pack_callback.is_valid():
		var pack_cb := _pending_pack_callback
		_pending_pack_callback = Callable()
		_begin_packing(pack_cb)


func _ensure_walk_playing() -> void:
	if _anim == null or _walk_anim_name.is_empty():
		return
	if _anim.current_animation != _walk_anim_name or not _anim.is_playing():
		_play_walk()


func _clamp_to_warehouse(world_position: Vector3) -> Vector3:
	return _grid.clamp_world_to_navigable(world_position)


func _face_direction(flat_direction: Vector3) -> void:
	if flat_direction.length_squared() < 0.001:
		return
	rotation.y = atan2(flat_direction.x, flat_direction.z)


func _play_walk() -> void:
	_play_anim(_walk_anim_name, true)


func _play_idle() -> void:
	_play_anim(_idle_anim_name, true)


func _play_anim(anim_name: String, loop: bool) -> void:
	if _anim == null or anim_name.is_empty():
		return
	var animation: Animation = _anim.get_animation(anim_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if _anim.current_animation != anim_name or not _anim.is_playing():
		_anim.play(anim_name)


func _strip_model_accessories() -> void:
	var model := get_node_or_null("Model")
	if model:
		CharacterModelCleanup.strip_accessories(model)


func _swap_character_model(model_file: String) -> void:
	var path := CharacterCatalogScript.model_path(model_file)
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_warning("Worker: failed to load model %s" % path)
		return
	var old_model := get_node_or_null("Model")
	if old_model:
		old_model.queue_free()
	var mesh: Node3D = scene.instantiate()
	mesh.name = "Model"
	add_child(mesh)
	move_child(mesh, 0)
	call_deferred("_rebind_character_animations")


func _rebind_character_animations() -> void:
	_anim = CharacterAnimationUtilsScript.find_animation_player(self)
	_walk_anim_name = CharacterAnimationUtilsScript.resolve_anim_name(
		_anim, ["walk", "Walk", "run"]
	)
	_idle_anim_name = CharacterAnimationUtilsScript.resolve_anim_name(
		_anim, ["idle", "Idle", "static"]
	)
	_strip_model_accessories()
	_play_idle()


const SaveManagerScript = preload("res://scripts/gameplay/save_manager.gd")


func export_save_state() -> Dictionary:
	var stacks: Array = []
	for product_id in _stack_order:
		stacks.append({"id": product_id, "count": int(_stacks[product_id])})
	return {
		"worker_id": _worker_id,
		"id": _worker_id,
		"display_name": _display_name,
		"daily_salary": _daily_salary,
		"specialization": _specialization,
		"is_manager": _is_manager,
		"model": _model_file,
		"position": SaveManagerScript.vec3_to_array(global_position),
		"yaw": rotation_degrees.y,
		"stacks": stacks,
		"carried_boxes": _carried_boxes.duplicate(true),
		"carried_placeables": _carried_placeables.duplicate(true),
		"package_meta": _package_meta.duplicate(),
		"next_box_id": _next_box_id,
		"next_placeable_box_id": _next_placeable_box_id,
		"tasks": get_task_assignments(),
	}


func apply_save_state(data: Dictionary) -> void:
	apply_roster_profile({
		"worker_id": String(data.get("worker_id", data.get("id", _worker_id))),
		"display_name": String(data.get("display_name", _display_name)),
		"daily_salary": int(data.get("daily_salary", data.get("salary", _daily_salary))),
		"specialization": String(data.get("specialization", _specialization)),
		"is_manager": bool(data.get("is_manager", _is_manager)),
		"model": String(data.get("model", _model_file)),
	})
	_stacks.clear()
	_stack_order.clear()
	_carried_boxes.clear()
	_carried_placeables.clear()
	_package_meta = data.get("package_meta", {}).duplicate()
	_next_box_id = int(data.get("next_box_id", 1))
	_next_placeable_box_id = int(data.get("next_placeable_box_id", 1))
	for entry in data.get("stacks", []):
		var product_id := String(entry.get("id", ""))
		if product_id == "":
			continue
		_stack_order.append(product_id)
		_stacks[product_id] = int(entry.get("count", 0))
	for box in data.get("carried_boxes", []):
		_carried_boxes.append(box.duplicate())
	for placeable in data.get("carried_placeables", []):
		_carried_placeables.append(placeable.duplicate())
	global_position = SaveManagerScript.array_to_vec3(data.get("position", [0, 0, 0]))
	rotation_degrees.y = float(data.get("yaw", 0.0))
	apply_task_assignments(data.get("tasks", {}))
	_emit_inventory_changed()


