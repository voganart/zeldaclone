@tool
extends EditorScenePostImport

const SAVE_PATH = "res://entities/environment/trees_generated/"
const COL_SUFFIX = "_col"

func _post_import(scene_root_node: Node) -> Object:
	print("--- START IMPORT DEBUG ---")
	_print_hierarchy(scene_root_node, "")
	print("--------------------------")

	var dir = DirAccess.open("res://")
	if not dir.dir_exists(SAVE_PATH):
		dir.make_dir_recursive(SAVE_PATH)

	# 1. Собираем все меши в словарь по имени
	var all_meshes = {}
	var all_nodes = _get_all_children(scene_root_node)
	
	for node in all_nodes:
		if node is MeshInstance3D:
			# Очищаем имя от мусора (Godot может добавить цифры, типа Tree_col2)
			# Для поиска будем использовать чистое имя
			all_meshes[node.name] = node

	# 2. Ищем пары
	for mesh_name in all_meshes:
		# Если это коллижн - пропускаем, обработаем с родителем
		if mesh_name.contains(COL_SUFFIX):
			continue
			
		var visual_node = all_meshes[mesh_name]
		
		# Пытаемся найти коллизию
		# Ищем среди ключей словаря тот, который начинается на ИмяДерева + _col
		var col_node = null
		var target_col_name = mesh_name + COL_SUFFIX
		
		for candidate_name in all_meshes:
			if candidate_name.begins_with(target_col_name):
				col_node = all_meshes[candidate_name]
				break
		
		_create_tree_scene(visual_node, col_node)

	return scene_root_node

func _create_tree_scene(visual_node: MeshInstance3D, col_node: MeshInstance3D):
	# --- ДИАГНОСТИКА ---
	var mesh = visual_node.mesh
	if mesh.get_surface_count() > 0:
		var arrays = mesh.surface_get_arrays(0)
		var colors = arrays[Mesh.ARRAY_COLOR]
		
		if colors == null or colors.size() == 0:
			print("🔴 [ERROR] Цветов нет вообще!")
		else:
			var found_interesting = false
			var white_count = 0
			
			for c in colors:
				# Проверяем, есть ли что-то НЕ белое
				if c.r < 0.95 or c.g < 0.95 or c.b < 0.95:
					print("🟢 [УСПЕХ] Найден цветной вертекс! ", c)
					found_interesting = true
					break # Хватит, мы нашли доказательство
				else:
					white_count += 1
			
			if not found_interesting:
				print("🔴 [FAIL] Проверено ", colors.size(), " вершин. ВСЕ ОНИ БЕЛЫЕ (1,1,1,1).")
	print("Generating: ", visual_node.name)
	
	var new_root = StaticBody3D.new()
	new_root.name = visual_node.name
	
	# Визуал
	var new_visual = visual_node.duplicate()
	new_visual.name = "Visual"
	new_visual.mesh = visual_node.mesh.duplicate()
	new_visual.transform = Transform3D.IDENTITY
	# Удаляем детей у визуала (чтобы там не было лишних коллизий)
	for child in new_visual.get_children(): child.queue_free()
	
	new_root.add_child(new_visual)
	new_visual.owner = new_root
	
	# --- КОЛЛИЗИЯ ---
	var shape = null
	
	if col_node:
		# ПОПЫТКА 1: Украсть готовую форму у Godot
		# Godot мог уже создать StaticBody3D внутри коллижн-меша
		for child in col_node.get_children():
			if child is StaticBody3D:
				for grandchild in child.get_children():
					if grandchild is CollisionShape3D:
						shape = grandchild.shape # БЕРЕМ ГОТОВУЮ ФОРМУ
						print("  [OK] Stolen existing shape from Godot importer.")
						break
			if shape: break
		
		# ПОПЫТКА 2: Если не вышло украсть, генерируем сами
		if not shape:
			print("  [OK] Generating convex shape manually.")
			shape = col_node.mesh.create_convex_shape()
			
		# Скрываем исходный меш коллизии, чтобы он не мешал
		col_node.visible = false
	else:
		print("  [!!] No custom collision. Auto-generating from visual.")
		shape = new_visual.mesh.create_convex_shape()
	
	# Создаем ноду коллизии с полученной формой
	if shape:
		var col_shape = CollisionShape3D.new()
		col_shape.shape = shape
		new_root.add_child(col_shape)
		col_shape.owner = new_root
	
	# Сохраняем
	var packed = PackedScene.new()
	packed.pack(new_root)
	ResourceSaver.save(packed, SAVE_PATH + visual_node.name + ".tscn")

func _get_all_children(node: Node, result: Array = []) -> Array:
	result.push_back(node)
	for child in node.get_children():
		_get_all_children(child, result)
	return result

func _print_hierarchy(node: Node, indent: String):
	var type = ""
	if node is MeshInstance3D: type = " (Mesh)"
	elif node is Node3D: type = " (Node3D)"
	print(indent + node.name + type)
	for child in node.get_children():
		_print_hierarchy(child, indent + "  ")
