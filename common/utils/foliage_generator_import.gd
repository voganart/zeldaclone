@tool
extends EditorScenePostImport

# --- НАСТРОЙКИ ---
const MARKER_PREFIX = "GENERATE_"
const FOLIAGE_CONFIG_PATH = "res://entities/environment/foliage_types/"

func _post_import(scene_root_node: Node) -> Object:
	var nodes = _get_all_mesh_instances(scene_root_node)
	print("Foliage Generator: Processing ", nodes.size(), " nodes...")
	
	for node in nodes:
		_process_node(node)
		
	return scene_root_node

func _process_node(node: MeshInstance3D):
	var mesh = node.mesh
	if not (mesh is ArrayMesh): return

	var new_mesh = ArrayMesh.new()
	var did_generate = false

	for i in range(mesh.get_surface_count()):
		var mat = mesh.surface_get_material(i)
		var mat_name = ""
		if mat: mat_name = mat.resource_name
		
		if mat_name.begins_with(MARKER_PREFIX):
			did_generate = true
			var foliage_type_name = mat_name.trim_prefix(MARKER_PREFIX)
			var config_path = FOLIAGE_CONFIG_PATH + foliage_type_name + ".tres"
			
			var foliage_type: FoliageType = load(config_path)
			
			if not foliage_type:
				printerr("Foliage Generator ERROR: Cannot load FoliageType resource at: ", config_path)
				_add_original_surface(new_mesh, mesh, i)
				continue

			print("Found marker '", mat_name, "'. Generating foliage on: ", node.name)
			
			var mdt = MeshDataTool.new()
			mdt.create_from_surface(mesh, i)
			
			var leaves_st = _generate_foliage_geometry(mdt, foliage_type, mesh)
			
			if leaves_st and foliage_type.mesh_to_spawn:
				var leaf_mesh_array = _ensure_array_mesh(foliage_type.mesh_to_spawn)
				if leaf_mesh_array and leaf_mesh_array.surface_get_material(0):
					leaves_st.set_material(leaf_mesh_array.surface_get_material(0))

			if leaves_st:
				leaves_st.commit(new_mesh)
		else:
			_add_original_surface(new_mesh, mesh, i)
	
	if did_generate:
		node.mesh = new_mesh

func _generate_foliage_geometry(source_mdt: MeshDataTool, config: FoliageType, source_mesh: ArrayMesh) -> SurfaceTool:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	if not config.mesh_to_spawn:
		printerr("Foliage Generator ERROR: 'mesh_to_spawn' is not set in the FoliageType resource!")
		return null
		
	var leaf_mesh_array = _ensure_array_mesh(config.mesh_to_spawn)
	if not leaf_mesh_array:
		return null
		
	var leaf_mdt = MeshDataTool.new()
	leaf_mdt.create_from_surface(leaf_mesh_array, 0) 
	var leaf_verts_count = leaf_mdt.get_vertex_count()
	
	var aabb = source_mesh.get_aabb()
	var min_y = aabb.position.y
	var height = aabb.size.y
	if height < 0.1: height = 1.0
	
	var total_leaves = 0
	for f in range(source_mdt.get_face_count()):
		var v1 = source_mdt.get_vertex(source_mdt.get_face_vertex(f, 0))
		var v2 = source_mdt.get_vertex(source_mdt.get_face_vertex(f, 1))
		var v3 = source_mdt.get_vertex(source_mdt.get_face_vertex(f, 2))
		var normal = source_mdt.get_face_normal(f)
		
		for l in range(config.count_per_triangle):
			var r1 = randf(); var r2 = randf()
			if r1 + r2 > 1.0: r1 = 1.0 - r1; r2 = 1.0 - r2
			
			var pos = v1 + (v2 - v1) * r1 + (v3 - v1) * r2
			pos += normal * config.push_out_from_surface
			
			var height_gradient = clamp((pos.y - min_y) / height, 0.0, 1.0)
			var random_depth = randf_range(0.3, 1.0)
			var baked_color = Color(random_depth, 0.0, 0.0, height_gradient)
			
			var t = Transform3D()
			t.origin = pos
			if abs(normal.y) < 0.99: t = t.looking_at(pos + normal, Vector3.UP)
			else: t = t.looking_at(pos + normal, Vector3.RIGHT)
			
			var tilt_angle = -90.0 - randf_range(config.gravity_tilt_min, config.gravity_tilt_max)
			t = t.rotated_local(Vector3(1, 0, 0), deg_to_rad(tilt_angle))
			t = t.rotated_local(Vector3(0, 0, 1), randf_range(-config.random_side_tilt, config.random_side_tilt))
			t = t.rotated_local(Vector3(0, 1, 0), randf_range(-config.random_spin, config.random_spin))
			
			var s = randf_range(config.scale_min, config.scale_max)
			t = t.scaled_local(Vector3(s, s, s))
			
			for k in range(leaf_verts_count):
				st.set_normal(t.basis * leaf_mdt.get_vertex_normal(k))
				st.set_uv(leaf_mdt.get_vertex_uv(k))
				st.set_color(baked_color) 
				st.add_vertex(t * leaf_mdt.get_vertex(k))
			
			var idx_offset = total_leaves * leaf_verts_count
			for lf in range(leaf_mdt.get_face_count()):
				st.add_index(idx_offset + leaf_mdt.get_face_vertex(lf, 0))
				st.add_index(idx_offset + leaf_mdt.get_face_vertex(lf, 1))
				st.add_index(idx_offset + leaf_mdt.get_face_vertex(lf, 2))
			
			total_leaves += 1
			
	return st

func _add_original_surface(new_mesh: ArrayMesh, old_mesh: ArrayMesh, surface_idx: int):
	var arrays = old_mesh.surface_get_arrays(surface_idx)
	var flags = old_mesh.surface_get_format(surface_idx)
	var mat = old_mesh.surface_get_material(surface_idx)
	var name = old_mesh.surface_get_name(surface_idx)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, mat)
	new_mesh.surface_set_name(new_mesh.get_surface_count() - 1, name)

func _ensure_array_mesh(source_mesh: Mesh) -> ArrayMesh:
	if source_mesh is ArrayMesh: return source_mesh
	if source_mesh is PrimitiveMesh:
		var arr_mesh = ArrayMesh.new()
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source_mesh.get_mesh_arrays())
		if source_mesh.material: arr_mesh.surface_set_material(0, source_mesh.material)
		return arr_mesh
	printerr("Foliage Generator ERROR: Unsupported mesh type: ", source_mesh.get_class())
	return null

func _get_all_mesh_instances(node: Node, result: Array = []) -> Array:
	if node is MeshInstance3D: result.push_back(node)
	for child in node.get_children(): _get_all_mesh_instances(child, result)
	return result
