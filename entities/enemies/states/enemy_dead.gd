extends State

var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	
	# Останавливаем все
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	enemy.nav_agent.avoidance_enabled = false
	enemy.velocity = Vector3.ZERO
	
	# Отключаем физику (но оставляем процесс для таймеров, если нужно)
	enemy.set_physics_process(false)
	
	# Отключаем коллизии (чтобы сквозь труп можно было ходить)
	enemy.collision_layer = 0
	# Можно также отключить маску, если нужно
	
	# Отключаем хитбоксы рук
	if enemy.punch_hand_r: enemy.punch_hand_r.set_deferred("monitoring", false)
	if enemy.punch_hand_l: enemy.punch_hand_l.set_deferred("monitoring", false)
	
	# Анимация
	enemy.play_animation(GameConstants.ANIM_ENEMY_DEATH, 0.2, 0.7)
	
	# Ждем окончания анимации + время лежания
	await enemy.anim_player.animation_finished
	await get_tree().create_timer(2.0).timeout
	
	_fade_out_and_free()

func _fade_out_and_free() -> void:
	# ... (код сбора мешей и материалов оставляем как был) ...
	# 1. Сбор мешей и материалов
	var meshes_to_fade: Array[MeshInstance3D] = []
	var materials_to_fade: Array[ShaderMaterial] = []
	_collect_meshes(enemy, meshes_to_fade)
	
	for mesh in meshes_to_fade:
		var mat = mesh.get_active_material(0)
		if mat is ShaderMaterial:
			var new_mat = mat.duplicate()
			mesh.set_surface_override_material(0, new_mat)
			materials_to_fade.append(new_mat)

	# 2. Безопасный цикл растворения
	if materials_to_fade.size() > 0:
		var t: float = 0.0
		var fade_speed: float = 0.5
		
		while t < 1.0:
			# !!! ВАЖНО: Проверка, жив ли враг
			if not is_instance_valid(enemy) or not enemy.is_inside_tree():
				return

			# Используем глобальное время, так как physics_process может быть отключен
			var dt = get_process_delta_time()
			t += dt * fade_speed
			
			for mat in materials_to_fade:
				mat.set_shader_parameter("dissolve_amount", t)
				
			await get_tree().process_frame
			
	if is_instance_valid(enemy):
		enemy.queue_free()

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		# Игнорируем дебажные сферы, если они есть
		if "Debug" not in node.name:
			result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)
