extends State

var player: Player

func enter() -> void:
	player = entity as Player
	player.is_attacking = false
	player.is_rolling = false
	
	if Input.is_action_pressed(GameConstants.INPUT_RUN):
		player.shift_pressed_time = player.roll_threshold + 0.05
		player.is_trying_to_run = true
	else:
		player.shift_pressed_time = 0.0
		if not player.is_auto_running:
			player.is_trying_to_run = false

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	if not player.is_on_floor():
		transitioned.emit(self, GameConstants.STATE_AIR)
		return

	# Читаем ввод заранее
	var attack_pressed = player.input_handler.is_attack_pressed
	var jump_pressed = player.input_handler.is_jump_pressed
	var run_just_released = player.input_handler.is_run_just_released
	
	# === ХАК: БЛОКИРОВКА РОЛЛА ПРИ АТАКЕ ===
	# Если мы хотим атаковать или прыгнуть, мы ОБНУЛЯЕМ событие отпускания шифта.
	# Это предотвратит случайный ролл, если игрок дернул пальцем.
	if attack_pressed or jump_pressed:
		run_just_released = false
		player.shift_pressed_time = 0.0 # Сбрасываем таймер ролла, будто мы его и не копили
	# =======================================

	# 1. АТАКА
	if attack_pressed:
		if player.ground_slam_ability.can_slam():
			transitioned.emit(self, GameConstants.STATE_SLAM)
			return
		elif player.can_attack:
			transitioned.emit(self, GameConstants.STATE_ATTACK)
			return

	# 2. ПРЫЖОК
	if jump_pressed:
		player.perform_jump()
		transitioned.emit(self, GameConstants.STATE_AIR)
		return

	# ... (дальше код движения и ролла, использующий переменную run_just_released) ...
	
	var input_vec = player.get_movement_vector()
	if input_vec == Vector2.ZERO:
		player.is_running = false
		player.is_auto_running = false
		player.is_trying_to_run = false
	
	var run_pressed = player.input_handler.is_run_pressed
	
	# Используем нашу переменную run_just_released (которую мы могли сбросить выше)
	if run_just_released:
		if player.shift_pressed_time <= player.roll_threshold:
			if player.can_roll():
				transitioned.emit(self, GameConstants.STATE_ROLL)
				player.shift_pressed_time = 0.0
				return 
		player.shift_pressed_time = 0.0

	# Обработка удержания (Бег)
	if run_pressed:
		player.shift_pressed_time += delta
		if player.shift_pressed_time > player.roll_threshold:
			player.is_trying_to_run = true
		if player.shift_pressed_time > player.auto_run_latch_time:
			if player.velocity.length() > 0.1:
				player.is_auto_running = true
	else:
		if not player.is_auto_running:
			player.is_trying_to_run = false

	# Расчет скорости
	var current_speed = player.base_speed
	var wants_to_run = (player.is_trying_to_run or player.is_auto_running)
	# (Здесь твоя логика стамины, если ты её оставил, или просто проверка)
	if wants_to_run: 
		current_speed = player.run_speed
		player.is_running = (player.velocity.length() >= player.base_speed)
	else:
		player.is_running = false

	player.apply_movement_velocity(delta, input_vec, current_speed)
	player.rot_char(delta)
	player.tilt_character(delta)
	player.handle_move_animation(delta, input_vec)
