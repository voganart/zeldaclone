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

	# --- ИСПОЛЬЗУЕМ БУФЕРИЗАЦИЮ ---
	# Читаем буферизированный ввод. 
	# Важно: check_attack() и check_jump() "съедают" ввод, возвращая true только один раз.
	
	# 1. АТАКА
	# Если атака была нажата за последние 0.2 сек, сработает сейчас.
	# Это позволяет нажимать атаку чуть раньше окончания предыдущей анимации или приземления.
	if player.input_handler.check_attack():
		if player.ground_slam_ability.can_slam():
			transitioned.emit(self, GameConstants.STATE_SLAM)
			return
		elif player.can_attack:
			transitioned.emit(self, GameConstants.STATE_ATTACK)
			return

	# 2. ПРЫЖОК
	# Позволяет прыгнуть сразу в момент касания земли (Bunny Hop)
	if player.input_handler.check_jump():
		player.perform_jump()
		transitioned.emit(self, GameConstants.STATE_AIR)
		return

	# 3. РОЛЛ (Логика таппинга остается сложной из-за механики Sprint/Roll на одной кнопке)
	# Но мы можем добавить проверку буфера для мгновенной реакции
	
	var run_just_released = player.input_handler.is_run_just_released
	
	# Хак для предотвращения случайного ролла, если нажали атаку или прыжок
	# (Здесь мы используем is_attack_pressed как свойство геттера для проверки наличия буфера без потребления, 
	# но так как мы выше уже потребили буфер через check_*, здесь это условие сработает корректно, 
	# если ввод был обработан)
	
	# ... (дальше код движения и ролла практически без изменений, используем новые методы) ...
	
	var input_vec = player.get_movement_vector()
	if input_vec == Vector2.ZERO:
		player.is_running = false
		player.is_auto_running = false
		player.is_trying_to_run = false
	
	var run_pressed = player.input_handler.is_run_pressed
	
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

	if wants_to_run: 
		current_speed = player.run_speed
		player.is_running = (player.velocity.length() >= player.base_speed)
	else:
		player.is_running = false

	player.apply_movement_velocity(delta, input_vec, current_speed)
	player.rot_char(delta)
	player.tilt_character(delta)
	player.handle_move_animation(delta, input_vec)
