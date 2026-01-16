extends State

var player: Player
var roll_duration: float = 0.0
var elapsed_time: float = 0.0

# Флаг, означающий, что анимация закончилась, но мы все еще катимся, потому что застряли
var is_extended_roll: bool = false 

func enter() -> void:
	player = entity as Player
	player.is_rolling = true
	player.is_invincible = true
	elapsed_time = 0.0
	is_extended_roll = false
	
	player.roll_ability.consume_charge()
	
	# !!! 1. СЖИМАЕМ КОЛЛАЙДЕР !!!
	player.shrink_collider()
	
	if player.shape_cast:
		player.shape_cast.enabled = true

	player.trigger_roll()
	
	if player.anim_player.has_animation(GameConstants.ANIM_PLAYER_ROLL):
		roll_duration = player.anim_player.get_animation(GameConstants.ANIM_PLAYER_ROLL).length
	else:
		roll_duration = 0.6
	
	# Скорость
	var current_speed_2d = Vector2(player.velocity.x, player.velocity.z).length()
	var speed_factor = clamp(current_speed_2d / player.run_speed, 0.0, 1.0)
	player.root_motion_speed_factor = lerp(player.roll_min_speed, player.roll_max_speed, speed_factor)
	
	player.sfx_roll.play_random()

func physics_update(delta: float) -> void:
	elapsed_time += delta
	var progress = elapsed_time / roll_duration

	# --- ЛОГИКА ЗАСТРЕВАНИЯ ПОД ПРЕПЯТСТВИЕМ ---
	
	# Если время анимации вышло
	if elapsed_time >= roll_duration:
		# Проверяем, есть ли крыша над головой
		if player.is_roof_above():
			# !!! КРЫША ЕСТЬ: Продлеваем состояние !!!
			is_extended_roll = true
			
			# Продолжаем двигаться вперед (автоматически выкатываемся)
			# Берем направление взгляда игрока
			var forward = -player.global_transform.basis.z
			player.velocity.x = forward.x * 3.0 # Скорость выкатывания
			player.velocity.z = forward.z * 3.0
			player.move_and_slide()
			
			# Можно зациклить последний кадр анимации или включить ползание, 
			# но пока просто фризим в конце ролла
			return 
		else:
			# !!! КРЫШИ НЕТ: Можно вставать !!!
			transitioned.emit(self, GameConstants.STATE_MOVE)
			return

	# --- ОБЫЧНАЯ ЛОГИКА (Пока идет анимация) ---
	
	# Прерывания (Прыжок/Атака) работают ТОЛЬКО если мы не в режиме "выкатывания"
	if not is_extended_roll:
		# Прыжок
		if player.input_handler.check_jump():
			if progress >= player.roll_jump_cancel_threshold:
				# Проверяем крышу перед прыжком! Нельзя прыгать в потолок.
				if not player.is_roof_above():
					player.perform_jump()
					transitioned.emit(self, GameConstants.STATE_AIR)
					return

		# Атака
		if player.input_handler.is_attack_pressed:
			var can_cancel_attack = progress >= (1.0 - player.attack_roll_cancel_threshold)
			if can_cancel_attack and player.can_attack:
				if not player.is_roof_above():
					player.input_handler.check_attack()
					transitioned.emit(self, GameConstants.STATE_ATTACK)
					return

	# Проверка физического застревания в стене
	if progress >= 0.9 and not is_extended_roll:
		if player.wall_detector and player.wall_detector.is_colliding(): # Используем wall_detector или shape_cast
			var nav_point = player.get_closest_nav_point()
			var push_dir = (nav_point - player.global_position).normalized()
			player.velocity += push_dir * 5.0

func exit() -> void:
	player.is_rolling = false
	player.is_invincible = false
	player.root_motion_speed_factor = 1.0
	
	# !!! 2. ВОССТАНАВЛИВАЕМ КОЛЛАЙДЕР !!!
	player.restore_collider()
	
	if player.shape_cast:
		player.shape_cast.enabled = false
		
	# Сохраняем инерцию ввода
	var input_vec = player.input_handler.move_vector
	if input_vec.length() > 0.01:
		if player.is_trying_to_run:
			player.current_movement_blend = player.blend_value_run
		else:
			player.current_movement_blend = player.blend_value_walk
		player.set_locomotion_blend(player.current_movement_blend)
