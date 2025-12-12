extends State

var player: Player

func enter() -> void:
	player = entity as Player
	player.is_attacking = false
	player.is_rolling = false
	
	# Логика входа при зажатой кнопке:
	# Если мы вышли из переката или атаки и УЖЕ держим Shift -> сразу переходим в бег,
	# минуя фазу накопления таймера (чтобы не кувыркнуться случайно при отпускании).
	if Input.is_action_pressed(GameConstants.INPUT_RUN):
		# Ставим таймер чуть больше порога, чтобы игра считала, что мы уже "давно" держим кнопку
		player.shift_pressed_time = player.roll_threshold + 0.05
		player.is_trying_to_run = true
	else:
		# Если кнопка не нажата, сбрасываем таймер
		# (кроме случая авто-бега, там таймер не важен, важен флаг is_auto_running)
		player.shift_pressed_time = 0.0
		if not player.is_auto_running:
			player.is_trying_to_run = false

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	var run_pressed = Input.is_action_pressed(GameConstants.INPUT_RUN)
	var run_just_released = Input.is_action_just_released(GameConstants.INPUT_RUN)
	
	# --- 1. ОБРАБОТКА ОТПУСКАНИЯ (ПОПЫТКА КУВЫРКА) ---
	if run_just_released:
		# Если нажатие было коротким -> Делаем КУВЫРОК
		# Это сработает и из состояния покоя, и во время авто-бега
		if player.shift_pressed_time <= player.roll_threshold:
			if player.can_roll():
				transitioned.emit(self, GameConstants.STATE_ROLL)
				player.shift_pressed_time = 0.0
				return
		
		# Если нажатие было длинным -> Мы просто перестали бежать вручную
		player.shift_pressed_time = 0.0

	# --- 2. ОБРАБОТКА УДЕРЖАНИЯ (БЕГ И АВТО-БЕГ) ---
	if run_pressed:
		player.shift_pressed_time += delta
		
		# Если держим кнопку дольше порога переката -> Это БЕГ
		if player.shift_pressed_time > player.roll_threshold:
			player.is_trying_to_run = true
			
		# Если держим кнопку ОЧЕНЬ долго -> Включаем АВТО-БЕГ
		# Добавляем проверку velocity, чтобы не включать автобег, стоя в стену
		if player.shift_pressed_time > player.auto_run_latch_time:
			if player.velocity.length() > 0.1:
				player.is_auto_running = true
				
	else:
		# Кнопка не нажата
		# Если мы НЕ в авто-беге, то отключаем бег
		if not player.is_auto_running:
			player.is_trying_to_run = false
			
	# --- ДВИЖЕНИЕ И АНИМАЦИЯ ---
	# Примечание: Сброс is_auto_running при остановке (отпускании WASD) 
	# должен происходить внутри player.handle_movement_input() в Player.gd
	player.handle_movement_input(delta)
	player.rot_char(delta)
	player.tilt_character(delta)
	player.handle_move_animation(delta)
	
	# --- ПЕРЕХОДЫ ---
	if not player.is_on_floor():
		transitioned.emit(self, GameConstants.STATE_AIR)
		return

	if Input.is_action_just_pressed(GameConstants.INPUT_JUMP):
		player.perform_jump() 
		transitioned.emit(self, GameConstants.STATE_AIR)
		return

	if Input.is_action_just_pressed(GameConstants.INPUT_ATTACK_PRIMARY):
		if player.ground_slam_ability.can_slam():
			transitioned.emit(self, GameConstants.STATE_SLAM)
		elif player.can_attack:
			transitioned.emit(self, GameConstants.STATE_ATTACK)
		return
