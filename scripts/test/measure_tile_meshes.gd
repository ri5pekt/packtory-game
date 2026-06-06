extends SceneTree

const KenneyMeshLoaderScript = preload("res://scripts/warehouse/kenney_mesh_loader.gd")

const PATHS := [
	"res://blender/assets/starter_kit_city/grass.glb",
	"res://blender/assets/starter_kit_city/pavement.glb",
	"res://blender/assets/starter_kit_city/road-straight.glb",
	"res://blender/assets/kenney_building-kit/Models/GLB format/floor-quarter.glb",
]


func _init() -> void:
	for path in PATHS:
		var data: Dictionary = KenneyMeshLoaderScript.load_renderable(path)
		var mesh: Mesh = data.get("mesh")
		if mesh == null:
			print("%s: NO MESH" % path)
			continue
		var aabb: AABB = mesh.get_aabb()
		print(
			"%s\n  size xz=(%.4f, %.4f) center=(%.4f, %.4f, %.4f) scale_to_1m=%.4f" % [
				path.get_file(),
				aabb.size.x,
				aabb.size.z,
				aabb.position.x + aabb.size.x * 0.5,
				aabb.position.y + aabb.size.y * 0.5,
				aabb.position.z + aabb.size.z * 0.5,
				1.0 / maxf(aabb.size.x, aabb.size.z),
			]
		)
	quit(0)
