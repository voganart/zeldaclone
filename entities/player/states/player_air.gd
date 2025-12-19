extends State

var player: Player
var jump_phase: String = ""

func enter() -> void:
	player = entity as Player
	if player.velocity.y > 0:
		jump_phase = "start"
		player.anim_player.play(GameConstants.ANIM_PLAYER_JUMP_START, 0.1, 1.0)
	else:
		jump_phase = "mid"
		player.anim_player.play(GameConstants.ANIM_PLAYER_JUMP_MID, 0.1, 1.0)

func physics_update(delta: float) -> void:
	# 1. Гравитация
	player.apply_gravity(delta)
	
	# 2. Управление в воздухе
	var input_vec = player.get_movement_vector()
	player.apply_movement_velocity(delta, input_vec, player.base_speed)
	player.rot_char(delta)
	_handle_jump_animation()
	
	# --- ПЕРЕХОДЫ ---
	
	# Land -> Move
	if player.is_on_floor():
		player.anim_player.play(GameConstants.ANIM_PLAYER_JUMP_END, 0.1, 1.0)
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return
		
	# Double / Triple Jump (Используем буфер)
	if player.input_handler.check_jump():
		var can_jump = false
		if player.current_jump_count > 0 and player.current_jump_count < 2:
			can_jump = true
		elif player.current_jump_count == 2 and player.air_dash_ability.bonus_jump_granted:
			can_jump = true
			
		if can_jump:
			player.perform_jump()
			jump_phase = "start"
			player.anim_player.play(GameConstants.ANIM_PLAYER_JUMP_START, 0.05, 1.0)
			
	# Air Dash
	if player.input_handler.is_run_pressed: 
		if player.air_dash_ability.can_dash():
			transitioned.emit(self, GameConstants.STATE_DASH)
			return
			
	# Ground Slam
	# !!! ВАЖНОЕ ИСПРАВЛЕНИЕ !!!
	# 1. Сначала просто "подсматриваем" в буфер (is_attack_pressed), НЕ очищая его.
	if player.input_handler.is_attack_pressed:
		# 2. Проверяем, разрешена ли способность (высота, кулдаун, двойной прыжок)
		if player.ground_slam_ability.can_slam():
			# 3. Если разрешена — "тратим" нажатие из буфера
			player.input_handler.check_attack()
			transitioned.emit(self, GameConstants.STATE_SLAM)
			return
		# Если can_slam() вернул false (например, еще низко), мы НЕ трогаем буфер.
		# Он сработает в следующем кадре (или через кадр), когда игрок подлетит выше.
		return

func _handle_jump_animation() -> void:
	if jump_phase == "start" and player.velocity.y <= 0.1:
		jump_phase = "mid"
		var mid_speed = clamp(-player.velocity.y / 15.0, 0.5, 2.5)
		player.anim_player.play(GameConstants.ANIM_PLAYER_JUMP_MID, 0.1, mid_speed)
