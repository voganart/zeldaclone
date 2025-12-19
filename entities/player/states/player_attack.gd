extends State

var player: Player
var anim_name: String = ""
var attack_friction: float = 25.0
var next_combo_queued: bool = false

func enter() -> void:
	player = entity as Player
	player.is_attacking = true
	player.can_attack = false
	next_combo_queued = false
	
	_setup_combo_parameters()
	player.apply_attack_impulse()
	player.sfx_attack.play_random()
	player.anim_player.play(anim_name, 0.05, player.primary_attack_speed)

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	# --- ПРЕРЫВАНИЕ АТАКИ РОЛЛОМ (Dodge Cancel) ---
	if player.input_handler.check_roll():
		if player.can_roll():
			var current_pos = player.anim_player.current_animation_position
			var total_len = player.anim_player.current_animation_length
			var progress = current_pos / total_len
			
			# Если dodge_cancel_attack_threshold = 1.0, то (1.0 - 1.0) = 0, прерывание разрешено сразу
			if progress >= (1.0 - player.dodge_cancel_attack_threshold):
				transitioned.emit(self, GameConstants.STATE_ROLL)
				return

	# Трение (торможение)
	player.velocity.x = move_toward(player.velocity.x, 0, attack_friction * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, attack_friction * delta)
	
	var current_pos = player.anim_player.current_animation_position
	var total_len = player.anim_player.current_animation_length
	
	# Буферизация следующего удара
	if (total_len - current_pos) <= 0.2:
		if player.input_handler.check_attack():
			next_combo_queued = true

	if not player.anim_player.is_playing() or current_pos >= total_len:
		transitioned.emit(self, GameConstants.STATE_MOVE)

func _setup_combo_parameters() -> void:
	var combo_step = player.combo_count % 3
	if combo_step == 0:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_1
	elif combo_step == 1:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_2
	else:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_3
		player.start_combo_cooldown()
	player.combo_count = (player.combo_count + 1) % 3

func exit() -> void:
	player.is_attacking = false
	if not player.combo_cooldown_active:
		player.can_attack = true
	if player.combo_reset_timer.is_stopped():
		player.combo_reset_timer.start()
