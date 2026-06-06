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


static func mesh_clipped_to_max_y(source: Mesh, max_y: float) -> Mesh:
	if source == null or source.get_surface_count() == 0:
		return source

	var arrays: Array = source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty():
		return source

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	if indices.is_empty():
		for i in range(0, vertices.size(), 3):
			if _triangle_within_y(vertices, i, i + 1, i + 2, max_y):
				_add_triangle(st, vertices, normals, uvs, i, i + 1, i + 2)
	else:
		for i in range(0, indices.size(), 3):
			var i0 := indices[i]
			var i1 := indices[i + 1]
			var i2 := indices[i + 2]
			if (
				vertices[i0].y <= max_y
				and vertices[i1].y <= max_y
				and vertices[i2].y <= max_y
			):
				_add_triangle(st, vertices, normals, uvs, i0, i1, i2)

	var clipped := st.commit()
	if clipped.get_surface_count() == 0:
		return source
	return clipped


static func _triangle_within_y(vertices: PackedVector3Array, i0: int, i1: int, i2: int, max_y: float) -> bool:
	return vertices[i0].y <= max_y and vertices[i1].y <= max_y and vertices[i2].y <= max_y


static func _add_triangle(
	st: SurfaceTool,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	i0: int,
	i1: int,
	i2: int
) -> void:
	for index in [i0, i1, i2]:
		if not normals.is_empty() and index < normals.size():
			st.set_normal(normals[index])
		if not uvs.is_empty() and index < uvs.size():
			st.set_uv(uvs[index])
		st.add_vertex(vertices[index])


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
