extends SceneTree

const PATHS := [
	"res://blender/assets/kenney_mini-characters/Models/GLB format/character-female-a.glb",
	"res://blender/assets/kenney_mini-characters/Models/GLB format/character-male-c.glb",
	"res://blender/assets/kenney_mini-market/Models/GLB format/character-employee.glb",
]


func _init() -> void:
	for path in PATHS:
		print("\n=== ", path, " ===")
		var scene: PackedScene = load(path)
		var model: Node = scene.instantiate()
		root.add_child(model)
		_walk(model, 0)
		model.queue_free()
	quit(0)


func _walk(node: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat_info := "no-mat"
		var mat := mi.get_active_material(0)
		if mat == null and mi.mesh:
			mat = mi.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			mat_info = "std tex=%s albedo=%s" % [
				sm.albedo_texture != null,
				sm.albedo_color,
			]
		print("%s%s mesh=%s mat=%s" % [pad, node.name, mi.mesh != null, mat_info])
	elif node is AnimationPlayer:
		print("%s%s anims=%s" % [pad, node.name, (node as AnimationPlayer).get_animation_list()])
	else:
		print("%s%s (%s)" % [pad, node.name, node.get_class()])
	for child in node.get_children():
		_walk(child, depth + 1)
