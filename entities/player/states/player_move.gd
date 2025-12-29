extends State

var player: Player

# --- ПЕРЕМЕННЫЕ ДЛЯ ТАНЦА ---
var current_idle_time: float = 0.0
var is_dancing: bool = false
# ----------------------------

func enter() -> void:
	player = entity as Player
	player.is_attacking = false
	player.is_rolling = false
	
	# Сброс таймера танца при входе
	current_idle_time = 0.0
	is_dancing = false
	
	# Сброс дерева анимации
	player.set_life_state("alive")
	player.set_air_state("ground")
	player.set_slam_state("off")
	player.set_jump_state("End")
	
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
		_stop_dance_logic()
		transitioned.emit(self, GameConstants.STATE_AIR)
		return

	var input_vec = player.get_movement_vector()
	var has_input = input_vec.length() > 0.01
	
	# Считаем только горизонтальную скорость (игнорируем гравитацию)
	# Это решает проблему с "0.77", когда персонаж стоит
	var horizontal_speed = Vector2(player.velocity.x, player.velocity.z).length()

	# --- ЛОГИКА ТАНЦА ---
	if not has_input and horizontal_speed < 0.5:
		if player.enable_idle_dance:
			current_idle_time += delta
			if current_idle_time >= player.idle_dance_time and not is_dancing:
				_start_dance_logic()
	else:
		if current_idle_time > 0 or is_dancing:
			_stop_dance_logic()
	# --------------------

	# 1. АТАКА
	if player.input_handler.check_attack():
		_stop_dance_logic()
		if player.ground_slam_ability.can_slam():
			transitioned.emit(self, GameConstants.STATE_SLAM)
			return
		elif player.can_attack:
			transitioned.emit(self, GameConstants.STATE_ATTACK)
			return

	# 2. ПРЫЖОК
	if player.input_handler.check_jump():
		_stop_dance_logic()
		player.perform_jump()
		transitioned.emit(self, GameConstants.STATE_AIR)
		return

	# 3. РОЛЛ / БЕГ
	var run_just_released = player.input_handler.is_run_just_released
	
	if input_vec == Vector2.ZERO:
		player.is_running = false
		player.is_auto_running = false
		player.is_trying_to_run = false
	
	var run_pressed = player.input_handler.is_run_pressed
	
	if run_just_released:
		if player.shift_pressed_time <= player.roll_threshold:
			if player.can_roll():
				_stop_dance_logic()
				transitioned.emit(self, GameConstants.STATE_ROLL)
				player.shift_pressed_time = 0.0
				return 
		player.shift_pressed_time = 0.0

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

func exit() -> void:
	_stop_dance_logic()

func _start_dance_logic():
	is_dancing = true
	if player.anim_controller.has_method("trigger_dance"):
		player.anim_controller.trigger_dance()

func _stop_dance_logic():
	current_idle_time = 0.0
	if is_dancing:
		is_dancing = false
		if player.anim_controller.has_method("stop_dance"):
			player.anim_controller.stop_dance()
