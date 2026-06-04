import bpy
from mathutils import Vector

for name in ["Corner_NW", "Wall_W_1", "Wall_N_1", "Floor_0_0"]:
	obj = bpy.data.objects.get(name)
	if not obj:
		continue
	bb = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
	xs = [p.x for p in bb]
	zs = [p.z for p in bb]
	print(
		name,
		"x",
		round(min(xs), 2),
		round(max(xs), 2),
		"z",
		round(min(zs), 2),
		round(max(zs), 2),
		"rot",
		round(obj.rotation_euler.y * 57.2958, 1),
	)
