extends State

var player: Player
var roll_duration: float = 0.0
var elapsed_time: float = 0.0
# Убрали переменную ghost_layers

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
	# УБРАЛИ ОТКЛЮЧЕНИЕ КОЛЛИЗИЙ. Теперь мы толкаем объекты собой.
	if player.shape_cast:
		player.shape_cast.enabled = true

	# Запуск анимации
	player.trigger_roll()
	
	if player.anim_player.has_animation(GameConstants.ANIM_PLAYER_ROLL):
		roll_duration = player.anim_player.get_animation(GameConstants.ANIM_PLAYER_ROLL).length
	else:
		roll_duration = 0.6
	
	# === УПРАВЛЕНИЕ СКОРОСТЬЮ ROOT MOTION ===
	var current_speed_2d = Vector2(player.velocity.x, player.velocity.z).length()
	var speed_factor = clamp(current_speed_2d / player.run_speed, 0.0, 1.0)
	
	player.root_motion_speed_factor = lerp(player.roll_min_speed, player.roll_max_speed, speed_factor)
	
	player.sfx_roll.play_random()

func physics_update(delta: float) -> void:
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

	# Проверка застревания (если уперлись в стену)
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
	player.root_motion_speed_factor = 1.0
	
	# Убрали восстановление масок, так как мы их не меняли
	if player.shape_cast:
		player.shape_cast.enabled = false
		
	var input_vec = player.input_handler.move_vector
	if input_vec.length() > 0.01:
		if player.is_trying_to_run:
			player.current_movement_blend = player.blend_value_run
		else:
			player.current_movement_blend = player.blend_value_walk
		
		player.set_locomotion_blend(player.current_movement_blend)
