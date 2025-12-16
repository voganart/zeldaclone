extends State

var player: Player
var roll_duration: float = 0.0
var current_time: float = 0.0

var has_buffered_jump: bool = false
var jump_buffer_timer: float = 0.0

var collision_restored: bool = false

# === НОВАЯ НАСТРОЙКА ===
# Сюда в Инспекторе добавь номера слоев.
# Например: [3] (Враги) и [5] (Ящики, если они на 5 слое).
@export var pass_through_layers: Array[int] = [3,5] 

func enter() -> void:
	player = entity as Player
	player.is_rolling = true
	player.sfx_roll.play_random()
	player.is_invincible = true
	
	# === 1. ОТКЛЮЧАЕМ ВСЕ СЛОИ ИЗ СПИСКА ===
	# Проходимся по массиву и отключаем маску для каждого слоя
	for layer_idx in pass_through_layers:
		player.set_collision_mask_value(layer_idx, false)
		
	collision_restored = false
	
	has_buffered_jump = false
	jump_buffer_timer = 0.0
	
	player.current_roll_charges -= 1
	if player.current_roll_charges <= 0:
		player.is_roll_recharging = true
		player.roll_penalty_timer = player.roll_recharge_time
		player.roll_regen_timer = 0.0
	else:
		if player.roll_regen_timer <= 0:
			player.roll_regen_timer = player.roll_cooldown
	
	player.roll_charges_changed.emit(player.current_roll_charges, player.roll_max_charges, player.is_roll_recharging)
	
	var current_speed_2d = Vector2(player.velocity.x, player.velocity.z).length()
	var bonus = 0.0
	if player.is_trying_to_run or player.is_auto_running or player.shift_pressed_time > player.roll_threshold:
		bonus = player.run_speed * 0.2
		
	var target_roll_speed = player.roll_speed + bonus
	var final_speed = max(current_speed_2d, target_roll_speed)
	
	var forward = player.global_transform.basis.z.normalized()
	player.velocity.x = forward.x * final_speed
	player.velocity.z = forward.z * final_speed
	
	player.anim_player.play(GameConstants.ANIM_PLAYER_ROLL, 0.1, 1.0)
	roll_duration = player.anim_player.get_animation(GameConstants.ANIM_PLAYER_ROLL).length
	current_time = 0.0
	
	var iframe_time = roll_duration * player.roll_invincibility_duration
	get_tree().create_timer(iframe_time).timeout.connect(func(): player.is_invincible = false)

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	current_time += delta
	
	var progress = 0.0
	if roll_duration > 0:
		progress = current_time / roll_duration
	
	# === 2. ВОЗВРАЩАЕМ КОЛЛИЗИЮ ДЛЯ ВСЕХ СЛОЕВ ===
	if not collision_restored and progress >= 0.7:
		for layer_idx in pass_through_layers:
			player.set_collision_mask_value(layer_idx, true)
		collision_restored = true
	
	# --- БУФЕР ПРЫЖКА ---
	if player.input_handler.check_jump():
		has_buffered_jump = true
		jump_buffer_timer = 0.0
	
	if has_buffered_jump:
		jump_buffer_timer += delta
		if jump_buffer_timer > player.buffered_jump_max_time:
			has_buffered_jump = false

	var can_cancel_jump = progress >= player.roll_jump_cancel_threshold
	if current_time < player.buffered_jump_min_time:
		can_cancel_jump = false
		
	if has_buffered_jump and can_cancel_jump:
		_perform_roll_jump()
		return
		
	# --- ОТМЕНА В АТАКУ ---
	if player.input_handler.is_attack_pressed:
		var required_progress = 1.0 - player.attack_roll_cancel_threshold
		if progress >= required_progress:
			if player.can_attack:
				player.input_handler.check_attack()
				transitioned.emit(self, GameConstants.STATE_ATTACK)
				return

	# --- STEERING ---
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
	player.push_obj()

	if current_time >= roll_duration:
		if has_buffered_jump:
			_perform_roll_jump()
		else:
			if player.roll_chain_delay > 0:
				player.roll_interval_timer = player.roll_chain_delay
			transitioned.emit(self, GameConstants.STATE_MOVE)

func _perform_roll_jump() -> void:
	player.perform_jump()
	transitioned.emit(self, GameConstants.STATE_AIR)

func exit() -> void:
	player.is_rolling = false
	player.is_invincible = false
	
	# === 3. ГАРАНТИРОВАННО ВКЛЮЧАЕМ ВСЕ СЛОИ ОБРАТНО ===
	for layer_idx in pass_through_layers:
		player.set_collision_mask_value(layer_idx, true)
