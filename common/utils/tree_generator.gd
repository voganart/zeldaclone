@tool
extends Node3D

@export_category("Leaf Generation")
@export var leaf_mesh: Mesh
@export var leaf_count: int = 500
@export var leaf_scale_min: float = 0.8
@export var leaf_scale_max: float = 1.4
@export var leaf_color: Color = Color.RED
@export var random_tilt: float = 0.5

@export_category("Actions")
@export var regenerate: bool = false:
	set(value):
		if value:
			generate_leaves()
		regenerate = false

func generate_leaves():
	var crown = get_node_or_null("Crown")
	if not crown:
		print("Error: Crown node not found!")
		return
		
	var multimesh_inst = crown.get_node_or_null("LeavesMultiMesh")
	if not multimesh_inst:
		multimesh_inst = MultiMeshInstance3D.new()
		multimesh_inst.name = "LeavesMultiMesh"
		crown.add_child(multimesh_inst)
		multimesh_inst.owner = self.owner if self.owner else self

	if not leaf_mesh:
		print("Error: Assign a Leaf Mesh!")
		return

	var multimesh = multimesh_inst.multimesh
	if not multimesh: multimesh = MultiMesh.new()
	
	# Сброс
	multimesh.instance_count = 0
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	
	# !!! ИЗМЕНЕНИЕ: Отключаем цвета инстансов, чтобы работал Vertex Paint меша !!!
	multimesh.use_colors = false 
	
	multimesh.mesh = leaf_mesh
	multimesh.instance_count = leaf_count
	
	# Данные меша
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(crown.mesh, 0)
	
	if mdt.get_vertex_count() == 0: return

	for i in range(leaf_count):
		var face_idx = randi() % mdt.get_face_count()
		var v1 = mdt.get_vertex(mdt.get_face_vertex(face_idx, 0))
		var v2 = mdt.get_vertex(mdt.get_face_vertex(face_idx, 1))
		var v3 = mdt.get_vertex(mdt.get_face_vertex(face_idx, 2))
		
		var r1 = randf()
		var r2 = randf()
		if r1 + r2 > 1.0:
			r1 = 1.0 - r1
			r2 = 1.0 - r2
		var pos = v1 + (v2 - v1) * r1 + (v3 - v1) * r2
		var normal = mdt.get_face_normal(face_idx)
		
		var t = Transform3D()
		t.origin = pos
		
		# Ориентация
		if abs(normal.y) < 0.99: t = t.looking_at(pos + normal, Vector3.UP)
		else: t = t.looking_at(pos + normal, Vector3.RIGHT)
		
		# Поворот для PlaneMesh
		t = t.rotated_local(Vector3(1, 0, 0), -PI * 0.5)
		
		# Хаос наклона
		t = t.rotated_local(Vector3(1, 0, 0), randf_range(-random_tilt, random_tilt))
		t = t.rotated_local(Vector3(0, 0, 1), randf_range(-random_tilt, random_tilt))
		
		# Рандом вокруг оси
		t = t.rotated_local(Vector3(0, 1, 0), randf() * TAU)
		
		var s = randf_range(leaf_scale_min, leaf_scale_max)
		t = t.scaled_local(Vector3(s, s, s))
		
		multimesh.set_instance_transform(i, t)
		
		# !!! ИЗМЕНЕНИЕ: Мы отключили use_colors, поэтому эту строку убираем !!!
		# multimesh.set_instance_color(i, leaf_color)
	
	multimesh_inst.multimesh = multimesh
	print("Leaves Generated: ", leaf_count)
