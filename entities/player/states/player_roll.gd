extends State

var player: Player
var roll_duration: float = 0.0
var elapsed_time: float = 0.0
var ghost_layers: Array[int] = [3, 5]
var current_roll_speed: float = 0.0

func enter() -> void:
	player = entity as Player
	player.is_rolling = true
	player.is_invincible = true
	elapsed_time = 0.0
	
	# --- ТРАТА ЗАРЯДОВ ---
	player.current_roll_charges -= 1
	if player.current_roll_charges <= 0:
		player.is_roll_recharging = true
		player.roll_penalty_timer = player.roll_recharge_time
	else:
		if player.roll_regen_timer <= 0:
			player.roll_regen_timer = player.roll_cooldown
	
	player.roll_charges_changed.emit(player.current_roll_charges, player.roll_max_charges, player.is_roll_recharging)
	
	# --- ФИЗИКА ---
	for layer in ghost_layers:
		player.set_collision_mask_value(layer, false)
	
	if player.shape_cast:
		player.shape_cast.enabled = true

	# Запуск анимации через дерево
	player.trigger_roll()
	
	if player.anim_player.has_animation(GameConstants.ANIM_PLAYER_ROLL):
		roll_duration = player.anim_player.get_animation(GameConstants.ANIM_PLAYER_ROLL).length
	else:
		roll_duration = 0.6
	
	# Расчет скорости
	var current_speed_2d = Vector2(player.velocity.x, player.velocity.z).length()
	var speed_factor = clamp(current_speed_2d / player.run_speed, 0.0, 1.0)
	current_roll_speed = lerp(player.roll_min_speed, player.roll_max_speed, speed_factor)
	
	var forward = player.global_transform.basis.z.normalized()
	player.velocity.x = forward.x * current_roll_speed
	player.velocity.z = forward.z * current_roll_speed
	
	player.sfx_roll.play_random()

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	elapsed_time += delta
	var progress = elapsed_time / roll_duration

	# --- 1. ПРЕРЫВАНИЕ ПРЫЖКОМ ---
	if player.input_handler.check_jump():
		if progress >= player.roll_jump_cancel_threshold:
			player.perform_jump()
			transitioned.emit(self, GameConstants.STATE_AIR)
			return

	# --- 2. ПРЕРЫВАНИЕ АТАКОЙ ---
	if player.input_handler.is_attack_pressed:
		var can_cancel_attack = progress >= (1.0 - player.attack_roll_cancel_threshold)
		if can_cancel_attack and player.can_attack:
			player.input_handler.check_attack()
			transitioned.emit(self, GameConstants.STATE_ATTACK)
			return

	# --- УПРАВЛЕНИЕ ---
	var input_dir = player.input_handler.move_vector
	if input_dir != Vector2.ZERO:
		var input_vec3 = Vector3(input_dir.x, 0, input_dir.y)
		var local_input = player.global_transform.basis.inverse() * input_vec3
		var steer_amount = local_input.x
		if abs(steer_amount) > 0.1:
			var rotation_strength = player.rot_speed * player.roll_control * delta
			player.rotate_y(steer_amount * rotation_strength)
	
	var forward = player.global_transform.basis.z.normalized()
	player.velocity.x = forward.x * current_roll_speed
	player.velocity.z = forward.z * current_roll_speed
	
	player.move_and_slide()

	# Проверка застревания в конце
	if progress >= 0.9:
		if player.shape_cast and player.shape_cast.is_colliding():
			var nav_point = player.get_closest_nav_point()
			var push_dir = (nav_point - player.global_position).normalized()
			player.velocity += push_dir * 5.0

	if elapsed_time >= roll_duration:
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return

func exit() -> void:
	player.is_rolling = false
	player.is_invincible = false
	for layer in ghost_layers:
		player.set_collision_mask_value(layer, true)
	if player.shape_cast:
		player.shape_cast.enabled = false
