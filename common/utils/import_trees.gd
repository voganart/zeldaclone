@tool
extends EditorScenePostImport

# --- НАСТРОЙКИ ---
const SAVE_PATH = "res://entities/environment/trees_generated/"
const COL_SUFFIX = "_col"
const TOP_SUFFIX = "_top"
const GENERATOR_SCRIPT_PATH = "res://common/utils/tree_generator.gd"
const LEAF_MESH_PATH = "res://assets/models/environment/LeafBasePlane.tres" 
const LEAF_COUNT_TREE = 1000          
const LEAF_COUNT_BUSH = 300
const LEAF_SCALE_MIN = 0.8
const LEAF_SCALE_MAX = 1.0
const LEAF_COLOR = Color.RED

# Коллизии
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
		# Пропускаем служебные меши
		if mesh_name.ends_with(COL_SUFFIX) or mesh_name.ends_with(TOP_SUFFIX):
			continue
		
		var is_tree = mesh_name.begins_with("Tree")
		var is_bush = mesh_name.begins_with("Bush")
		
		if not is_tree and not is_bush:
			continue
			
		var main_node = all_meshes[mesh_name]
		var col_node = all_meshes.get(mesh_name + COL_SUFFIX)
		var top_node = all_meshes.get(mesh_name + TOP_SUFFIX)
		
		_update_or_create_scene(main_node, top_node, col_node, is_bush)

	return scene_root_node

func _update_or_create_scene(main_source: MeshInstance3D, top_source: MeshInstance3D, col_source: MeshInstance3D, is_bush: bool):
	var file_path = SAVE_PATH + main_source.name + ".tscn"
	var root_node: StaticBody3D
	var packed_scene: PackedScene
	
	if FileAccess.file_exists(file_path):
		print("Updating object: ", main_source.name)
		packed_scene = load(file_path)
		if packed_scene:
			root_node = packed_scene.instantiate()
	
	if not root_node:
		print("Creating NEW object: ", main_source.name)
		root_node = StaticBody3D.new()
		root_node.name = main_source.name
	
	# Слой выставляем, но для кустов он не будет работать, так как нет шейпа (что и требовалось)
	root_node.collision_layer = 1 << (TREE_LAYER_NUMBER - 1)
	var mask_val = 0
	for i in range(TREE_MASK_UP_TO_LAYER):
		mask_val += 1 << i
	root_node.collision_mask = mask_val
	
	# --- ГЕОМЕТРИЯ ---
	if is_bush:
		# КУСТ: только Crown, Shadows Only
		var crown_inst = root_node.get_node_or_null("Crown")
		if not crown_inst:
			crown_inst = MeshInstance3D.new()
			crown_inst.name = "Crown"
			root_node.add_child(crown_inst)
			crown_inst.owner = root_node
		
		crown_inst.mesh = main_source.mesh.duplicate()
		crown_inst.transform = Transform3D.IDENTITY
		# ИЗМЕНЕНИЕ: Тени как у деревьев
		crown_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY 
		
	else:
		# ДЕРЕВО: Trunk + Crown
		var trunk_inst = root_node.get_node_or_null("Trunk")
		if not trunk_inst:
			trunk_inst = MeshInstance3D.new()
			trunk_inst.name = "Trunk"
			root_node.add_child(trunk_inst)
			trunk_inst.owner = root_node
		trunk_inst.mesh = main_source.mesh.duplicate()
		trunk_inst.transform = Transform3D.IDENTITY
		
		if top_source:
			var crown_inst = root_node.get_node_or_null("Crown")
			if not crown_inst:
				crown_inst = MeshInstance3D.new()
				crown_inst.name = "Crown"
				root_node.add_child(crown_inst)
				crown_inst.owner = root_node
			crown_inst.mesh = top_source.mesh.duplicate()
			crown_inst.transform = Transform3D.IDENTITY
			crown_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			top_source.visible = false
	
	# --- КОЛЛИЗИЯ SHAPE ---
	
	# Удаляем старую коллизию всегда (чтобы убрать её у кустов при переимпорте)
	var old_col = root_node.get_node_or_null("CollisionShape3D")
	if old_col: old_col.free()
	
	# ИЗМЕНЕНИЕ: Создаем новую только если это НЕ куст
	if not is_bush:
		var shape = null
		if col_source:
			for child in col_source.get_children():
				if child is StaticBody3D:
					for grandchild in child.get_children():
						if grandchild is CollisionShape3D:
							shape = grandchild.shape
							break
				if shape: break
			if not shape: shape = col_source.mesh.create_convex_shape()
			col_source.visible = false
		else:
			shape = main_source.mesh.create_convex_shape()
		
		if shape:
			var col_node = CollisionShape3D.new()
			col_node.name = "CollisionShape3D"
			col_node.shape = shape
			root_node.add_child(col_node)
			col_node.owner = root_node

	# --- OCCLUSION VOLUME (Area3D) ---
	# Зона прозрачности нужна и кустам, и деревьям
	var occ_vol = root_node.get_node_or_null("OcclusionVolume")
	if occ_vol: occ_vol.free() 
	
	occ_vol = Area3D.new()
	occ_vol.name = "OcclusionVolume"
	occ_vol.collision_layer = 1 << (OCCLUSION_LAYER_NUMBER - 1)
	occ_vol.collision_mask = 0 
	
	root_node.add_child(occ_vol)
	occ_vol.owner = root_node
	
	var occ_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	
	if is_bush:
		var aabb = main_source.mesh.get_aabb()
		sphere.radius = aabb.get_longest_axis_size() * 0.5
		occ_shape.position = Vector3(0, aabb.get_center().y, 0)
	elif top_source:
		var aabb = top_source.mesh.get_aabb()
		sphere.radius = aabb.get_longest_axis_size() * 0.6
		occ_shape.position = top_source.position + Vector3(0, aabb.get_center().y, 0)
	else:
		sphere.radius = 2.5
		occ_shape.position = Vector3(0, 3.0, 0)
		
	occ_shape.shape = sphere
	occ_vol.add_child(occ_shape)
	occ_shape.owner = root_node
	
	# --- СКРИПТ ГЕНЕРАЦИИ ---
	var gen_script = load(GENERATOR_SCRIPT_PATH)
	if gen_script:
		if root_node.get_script() != gen_script:
			root_node.set_script(gen_script)
		
		if "leaf_mesh" in root_node and root_node.leaf_mesh == null:
			var leaf_mesh_res = load(LEAF_MESH_PATH)
			if leaf_mesh_res: root_node.leaf_mesh = leaf_mesh_res
		
		if "leaf_count" in root_node: 
			root_node.leaf_count = LEAF_COUNT_BUSH if is_bush else LEAF_COUNT_TREE
			
		if "leaf_color" in root_node: root_node.leaf_color = LEAF_COLOR
		
		if root_node.has_method("generate_leaves"):
			root_node.generate_leaves()

	var new_packed = PackedScene.new()
	new_packed.pack(root_node)
	ResourceSaver.save(new_packed, file_path)
	root_node.queue_free()

func _get_all_children(node: Node, result: Array = []) -> Array:
	result.push_back(node)
	for child in node.get_children():
		_get_all_children(child, result)
	return result
