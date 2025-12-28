extends State

var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	AIDirector.release_slot(enemy)
	AIDirector.return_attack_token(enemy)
	
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	enemy.nav_agent.avoidance_enabled = false
	enemy.velocity = Vector3.ZERO
	enemy.set_physics_process(false)
	enemy.collision_layer = 0
	
	# --- ИСПРАВЛЕНИЕ: Используем CombatComponent вместо удаленных переменных ---
	# Раньше: if enemy.punch_hand_r: enemy.punch_hand_r.set_deferred("monitoring", false)
	# Теперь:
	if enemy.combat_component:
		enemy.combat_component._stop_hitbox_monitoring()
	# --------------------------------------------------------------------------
	
	# СБРОС TimeScale (Фикс HitStop)
	enemy.anim_player.speed_scale = 1.0
	
	# ПЕРЕКЛЮЧАЕМ ДЕРЕВО В DEAD
	enemy.set_tree_state("dead")
	
	# Получаем длину анимации смерти
	var anim_len = 2.0
	if enemy.anim_player.has_animation(GameConstants.ANIM_ENEMY_DEATH):
		anim_len = enemy.anim_player.get_animation(GameConstants.ANIM_ENEMY_DEATH).length
	
	await get_tree().create_timer(anim_len + 2.0).timeout
	
	_fade_out_and_free()

func _fade_out_and_free() -> void:
	var meshes_to_fade: Array[MeshInstance3D] = []
	var materials_to_fade: Array[ShaderMaterial] = []
	_collect_meshes(enemy, meshes_to_fade)
	
	# 1. Создаем дубликаты материалов для растворения
	for mesh in meshes_to_fade:
		var mat = mesh.get_active_material(0)
		if mat is ShaderMaterial:
			var new_mat = mat.duplicate()
			mesh.set_surface_override_material(0, new_mat)
			materials_to_fade.append(new_mat)

	# 2. Анимация растворения
	if materials_to_fade.size() > 0:
		var t: float = 0.0
		var fade_speed: float = 0.5
		while t < 1.0:
			if not is_instance_valid(enemy) or not enemy.is_inside_tree(): return
			var dt = get_process_delta_time()
			t += dt * fade_speed
			for mat in materials_to_fade:
				if is_instance_valid(mat): # Проверка валидности материала
					mat.set_shader_parameter("dissolve_amount", t)
			await get_tree().process_frame
			
	# 3. БЕЗОПАСНОЕ УДАЛЕНИЕ (FIX)
	if is_instance_valid(enemy):
		# Сначала отключаем меши и очищаем материалы, чтобы RenderingServer перестал их трогать
		for mesh in meshes_to_fade:
			if is_instance_valid(mesh):
				mesh.visible = false # Скрываем, чтобы не рендерился
				mesh.set_surface_override_material(0, null) # Убираем ссылку на материал
		
		# Ждем 1 кадр, чтобы RenderingServer обновил состояние и "забыл" про эти материалы
		await get_tree().process_frame
		
		# Теперь удаляем саму ноду
		if is_instance_valid(enemy):
			enemy.queue_free()

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		if "Debug" not in node.name:
			result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)
