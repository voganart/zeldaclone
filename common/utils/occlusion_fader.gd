extends Node

@export var player: Node3D
@export var fade_speed: float = 3.0
# Слой 6 в двоичной системе это 32 (2 в степени 5). 
# В инспекторе просто выбери "Occlusion" слой, который мы создали.
@export_flags_3d_physics var collision_mask: int = 0

var fading_trees = {} 

func _physics_process(delta: float):
	if not is_instance_valid(player): return
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var space_state = player.get_world_3d().direct_space_state
	
	# Создаем луч от камеры к игроку
	# Мы целимся чуть выше ног игрока (Vector3(0, 1.0, 0))
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position, 
		player.global_position + Vector3(0, 1.0, 0)
	)
	
	query.collision_mask = collision_mask
	# Важно: нам не нужно исключать игрока, так как он на другом слое,
	# но на всякий случай оставим.
	query.exclude = [player] 
	
	var result = space_state.intersect_ray(query)
	var hit_tree: Node3D = null
	
	if result:
		# Нашли наш OcclusionVolume. Нам нужно получить само дерево.
		# Если OcclusionVolume — это ребенок дерева, берем get_parent()
		var hit_obj = result.collider
		if hit_obj.name == "OcclusionVolume":
			hit_tree = hit_obj.get_parent()
		else:
			hit_tree = hit_obj
		
		if not fading_trees.has(hit_tree):
			fading_trees[hit_tree] = 1.0 
	
	# Логика плавного затухания
	var to_remove = []
	for tree in fading_trees.keys():
		if not is_instance_valid(tree):
			to_remove.append(tree)
			continue
			
		var target_alpha = 1.0
		if tree == hit_tree:
			target_alpha = 0.2 # Прозрачность когда мешает
			
		fading_trees[tree] = move_toward(fading_trees[tree], target_alpha, delta * fade_speed)
		
		# Применяем прозрачность ко всем частям дерева
		_apply_opacity_recursive(tree, fading_trees[tree])
		
		if fading_trees[tree] >= 0.99 and tree != hit_tree:
			to_remove.append(tree)
			
	for t in to_remove:
		fading_trees.erase(t)

func _apply_opacity_recursive(node: Node, alpha: float):
	if node is GeometryInstance3D:
		# Используем твой шейдерный параметр
		node.set_instance_shader_parameter("dither_opacity", alpha)
		
	for child in node.get_children():
		_apply_opacity_recursive(child, alpha)
