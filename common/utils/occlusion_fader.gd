extends Node

@export var player: Node3D
@export var fade_speed: float = 5.0 # Чуть ускорил для отзывчивости
# Слой, на котором находятся препятствия (деревья, стены)
@export_flags_3d_physics var collision_mask: int = 1 

var fading_trees = {} 

func _physics_process(delta: float):
	if not is_instance_valid(player): return
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var space_state = player.get_world_3d().direct_space_state
	var cam_pos = camera.global_position
	# Целимся в голову/торс игрока
	var player_target_pos = player.global_position + Vector3(0, 1.0, 0)
	
	# Список объектов, которые нужно сделать прозрачными в этом кадре
	var objects_to_fade_this_frame = {}
	
	# --- 1. ПРОВЕРКА ЛУЧОМ (Между камерой и игроком) ---
	var ray_query = PhysicsRayQueryParameters3D.create(cam_pos, player_target_pos)
	ray_query.collision_mask = collision_mask
	ray_query.exclude = [player] 
	
	var ray_result = space_state.intersect_ray(ray_query)
	
	if ray_result:
		var hit_obj = ray_result.collider
		var tree_root = _get_root_object(hit_obj)
		if tree_root:
			objects_to_fade_this_frame[tree_root] = true

	# --- 2. ПРОВЕРКА ТОЧКИ (Камера ВНУТРИ объекта) ---
	var point_query = PhysicsPointQueryParameters3D.new()
	point_query.position = cam_pos
	point_query.collision_mask = collision_mask
	point_query.collide_with_bodies = true
	point_query.collide_with_areas = true # Если ваши деревья используют Area3D для листвы
	
	# max_results = 4 достаточно, вряд ли камера будет внутри 5 деревьев сразу
	var point_results = space_state.intersect_point(point_query, 4)
	
	for res in point_results:
		var hit_obj = res.collider
		var tree_root = _get_root_object(hit_obj)
		if tree_root:
			objects_to_fade_this_frame[tree_root] = true

	# --- 3. ОБРАБОТКА СПИСКОВ ---
	
	# Добавляем новые объекты в список активного фейда
	for obj in objects_to_fade_this_frame:
		if not fading_trees.has(obj):
			fading_trees[obj] = 1.0 # Начинаем с полной непрозрачности
	
	# Логика плавного изменения прозрачности
	var to_remove = []
	for tree in fading_trees.keys():
		if not is_instance_valid(tree):
			to_remove.append(tree)
			continue
			
		var target_alpha = 1.0
		# Если дерево есть в текущем списке помех -> стремимся к прозрачности
		if objects_to_fade_this_frame.has(tree):
			target_alpha = 0.15 # Сильная прозрачность, если камера внутри
		
		# Плавное изменение
		fading_trees[tree] = move_toward(fading_trees[tree], target_alpha, delta * fade_speed)
		
		# Применяем к мешам
		_apply_opacity_recursive(tree, fading_trees[tree])
		
		# Если объект полностью восстановился и больше не мешает -> удаляем из обработки
		if fading_trees[tree] >= 0.99 and not objects_to_fade_this_frame.has(tree):
			to_remove.append(tree)
			# Для чистоты сбрасываем в ровно 1.0
			_apply_opacity_recursive(tree, 1.0)
			
	for t in to_remove:
		fading_trees.erase(t)

# Вспомогательная функция для поиска корня (если попали в OcclusionVolume или чайлд)
func _get_root_object(collider: Node) -> Node3D:
	if not collider: return null
	# Если коллайдер называется OcclusionVolume, берем родителя
	if collider.name == "OcclusionVolume":
		return collider.get_parent()
	# Если это StaticBody внутри меша (как у нас в генераторе деревьев)
	if collider.get_parent() is MeshInstance3D or collider.get_parent().name.begins_with("Tree"):
		return collider.get_parent()
	
	return collider as Node3D

func _apply_opacity_recursive(node: Node, alpha: float):
	# Проверяем, является ли объект визуальным (GeometryInstance3D)
	if node is GeometryInstance3D:
		var should_apply = false
		
		# 1. Если это обычный Меш (MeshInstance3D)
		if node is MeshInstance3D:
			# У него есть эта функция, проверяем безопасно
			if node.get_active_material(0) != null:
				should_apply = true
		
		# 2. Если это CSG Стена (CSGShape3D)
		elif node is CSGShape3D:
			# У CSG нет get_active_material, проверяем свойства напрямую
			if node.material_override != null or node.material != null:
				should_apply = true
				
		# 3. Если это Мультимеш (Трава/Листва)
		elif node is MultiMeshInstance3D:
			# У мультимеша материал обычно внутри MultiMesh ресурса или в override
			# Тут сложно проверить просто, поэтому просто разрешаем, краша не будет
			should_apply = true

		# Применяем параметр только если проверки прошли
		if should_apply:
			node.set_instance_shader_parameter("dither_opacity", alpha)
		
	# Рекурсия для детей
	for child in node.get_children():
		_apply_opacity_recursive(child, alpha)
