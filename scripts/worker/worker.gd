class_name Worker
extends Node3D

signal inventory_changed(stacks: Array)

const WALK_SPEED := 3.5
const ARRIVE_DISTANCE := 0.05
# Generous carry cap so a delivery box (up to a full shelf, 10) becomes one stack,
# and products can be shuttled between shelves. Orders stay small (ORDER_MAX_UNITS).
const MAX_INVENTORY := 20
const MAX_STACK_SLOTS := 4
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
var _arrive_callback: Callable = Callable()
var _stacks: Dictionary = {}
var _stack_order: Array[String] = []

var _pack_bar_root: Node3D
var _pack_bar_fill: MeshInstance3D

@onready var selection_ring: MeshInstance3D = $SelectionRing


func _ready() -> void:
	_grid = get_node("/root/GridService") as WarehouseGrid
	_anim = _find_animation_player(self)
	_walk_anim_name = _resolve_anim_name(["walk", "Walk", "run"])
	_idle_anim_name = _resolve_anim_name(["idle", "Idle", "static"])
	add_to_group("workers")
	set_selected(false)
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
	selection_ring.visible = is_selected


func is_moving() -> bool:
	return _moving


func is_packing() -> bool:
	return _packing


func walk_to_world(world_position: Vector3, on_arrive: Callable = Callable()) -> void:
	if _packing:
		return

	_arrive_callback = on_arrive

	if _pathfinding == null:
		_fire_arrive()
		return

	var target := _clamp_to_warehouse(world_position)
	target.y = global_position.y

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


func start_packing(on_complete: Callable = Callable()) -> void:
	if _packing or _moving:
		return
	_packing = true
	_pack_progress = 0.0
	_pack_callback = on_complete
	_set_pack_bar_visible(true)
	_update_pack_bar()
	_play_idle()


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
		stacks.append({"id": product_id, "count": int(_stacks[product_id])})
	return stacks


func get_total_units() -> int:
	var total := 0
	for product_id in _stacks:
		total += int(_stacks[product_id])
	return total


func count_product(product_id: String) -> int:
	return int(_stacks.get(product_id, 0))


func is_inventory_full() -> bool:
	return get_total_units() >= MAX_INVENTORY


func has_product(product_id: String) -> bool:
	return count_product(product_id) > 0


func has_package() -> bool:
	return has_product("package")


func add_product(product_id: String) -> bool:
	if is_inventory_full():
		return false
	if has_package() and product_id != "package":
		return false
	if product_id == "package" and get_total_units() > 0:
		return false
	if not _stacks.has(product_id) and _stack_order.size() >= MAX_STACK_SLOTS:
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
	_emit_inventory_changed()
	return true


func free_capacity() -> int:
	return MAX_INVENTORY - get_total_units()


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
	if not ProductCatalog.inventory_fulfills_order(get_inventory(), order):
		return false
	var saved_order := _stack_order.duplicate()
	var saved_stacks := _stacks.duplicate()
	for product_id in order:
		for _i in order[product_id]:
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
	for product_id in order:
		for _i in order[product_id]:
			add_product(String(product_id))


func _advance_packing(delta: float) -> void:
	_pack_progress = minf(_pack_progress + delta / PACK_DURATION, 1.0)
	_update_pack_bar()
	if _pack_progress >= 1.0:
		_finish_packing()


func _finish_packing() -> void:
	_packing = false
	_pack_progress = 0.0
	_set_pack_bar_visible(false)
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
		global_position.x = waypoint.x
		global_position.z = waypoint.z
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


func _resolve_anim_name(preferred_names: Array[String]) -> String:
	if _anim == null:
		return ""
	for anim_name in preferred_names:
		if _anim.has_animation(anim_name):
			return anim_name
	var list := _anim.get_animation_list()
	if list.is_empty():
		return ""
	return list[0]


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
