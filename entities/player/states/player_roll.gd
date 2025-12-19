extends State

var player: Player
var roll_duration: float = 0.0
var current_time: float = 0.0
var ghost_layers: Array[int] = [3, 5] 

func enter() -> void:
	player = entity as Player
	player.is_rolling = true
	player.is_invincible = true
	
	# --- ТРАТА ЗАРЯДОВ ---
	player.current_roll_charges -= 1
	if player.current_roll_charges <= 0:
		player.is_roll_recharging = true
		player.roll_penalty_timer = player.roll_recharge_time
	else:
		if player.roll_regen_timer <= 0:
			player.roll_regen_timer = player.roll_cooldown
	
	player.roll_charges_changed.emit(player.current_roll_charges, player.roll_max_charges, player.is_roll_recharging)
	
	# --- ФИЗИКА И СЛОИ ---
	for layer in ghost_layers:
		player.set_collision_mask_value(layer, false)
	
	if player.shape_cast:
		player.shape_cast.enabled = true

	player.anim_player.play(GameConstants.ANIM_PLAYER_ROLL, 0.1, 1.0)
	roll_duration = player.anim_player.get_animation(GameConstants.ANIM_PLAYER_ROLL).length
	current_time = 0.0
	
	# Начальный импульс
	var speed = max(Vector2(player.velocity.x, player.velocity.z).length(), player.roll_speed)
	var forward = player.global_transform.basis.z.normalized()
	player.velocity.x = forward.x * speed
	player.velocity.z = forward.z * speed
	
	player.sfx_roll.play_random()

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	current_time += delta
	var progress = current_time / roll_duration

	# --- 1. ПРЕРЫВАНИЕ ПРЫЖКОМ (JUMP CANCEL) ---
	# Если нажата кнопка прыжка и мы прошли порог (напр. 75% анимации)
	if player.input_handler.check_jump():
		if progress >= player.roll_jump_cancel_threshold:
			player.perform_jump()
			transitioned.emit(self, GameConstants.STATE_AIR)
			return

	# --- 2. ПРЕРЫВАНИЕ АТАКОЙ (ATTACK CANCEL) ---
	# Если нажата атака и мы прошли порог отмены
	if player.input_handler.is_attack_pressed:
		# Обычно порог отмены атаки считается как "последняя часть анимации"
		# Если attack_roll_cancel_threshold = 0.2, значит последние 20% можно отменить
		var can_cancel_attack = progress >= (1.0 - player.attack_roll_cancel_threshold)
		if can_cancel_attack and player.can_attack:
			player.input_handler.check_attack() # Потребляем ввод из буфера
			transitioned.emit(self, GameConstants.STATE_ATTACK)
			return

	# --- УПРАВЛЕНИЕ (STEERING) ---
	var input_dir = player.input_handler.move_vector
	if input_dir != Vector2.ZERO:
		var input_vec3 = Vector3(input_dir.x, 0, input_dir.y)
		var local_input = player.global_transform.basis.inverse() * input_vec3
		var steer_amount = local_input.x
		
		if abs(steer_amount) > 0.1:
			var rotation_strength = player.rot_speed * player.roll_control * delta
			player.rotate_y(steer_amount * rotation_strength)
			
			var speed = Vector2(player.velocity.x, player.velocity.z).length()
			var new_forward = player.global_transform.basis.z.normalized()
			player.velocity.x = new_forward.x * speed
			player.velocity.z = new_forward.z * speed

	player.move_and_slide()

	# Безопасный выход (проверка застревания)
	if progress >= 0.9:
		if player.shape_cast and player.shape_cast.is_colliding():
			var nav_point = player.get_closest_nav_point()
			var push_dir = (nav_point - player.global_position).normalized()
			player.velocity += push_dir * 5.0

	if current_time >= roll_duration:
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return
func exit() -> void:
	player.is_rolling = false
	player.is_invincible = false
	# ВСЕГДА возвращаем коллизии при выходе из состояния
	for layer in ghost_layers:
		player.set_collision_mask_value(layer, true)
	if player.shape_cast: 
		player.shape_cast.enabled = false
