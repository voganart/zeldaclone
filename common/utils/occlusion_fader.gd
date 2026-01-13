extends Node

# Можно назначить вручную, но если пусто - найдем сами
@export var player: Node3D
@export var fade_speed: float = 2.0
@export var fade_opacity: float = 0.5
# Слой 32 (Occlusion)
@export_flags_3d_physics var collision_mask: int = 2147483648 

var fading_trees = {} 

func _physics_process(delta: float):
	# --- ЛЕНИВЫЙ ПОИСК ИГРОКА ---
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		# Если все еще не нашли, пропускаем кадр
		if not player: return
	# -----------------------------

	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var space_state = player.get_world_3d().direct_space_state
	
	var trees_to_hide = []
	
	# 1. Проверка: Камера ВНУТРИ листвы
	var point_query = PhysicsPointQueryParameters3D.new()
	point_query.position = camera.global_position
	point_query.collision_mask = collision_mask
	point_query.collide_with_areas = true 
	point_query.collide_with_bodies = false 
	
	var point_results = space_state.intersect_point(point_query, 8)
	
	for res in point_results:
		var root = _get_tree_root(res.collider)
		if not trees_to_hide.has(root):
			trees_to_hide.append(root)
	
	# 2. Проверка: Листва ПЕРЕКРЫВАЕТ вид
	var ray_query = PhysicsRayQueryParameters3D.create(
		camera.global_position, 
		player.global_position + Vector3(0, 1.5, 0)
	)
	ray_query.collision_mask = collision_mask
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = true 
	
	var current_exclusions = [player.get_rid()]
	
	for i in range(3):
		ray_query.exclude = current_exclusions
		var ray_result = space_state.intersect_ray(ray_query)
		
		if ray_result:
			var collider = ray_result.collider
			var root = _get_tree_root(collider)
			
			if not trees_to_hide.has(root):
				trees_to_hide.append(root)
			
			current_exclusions.append(ray_result.rid)
		else:
			break
	
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
		if active_trees.has(tree):
			target_alpha = fade_opacity
			
		fading_trees[tree] = move_toward(fading_trees[tree], target_alpha, delta * fade_speed)
		
		_apply_opacity_recursive(tree, fading_trees[tree])
		
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
