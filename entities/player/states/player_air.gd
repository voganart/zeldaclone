extends State

var player: Player
var prev_velocity_y: float = 0.0

func enter() -> void:
	player = entity as Player
	
	# === ВАЖНО: Переключаем Transition в воздух ===
	player.set_air_state("air")
	player.set_slam_state("off") # Гарантируем, что слэм выключен
	# ==============================================

	if player.velocity.y > 0:
		player.set_jump_state("Start")
	else:
		player.set_jump_state("Mid")

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	# Обновление фаз анимации прыжка (Start -> Mid)
	if player.velocity.y < 0 and prev_velocity_y >= 0:
		player.set_jump_state("Mid")
	
	prev_velocity_y = player.velocity.y
	
	# Управление в воздухе
	var input_vec = player.get_movement_vector()
	player.apply_movement_velocity(delta, input_vec, player.base_speed)
	player.rot_char(delta)
	player.tilt_character(delta) 
	# --- ПЕРЕХОДЫ ---
	
	# Приземление
	if player.is_on_floor():
		player.set_jump_state("End")
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return
		
	# Двойной прыжок
	if player.input_handler.check_jump():
		var can_jump = false
		if player.current_jump_count > 0 and player.current_jump_count < 2:
			can_jump = true
		elif player.current_jump_count == 2 and player.air_dash_ability.bonus_jump_granted:
			can_jump = true
			
		if can_jump:
			player.perform_jump()
			player.set_jump_state("Start") # Рестарт анимации прыжка
			
	# Air Dash
	if player.input_handler.is_run_pressed: 
		if player.air_dash_ability.can_dash():
			transitioned.emit(self, GameConstants.STATE_DASH)
			return
			
	# Ground Slam
	if player.input_handler.is_attack_pressed:
		if player.ground_slam_ability.can_slam():
			player.input_handler.check_attack()
			transitioned.emit(self, GameConstants.STATE_SLAM)
			return
