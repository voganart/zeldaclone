@tool
extends EditorScenePostImport

# --- НАСТРОЙКИ ---
const SPAWN_MATERIAL_NAME = "GENERATE_LEAVES"
const LEAF_MESH_PATH = "res://assets/models/environment/WallFoliagePlane.tres"

const LEAF_COUNT_PER_TRIANGLE = 2
const LEAF_SCALE_MIN = 0.5
const LEAF_SCALE_MAX = 0.8
const PUSH_OUT = 0.05

# --- НАСТРОЙКИ ПОВОРОТА ---
# На сколько градусов опустить листья вниз (эффект гравитации/свисания)
# 0 = Перпендикулярно стене (торчат)
# 60-70 = Сильно свисают (почти параллельно стене)
const GRAVITY_TILT_MIN = 60.0 
const GRAVITY_TILT_MAX = 75.0

# Случайный наклон влево/вправо и вращение вокруг оси (хаос)
const RANDOM_SIDE_TILT = 0.1
const RANDOM_SPIN = 0.1 # Полный оборот = TAU (6.28), тут ставим поменьше

func _post_import(scene_root_node: Node) -> Object:
	var raw_leaf_mesh = load(LEAF_MESH_PATH)
	if not raw_leaf_mesh:
		printerr("ERROR: Leaf mesh not found!")
		return scene_root_node

	var leaf_mesh_array = _ensure_array_mesh(raw_leaf_mesh)
	var leaf_mat = leaf_mesh_array.surface_get_material(0)
	
	var nodes = _get_all_mesh_instances(scene_root_node)
	print("Processing Foliage Import on ", nodes.size(), " nodes...")
	
	for node in nodes:
		_process_node(node, leaf_mesh_array, leaf_mat)
		
	return scene_root_node

func _process_node(node: MeshInstance3D, leaf_mesh: ArrayMesh, final_leaf_mat: Material):
	var mesh = node.mesh
	if not (mesh is ArrayMesh): return

	var surf_count = mesh.get_surface_count()
	var marker_surface_idx = -1
	
	for i in range(surf_count):
		var mat = mesh.surface_get_material(i)
		var mat_name = ""
		if mat: mat_name = mat.resource_name
		
		if (mat_name == "" and mesh.surface_get_name(i).begins_with(SPAWN_MATERIAL_NAME)) or mat_name.begins_with(SPAWN_MATERIAL_NAME):
			marker_surface_idx = i
			break
			
	if marker_surface_idx == -1: return

	print("Found foliage marker on: ", node.name)

	var aabb = mesh.get_aabb()
	var min_y = aabb.position.y
	var height = aabb.size.y
	if height < 0.1: height = 1.0

	var mdt = MeshDataTool.new()
	mdt.create_from_surface(mesh, marker_surface_idx)
	
	var leaves_st = _generate_leaves_geometry(mdt, leaf_mesh, min_y, height)
	if final_leaf_mat:
		leaves_st.set_material(final_leaf_mat)

	var new_mesh = ArrayMesh.new()
	for i in range(surf_count):
		if i == marker_surface_idx: continue 
		
		var arrays = mesh.surface_get_arrays(i)
		var flags = mesh.surface_get_format(i)
		var mat = mesh.surface_get_material(i)
		var name = mesh.surface_get_name(i)
		
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, mat)
		new_mesh.surface_set_name(new_mesh.get_surface_count() - 1, name)
	
	leaves_st.commit(new_mesh)
	node.mesh = new_mesh

func _generate_leaves_geometry(source_mdt: MeshDataTool, leaf_mesh: ArrayMesh, wall_min_y: float, wall_height: float) -> SurfaceTool:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var leaf_mdt = MeshDataTool.new()
	leaf_mdt.create_from_surface(leaf_mesh, 0) 
	var leaf_verts_count = leaf_mdt.get_vertex_count()
	var face_count = source_mdt.get_face_count()
	var total_leaves = 0
	
	for f in range(face_count):
		var v1 = source_mdt.get_vertex(source_mdt.get_face_vertex(f, 0))
		var v2 = source_mdt.get_vertex(source_mdt.get_face_vertex(f, 1))
		var v3 = source_mdt.get_vertex(source_mdt.get_face_vertex(f, 2))
		var normal = source_mdt.get_face_normal(f)
		
		for l in range(LEAF_COUNT_PER_TRIANGLE):
			var r1 = randf(); var r2 = randf()
			if r1 + r2 > 1.0: r1 = 1.0 - r1; r2 = 1.0 - r2
			
			var pos = v1 + (v2 - v1) * r1 + (v3 - v1) * r2
			pos += normal * PUSH_OUT
			
			var height_gradient = clamp((pos.y - wall_min_y) / wall_height, 0.0, 1.0)
			var random_depth = randf_range(0.3, 1.0)
			var baked_color = Color(random_depth, 0.0, 0.0, height_gradient)
			
			var t = Transform3D()
			t.origin = pos
			
			# 1. Ориентируем базу по нормали стены (ось Z смотрит от стены)
			if abs(normal.y) < 0.99: t = t.looking_at(pos + normal, Vector3.UP)
			else: t = t.looking_at(pos + normal, Vector3.RIGHT)
			
			# 2. Основной поворот:
			# -90.0 делает их перпендикулярными (как раньше).
			# Вычитаем GRAVITY_TILT, чтобы опустить их вниз.
			var tilt_angle = -90.0 - randf_range(GRAVITY_TILT_MIN, GRAVITY_TILT_MAX)
			t = t.rotated_local(Vector3(1, 0, 0), deg_to_rad(tilt_angle))
			
			# 3. Случайный наклон влево/вправо (чтобы не было как под линейку)
			t = t.rotated_local(Vector3(0, 0, 1), randf_range(-RANDOM_SIDE_TILT, RANDOM_SIDE_TILT))
			
			# 4. Случайный поворот вокруг своей оси (разнообразие текстуры)
			t = t.rotated_local(Vector3(0, 1, 0), randf_range(-RANDOM_SPIN, RANDOM_SPIN))
			
			var s = randf_range(LEAF_SCALE_MIN, LEAF_SCALE_MAX)
			t = t.scaled_local(Vector3(s, s, s))
			
			for k in range(leaf_verts_count):
				var lv = leaf_mdt.get_vertex(k)
				var ln = leaf_mdt.get_vertex_normal(k)
				var luv = leaf_mdt.get_vertex_uv(k)
				
				st.set_normal(t.basis * ln)
				st.set_uv(luv)
				st.set_color(baked_color) 
				st.add_vertex(t * lv)
			
			var idx_offset = total_leaves * leaf_verts_count
			for lf in range(leaf_mdt.get_face_count()):
				st.add_index(idx_offset + leaf_mdt.get_face_vertex(lf, 0))
				st.add_index(idx_offset + leaf_mdt.get_face_vertex(lf, 1))
				st.add_index(idx_offset + leaf_mdt.get_face_vertex(lf, 2))
			
			total_leaves += 1
			
	return st

func _ensure_array_mesh(source_mesh: Mesh) -> ArrayMesh:
	if source_mesh is ArrayMesh: return source_mesh
	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source_mesh.get_mesh_arrays())
	if source_mesh.get_material(): arr_mesh.surface_set_material(0, source_mesh.get_material())
	return arr_mesh

func _get_all_mesh_instances(node: Node, result: Array = []) -> Array:
	if node is MeshInstance3D: result.push_back(node)
	for child in node.get_children(): _get_all_mesh_instances(child, result)
	return result
