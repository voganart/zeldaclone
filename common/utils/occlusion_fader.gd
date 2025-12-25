extends Node

@export var player: Node3D
@export var fade_speed: float = 5.0
@export var fade_opacity: float = 0.5
# Выбери слой 32 в инспекторе!
@export_flags_3d_physics var collision_mask: int = 2147483648 

var fading_trees = {} 

func _physics_process(delta: float):
	if not is_instance_valid(player): return
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var space_state = player.get_world_3d().direct_space_state
	
	# Список всех деревьев, которые мешают в ЭТОМ кадре
	var trees_to_hide = []
	
	# --- ПРОВЕРКА 1: Камера ВНУТРИ листвы? (Ищем сразу много) ---
	var point_query = PhysicsPointQueryParameters3D.new()
	point_query.position = camera.global_position
	point_query.collision_mask = collision_mask
	point_query.collide_with_areas = true 
	point_query.collide_with_bodies = false 
	
	# Увеличиваем лимит до 8, чтобы поймать пересечение нескольких крон
	var point_results = space_state.intersect_point(point_query, 8)
	
	for res in point_results:
		var root = _get_tree_root(res.collider)
		if not trees_to_hide.has(root):
			trees_to_hide.append(root)
	
	# --- ПРОВЕРКА 2: Листва ПЕРЕКРЫВАЕТ вид? (Пробиваем лучом насквозь) ---
	# Создаем параметры луча
	var ray_query = PhysicsRayQueryParameters3D.create(
		camera.global_position, 
		player.global_position + Vector3(0, 1.5, 0)
	)
	ray_query.collision_mask = collision_mask
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = true 
	
	# Начинаем со списка исключений, содержащего только игрока
	var current_exclusions = [player.get_rid()]
	
	# Делаем до 3 "пробитий" (скроем до 3 деревьев стоящих друг за другом)
	for i in range(3):
		ray_query.exclude = current_exclusions
		var ray_result = space_state.intersect_ray(ray_query)
		
		if ray_result:
			var collider = ray_result.collider
			var root = _get_tree_root(collider)
			
			if not trees_to_hide.has(root):
				trees_to_hide.append(root)
			
			# Добавляем найденное дерево в исключения, чтобы следующий луч прошел сквозь него
			current_exclusions.append(ray_result.rid)
		else:
			# Если луч никуда не попал - выходим из цикла
			break
	
	# Регистрируем новые деревья в систему
	for tree in trees_to_hide:
		if not fading_trees.has(tree):
			fading_trees[tree] = 1.0
	
	_process_fading(delta, trees_to_hide)

func _get_tree_root(collider: Node) -> Node3D:
	if collider.name == "OcclusionVolume":
		return collider.get_parent()
	return collider as Node3D

func _process_fading(delta: float, active_trees: Array):
	var to_remove = []
	
	for tree in fading_trees.keys():
		if not is_instance_valid(tree):
			to_remove.append(tree)
			continue
			
		var target_alpha = 1.0
		
		# Если дерево есть в списке "активных" (мешающих) в этом кадре
		if active_trees.has(tree):
			target_alpha = fade_opacity
			
		fading_trees[tree] = move_toward(fading_trees[tree], target_alpha, delta * fade_speed)
		
		_apply_opacity_recursive(tree, fading_trees[tree])
		
		# Если дерево полностью проявилось и его нет в списке активных - удаляем
		if fading_trees[tree] >= 0.99 and not active_trees.has(tree):
			_apply_opacity_recursive(tree, 1.0)
			to_remove.append(tree)
			
	for t in to_remove:
		fading_trees.erase(t)

func _apply_opacity_recursive(node: Node, alpha: float):
	if node is GeometryInstance3D:
		var is_shader_mat = false
		
		if node is MeshInstance3D:
			if node.get_active_material(0) is ShaderMaterial:
				is_shader_mat = true
		elif node is MultiMeshInstance3D:
			if node.material_override is ShaderMaterial:
				is_shader_mat = true
			elif node.multimesh and node.multimesh.mesh:
				if node.multimesh.mesh.surface_get_material(0) is ShaderMaterial:
					is_shader_mat = true
		elif node is CSGShape3D:
			if node.material is ShaderMaterial:
				is_shader_mat = true

		if is_shader_mat:
			node.set_instance_shader_parameter("dither_opacity", alpha)
		
	for child in node.get_children():
		_apply_opacity_recursive(child, alpha)
