extends Node

@export var player: Node3D
@export var fade_speed: float = 3.0
# Выбери слой 32 в инспекторе!
@export_flags_3d_physics var collision_mask: int = 2147483648 # Это значение для 32 слоя по умолчанию

var fading_trees = {} 

func _physics_process(delta: float):
	if not is_instance_valid(player): return
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var space_state = player.get_world_3d().direct_space_state
	
	# Луч от камеры к игроку (чуть выше ног)
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position, 
		player.global_position + Vector3(0, 1.0, 0)
	)
	
	query.collision_mask = collision_mask
	query.exclude = [player]
	
	# !!! ВАЖНО: Разрешаем лучу видеть Area3D (наш OcclusionVolume) !!!
	query.collide_with_areas = true
	query.collide_with_bodies = true # Оставляем true, если хотим фейдить и от стволов (если они на 32 слое)
	
	var result = space_state.intersect_ray(query)
	var hit_tree: Node3D = null
	
	if result:
		var hit_obj = result.collider
		# Теперь hit_obj будет Area3D
		if hit_obj.name == "OcclusionVolume":
			hit_tree = hit_obj.get_parent()
		else:
			hit_tree = hit_obj
		
		if not fading_trees.has(hit_tree):
			fading_trees[hit_tree] = 1.0 
	
	_process_fading(delta, hit_tree)

func _process_fading(delta: float, hit_tree: Node3D):
	var to_remove = []
	for tree in fading_trees.keys():
		if not is_instance_valid(tree):
			to_remove.append(tree)
			continue
			
		var target_alpha = 1.0
		if tree == hit_tree:
			target_alpha = 0.2 
			
		fading_trees[tree] = move_toward(fading_trees[tree], target_alpha, delta * fade_speed)
		
		_apply_opacity_recursive(tree, fading_trees[tree])
		
		if fading_trees[tree] >= 0.99 and tree != hit_tree:
			to_remove.append(tree)
			
	for t in to_remove:
		fading_trees.erase(t)

func _apply_opacity_recursive(node: Node, alpha: float):
	if node is GeometryInstance3D:
		var has_valid_material = false
		
		if node is CSGShape3D:
			if node.material_override != null or node.material != null:
				has_valid_material = true
		elif node is MeshInstance3D:
			if node.material_override != null or node.get_active_material(0) != null:
				has_valid_material = true
		elif node is MultiMeshInstance3D:
			if node.material_override != null:
				has_valid_material = true
			elif node.multimesh and node.multimesh.mesh:
				has_valid_material = true

		if has_valid_material:
			node.set_instance_shader_parameter("dither_opacity", alpha)
		
	for child in node.get_children():
		_apply_opacity_recursive(child, alpha)
