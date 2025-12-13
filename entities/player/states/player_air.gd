extends State

var player: Player
var jump_phase: String = ""

func enter() -> void:
	player = entity as Player
	# Если мы вошли в воздух сразу с прыжка (через transition), то perform_jump уже был вызван в Move.
	# Если мы просто упали с края, perform_jump не вызывался, но гравитация сама потянет вниз.
	
	# Анимация начала прыжка, если есть вертикальная скорость
	if player.velocity.y > 0:
		jump_phase = "start"
		player.anim_player.play(GameConstants.ANIM_PLAYER_JUMP_START, 0.1, 1.0)
	else:
		jump_phase = "mid"
		player.anim_player.play(GameConstants.ANIM_PLAYER_JUMP_MID, 0.1, 1.0)

	# print("[FSM] Player Air")

func physics_update(delta: float) -> void:
	# 1. Гравитация
	player.apply_gravity(delta)
	
	# 2. Управление в воздухе (Air Control)
	# !!! ИЗМЕНЕНИЕ: Используем новый метод
	var input_vec = player.get_movement_vector()
	# В воздухе используем base_speed, но с малой интерполяцией (которая внутри apply_movement_velocity зашита как acceleration)
	# Для лучшего Air Control можно передать другой параметр acceleration, но пока используем стандартный
	player.apply_movement_velocity(delta, input_vec, player.base_speed)
	
	# 3. Вращение
	player.rot_char(delta)
	
	# 4. Анимация прыжка (фазы)
	_handle_jump_animation()
	
	# --- ПЕРЕХОДЫ ---
	
	# Land -> Move
	if player.is_on_floor():
		player.anim_player.play(GameConstants.ANIM_PLAYER_JUMP_END, 0.1, 1.0)
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return
		
	# Double / Triple Jump
	if Input.is_action_just_pressed(GameConstants.INPUT_JUMP):
		var can_jump = false
		if player.current_jump_count > 0 and player.current_jump_count < 2:
			can_jump = true
		elif player.current_jump_count == 2 and player.air_dash_ability.bonus_jump_granted:
			can_jump = true
			
		if can_jump:
			player.perform_jump()
			# Сбрасываем фазу анимации для нового прыжка
			jump_phase = "start"
			player.anim_player.play(GameConstants.ANIM_PLAYER_JUMP_START, 0.05, 1.0)
			
	# Air Dash
	# Проверяем нажатие Shift (или отпускание, как в оригинале)
	# В оригинале было: if not is_on_floor() and shift_pressed_time <= roll_threshold:
	# Здесь упростим: если нажали Run в воздухе
	if Input.is_action_just_pressed(GameConstants.STATE_RUN): # Или released, как удобнее
		if player.air_dash_ability.can_dash():
			transitioned.emit(self, GameConstants.STATE_DASH)
			return
			
	# Ground Slam
	if Input.is_action_just_pressed(GameConstants.INPUT_ATTACK_PRIMARY):
		if player.ground_slam_ability.can_slam():
			transitioned.emit(self, GameConstants.STATE_SLAM)
		# Можно добавить атаку в воздухе, если нужно
		return

func _handle_jump_animation() -> void:
	if jump_phase == "start" and player.velocity.y <= 0.1:
		jump_phase = "mid"
		# Скорость анимации падения зависит от скорости падения
		var mid_speed = clamp(-player.velocity.y / 15.0, 0.5, 2.5)
		player.anim_player.play(GameConstants.ANIM_PLAYER_JUMP_MID, 0.1, mid_speed)
