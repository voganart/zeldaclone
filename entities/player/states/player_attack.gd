extends State

var player: Player
var anim_name: String = ""
var attack_friction: float = 25.0
var next_combo_queued: bool = false

func enter() -> void:
	player = entity as Player
	player.is_attacking = true
	player.can_attack = false # Блокируем, чтобы не спамить мгновенно
	next_combo_queued = false
	
	_setup_combo_parameters()
	player.apply_attack_impulse()
	player.sfx_attack.play_random()
	
	# Запускаем анимацию
	player.anim_player.play(anim_name, 0.05, player.primary_attack_speed)

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	# Гасим инерцию рывка
	player.velocity.x = move_toward(player.velocity.x, 0, attack_friction * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, attack_friction * delta)
	
	var current_pos = player.anim_player.current_animation_position
	var total_len = player.anim_player.current_animation_length
	
	# Окно буферизации для следующего удара
	if (total_len - current_pos) <= 0.2:
		if player.input_handler.check_attack():
			next_combo_queued = true

	# Если анимация закончилась
	if not player.anim_player.is_playing() or current_pos >= total_len:
		transitioned.emit(self, GameConstants.STATE_MOVE)

func _setup_combo_parameters() -> void:
	var combo_step = player.combo_count % 3
	if combo_step == 0:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_1
		player.current_attack_damage = 1.0
	elif combo_step == 1:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_2
		player.current_attack_damage = 1.0
	else:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_3
		player.current_attack_damage = 2.0
		player.start_combo_cooldown() # Здесь включится глобальный кулдаун комбо

	player.combo_count = (player.combo_count + 1) % 3

func exit() -> void:
	player.is_attacking = false
	# Если мы не на глобальном кулдауне после 3-го удара, разрешаем атаковать снова
	if not player.combo_cooldown_active:
		player.can_attack = true
	
	# Запускаем таймер сброса комбо, если игрок перестал бить
	if player.combo_reset_timer.is_stopped():
		player.combo_reset_timer.start()
