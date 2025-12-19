@tool
extends EditorScenePostImport

# --- НАСТРОЙКИ ---
const SAVE_PATH = "res://entities/environment/trees_generated/"
const COL_SUFFIX = "_col"
const TOP_SUFFIX = "_top"

# Настройки Листвы
const LEAF_MESH_PATH = "res://assets/models/environment/LeafBasePlane.tres" # <--- ЗАМЕНИ НА СВОЙ ПУТЬ!
const LEAF_COUNT = 1000          # Количество листьев на дереве
const LEAF_SCALE_MIN = 0.8
const LEAF_SCALE_MAX = 1.0
const LEAF_COLOR = Color.RED    # Цвет вершины для шейдера ветра (Красный = Ветер)

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
			
		var trunk_node = all_meshes[mesh_name]
		var col_node = all_meshes.get(mesh_name + COL_SUFFIX)
		var top_node = all_meshes.get(mesh_name + TOP_SUFFIX)
		
		_update_or_create_scene(trunk_node, top_node, col_node)

	return scene_root_node

func _update_or_create_scene(trunk_source: MeshInstance3D, top_source: MeshInstance3D, col_source: MeshInstance3D):
	var file_path = SAVE_PATH + trunk_source.name + ".tscn"
	var root_node: StaticBody3D
	var packed_scene: PackedScene
	
	# 1. Загрузка или создание
	if FileAccess.file_exists(file_path):
		print("Updating tree: ", trunk_source.name)
		packed_scene = load(file_path)
		if packed_scene:
			root_node = packed_scene.instantiate()
	
	if not root_node:
		print("Creating NEW tree: ", trunk_source.name)
		root_node = StaticBody3D.new()
		root_node.name = trunk_source.name
	
	# 2. Обновление Ствола
	var trunk_inst = root_node.get_node_or_null("Trunk")
	if not trunk_inst:
		trunk_inst = MeshInstance3D.new()
		trunk_inst.name = "Trunk"
		root_node.add_child(trunk_inst)
		trunk_inst.owner = root_node
	
	trunk_inst.mesh = trunk_source.mesh.duplicate()
	trunk_inst.transform = Transform3D.IDENTITY
	
	# 3. Обновление Кроны и Листьев
	if top_source:
		var crown_inst = root_node.get_node_or_null("Crown")
		if not crown_inst:
			crown_inst = MeshInstance3D.new()
			crown_inst.name = "Crown"
			root_node.add_child(crown_inst)
			crown_inst.owner = root_node
			
		crown_inst.mesh = top_source.mesh.duplicate()
		crown_inst.transform = Transform3D.IDENTITY
		top_source.visible = false
		
	
	# 4. Обновление Коллизии
	var old_col = root_node.get_node_or_null("CollisionShape3D")
	if old_col: old_col.free()
	
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
		shape = trunk_inst.mesh.create_convex_shape()
	
	if shape:
		var col_node = CollisionShape3D.new()
		col_node.name = "CollisionShape3D"
		col_node.shape = shape
		root_node.add_child(col_node)
		col_node.owner = root_node

	# 5. Сохранение
	var new_packed = PackedScene.new()
	new_packed.pack(root_node)
	ResourceSaver.save(new_packed, file_path)
	root_node.queue_free()


func _get_all_children(node: Node, result: Array = []) -> Array:
	result.push_back(node)
	for child in node.get_children():
		_get_all_children(child, result)
	return result
