class_name KenneyMeshLoader
extends RefCounted


static func load_renderable(path: String) -> Dictionary:
	var resource: Resource = load(path)
	if resource is Mesh:
		return {"mesh": resource, "material": null}

	if resource is PackedScene:
		var sample: Node = (resource as PackedScene).instantiate()
		var mesh_instance := _find_mesh_instance(sample)
		if mesh_instance == null:
			sample.free()
			push_error("KenneyMeshLoader: no MeshInstance3D in %s" % path)
			return {}

		var data := {
			"mesh": mesh_instance.mesh,
			"material": _resolve_material(mesh_instance),
		}
		sample.free()
		return data

	push_error("KenneyMeshLoader: could not load renderable from %s" % path)
	return {}


static func load_mesh(path: String) -> Mesh:
	return load_renderable(path).get("mesh")


static func mesh_with_material(mesh: Mesh, material: Material) -> Mesh:
	if mesh == null or material == null:
		return mesh
	var copy := mesh.duplicate() as Mesh
	if copy.get_surface_count() > 0:
		copy.surface_set_material(0, material)
	return copy


static func _resolve_material(mesh_instance: MeshInstance3D) -> Material:
	var mesh := mesh_instance.mesh
	if mesh and mesh.get_surface_count() > 0:
		var surface_material := mesh.surface_get_material(0)
		if surface_material:
			return surface_material
	return mesh_instance.get_active_material(0)


static func _find_mesh_instance(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for child in root.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null
