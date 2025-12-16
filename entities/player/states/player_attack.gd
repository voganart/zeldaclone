extends State

var player: Player
var anim_name: String = ""

# Настройка трения специально для атаки
var attack_friction: float = 25.0 # Намного больше, чем обычный stop_speed (8.0)

func enter() -> void:
	player = entity as Player
	player.is_attacking = true
	player.can_attack = false
	player.combo_reset_timer.stop()
	
	_setup_combo_parameters()
	
	# Импульс применяется ОДИН раз при входе
	# Внутри него velocity обнуляется и задается новый рывок
	player.apply_attack_impulse()
	
	# ЗВУК АТАКИ
	player.sfx_attack.play_random()
	
	player.anim_player.play(anim_name, 0.0, player.primary_attack_speed)

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	# === АГРЕССИВНОЕ ТОРМОЖЕНИЕ ===
	# Вместо плавного скольжения, мы быстро гасим импульс.
	# Это создает ощущение "Snappy" (резкости).
	# Игрок делает рывок (в enter) и почти сразу останавливается.
	player.velocity.x = move_toward(player.velocity.x, 0, attack_friction * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, attack_friction * delta)
	
	# Вращение во время атаки (обычно замедленное или отключенное)
	# Если мы используем Soft Lock, то мы уже повернулись в начале.
	# Можно оставить небольшую возможность корректировки.
	player.rot_char(delta)
	
	# === ОТМЕНА АТАКИ В РОЛЛ ===
	if player.input_handler.is_roll_buffered:
		if player.try_cancel_attack_for_roll() and player.can_roll():
			player.input_handler.check_roll()
			transitioned.emit(self, GameConstants.STATE_ROLL)
			return
			
	if not player.anim_player.is_playing() or player.anim_player.current_animation != anim_name:
		_finish_attack()

func _setup_combo_parameters() -> void:
	var combo_step = player.combo_count % 3
	if combo_step == 0:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_1
		player.current_attack_damage = 1.0
		player.current_attack_knockback_enabled = true
	elif combo_step == 1:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_2
		player.current_attack_damage = 1.0
		player.current_attack_knockback_enabled = true
	else:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_3
		player.current_attack_damage = 2.0
		player.current_attack_knockback_enabled = true
		player.start_combo_cooldown()

	player.combo_count = (player.combo_count + 1) % 3

func _finish_attack() -> void:
	transitioned.emit(self, GameConstants.STATE_MOVE)

func exit() -> void:
	player.is_attacking = false
	player.current_attack_knockback_enabled = false
	
	if player.combo_reset_timer.is_stopped():
		player.combo_reset_timer.start()

	if not player.combo_cooldown_active:
		player.can_attack = true
