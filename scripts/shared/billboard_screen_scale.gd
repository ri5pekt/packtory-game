class_name BillboardScreenScale
extends RefCounted

## Keeps billboard Sprite3D / Label3D badges the same on-screen size when the
## orthographic camera zoom (`Camera3D.size`) changes.

const REFERENCE_ORTHO_SIZE := 18.0
## Multiplier for on-screen size of 3D shelf/box/van labels (zoom compensation still applies).
const WORLD_LABEL_READABILITY := 2.45

static var _cached_camera_size := -1.0
static var _cached_reference_size := -1.0
static var _cached_factor := 1.0


static func reference_ortho_size(tree: SceneTree) -> float:
	if tree == null:
		return REFERENCE_ORTHO_SIZE
	var rig := tree.get_first_node_in_group("camera_rig")
	if rig != null and rig.has_method("get_reference_ortho_size"):
		return maxf(0.001, float(rig.get_reference_ortho_size()))
	return REFERENCE_ORTHO_SIZE


static func gameplay_camera(tree: SceneTree) -> Camera3D:
	if tree == null:
		return null
	var rig := tree.get_first_node_in_group("camera_rig")
	if rig != null and rig.has_method("get_camera"):
		return rig.get_camera() as Camera3D
	return null


static func get_factor(tree: SceneTree) -> float:
	var camera := gameplay_camera(tree)
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return 1.0
	var reference := reference_ortho_size(tree)
	if (
		is_equal_approx(camera.size, _cached_camera_size)
		and is_equal_approx(reference, _cached_reference_size)
	):
		return _cached_factor
	_cached_camera_size = camera.size
	_cached_reference_size = reference
	_cached_factor = camera.size / reference
	return _cached_factor


static func scaled_pixel_size(base: float, tree: SceneTree) -> float:
	return base * get_factor(tree)


static func scaled_vector(base: Vector3, tree: SceneTree) -> Vector3:
	return base * get_factor(tree)


static func scaled_font_size(base: int, tree: SceneTree) -> int:
	return maxi(8, int(round(float(base) * get_factor(tree))))
