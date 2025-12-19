extends Node

@export var player: Node3D
@export var fade_speed: float = 2.5
@export var collision_mask: int = 8 # Слой 4, если у тебя деревья там

# Храним не меши, а КОРНЕВЫЕ ОБЪЕКТЫ (Деревья), которые сейчас прозрачные
# { TreeRootNode: current_alpha }
var fading_trees = {} 

func _physics_process(delta: float):
	if not is_instance_valid(player): return
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	# Луч от камеры к игроку
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position, player.global_position + Vector3(0, 1.0, 0))
	query.collision_mask = collision_mask
	query.exclude = [player] 
	
	var result = space_state.intersect_ray(query)
	var hit_tree: Node3D = null
	
	if result:
		# Нашли коллайдер (StaticBody дерева)
		hit_tree = result.collider
		
		# Добавляем в список на обработку, если еще нет
		if not fading_trees.has(hit_tree):
			fading_trees[hit_tree] = 1.0 # Начинаем с 1.0
	
	# Обработка плавности
	var to_remove = []
	
	for tree in fading_trees.keys():
		if not is_instance_valid(tree):
			to_remove.append(tree)
			continue
			
		var target_alpha = 1.0
		if tree == hit_tree:
			target_alpha = 0.15 # Прозрачность
			
		var current_alpha = fading_trees[tree]
		current_alpha = move_toward(current_alpha, target_alpha, delta * fade_speed)
		fading_trees[tree] = current_alpha
		
		# --- ПРИМЕНЯЕМ КО ВСЕМ МЕШАМ В ДЕРЕВЕ ---
		_apply_opacity_recursive(tree, current_alpha)
		
		if current_alpha >= 0.99 and tree != hit_tree:
			to_remove.append(tree)
			
	for t in to_remove:
		fading_trees.erase(t)

# Рекурсивная функция: ищет все меши внутри дерева и ставит им параметр
func _apply_opacity_recursive(node: Node, alpha: float):
	# Если это Меш или МультиМеш - применяем параметр
	if node is GeometryInstance3D:
		node.set_instance_shader_parameter("dither_opacity", alpha)
		
	# Идем в детей (Crown, LeavesMultiMesh, Trunk)
	for child in node.get_children():
		_apply_opacity_recursive(child, alpha)
