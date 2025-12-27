@tool
extends EditorScenePostImport

# --- НАСТРОЙКИ ---
const SAVE_PATH = "res://entities/environment/trees_generated/"
const COL_SUFFIX = "_col"
const TOP_SUFFIX = "_top"
const GENERATOR_SCRIPT_PATH = "res://common/utils/tree_generator.gd"
const LEAF_MESH_PATH = "res://assets/models/environment/LeafBasePlane.tres" 

const LEAF_COUNT_TREE = 1200          
const LEAF_COUNT_BUSH = 400
const LEAF_COLOR = Color(1, 1, 1, 1)

const OCCLUSION_LAYER_NUMBER = 32
const TREE_LAYER_NUMBER = 4
const TREE_MASK_UP_TO_LAYER = 6 

func _post_import(scene_root_node: Node) -> Object:
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(SAVE_PATH):
		dir.make_dir_recursive(SAVE_PATH)

	var all_meshes = {}
	var all_nodes = _get_all_children(scene_root_node)
	
	for node in all_nodes:
		if node is MeshInstance3D:
			all_meshes[node.name] = node

	for mesh_name in all_meshes:
		if mesh_name.ends_with(COL_SUFFIX) or mesh_name.ends_with(TOP_SUFFIX):
			continue
		
		var is_tree = mesh_name.begins_with("Tree")
		var is_bush = mesh_name.begins_with("Bush")
		
		if not is_tree and not is_bush:
			continue
			
		var main_node = all_meshes[mesh_name]
		var col_node = all_meshes.get(mesh_name + COL_SUFFIX)
		var top_node = all_meshes.get(mesh_name + TOP_SUFFIX)
		
		_create_and_save_scene(main_node, top_node, col_node, is_bush)

	return scene_root_node

func _create_and_save_scene(main_source: MeshInstance3D, top_source: MeshInstance3D, col_source: MeshInstance3D, is_bush: bool):
	var file_path = SAVE_PATH + main_source.name + ".tscn"
	
	# Создаем всегда новый StaticBody, чтобы собрать его с нуля чисто
	var root_node = StaticBody3D.new()
	root_node.name = main_source.name
	
	root_node.collision_layer = 1 << (TREE_LAYER_NUMBER - 1)
	var mask_val = 0
	for i in range(TREE_MASK_UP_TO_LAYER): mask_val += 1 << i
	root_node.collision_mask = mask_val
	
	# --- ГЕОМЕТРИЯ ---
	if is_bush:
		var crown_inst = _create_mesh_node(root_node, "Crown")
		crown_inst.mesh = main_source.mesh.duplicate()
		crown_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	else:
		var trunk_inst = _create_mesh_node(root_node, "Trunk")
		trunk_inst.mesh = main_source.mesh.duplicate()
		trunk_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		
		if top_source:
			var crown_inst = _create_mesh_node(root_node, "Crown")
			crown_inst.mesh = top_source.mesh.duplicate()
			crown_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	
	# --- КОЛЛИЗИЯ ---
	var shape = null
	if not is_bush and col_source:
		# Пытаемся найти шейп в суффиксе _col
		for child in col_source.get_children():
			if child is CollisionShape3D: shape = child.shape; break
			if child.get_child_count() > 0 and child.get_child(0) is CollisionShape3D:
				shape = child.get_child(0).shape; break
		if not shape: shape = col_source.mesh.create_convex_shape()
	elif not is_bush:
		shape = main_source.mesh.create_convex_shape()
	
	if shape:
		var col_node = CollisionShape3D.new()
		col_node.name = "CollisionShape3D"
		col_node.shape = shape
		root_node.add_child(col_node)
		col_node.owner = root_node

	# --- OCCLUSION VOLUME ---
	var occ_vol = Area3D.new()
	occ_vol.name = "OcclusionVolume"
	occ_vol.collision_layer = 1 << (OCCLUSION_LAYER_NUMBER - 1)
	occ_vol.collision_mask = 0 
	root_node.add_child(occ_vol)
	occ_vol.owner = root_node
	
	var occ_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	
	if is_bush:
		var aabb = main_source.mesh.get_aabb()
		sphere.radius = max(aabb.get_longest_axis_size() * 0.8, 1.5)
		occ_shape.position = Vector3(0, max(aabb.get_center().y, 1.0), 0)
	elif top_source:
		var aabb = top_source.mesh.get_aabb()
		sphere.radius = max(aabb.get_longest_axis_size() * 0.7, 3.0)
		# Центрируем по кроне
		occ_shape.position = Vector3(0, 3.5, 0) # Дефолт
	else:
		sphere.radius = 3.0
		occ_shape.position = Vector3(0, 3.5, 0)
		
	occ_shape.shape = sphere
	occ_vol.add_child(occ_shape)
	occ_shape.owner = root_node

	# --- СКРИПТ И ГЕНЕРАЦИЯ ---
	var gen_script = load(GENERATOR_SCRIPT_PATH)
	if gen_script:
		root_node.set_script(gen_script)
		
		# Задаем параметры
		var leaf_mesh_res = load(LEAF_MESH_PATH)
		if leaf_mesh_res: root_node.leaf_mesh = leaf_mesh_res
		root_node.leaf_count = LEAF_COUNT_BUSH if is_bush else LEAF_COUNT_TREE
		root_node.leaf_color = LEAF_COLOR
		
		# !!! ГЛАВНОЕ: Генерируем листья ПРЯМО СЕЙЧАС !!!
		# Это создаст MultiMeshInstance3D и наполнит его данными
		if root_node.has_method("generate_leaves"):
			root_node.generate_leaves()

	# --- СОХРАНЕНИЕ ---
	var new_packed = PackedScene.new()
	var err = new_packed.pack(root_node)
	if err == OK:
		ResourceSaver.save(new_packed, file_path)
		print("Saved generated tree: ", file_path)
	else:
		printerr("Failed to pack scene: ", main_source.name)
		
	root_node.queue_free()

func _create_mesh_node(parent: Node, node_name: String) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = node_name
	parent.add_child(node)
	node.owner = parent
	return node

func _get_all_children(node: Node, result: Array = []) -> Array:
	result.push_back(node)
	for child in node.get_children():
		_get_all_children(child, result)
	return result
