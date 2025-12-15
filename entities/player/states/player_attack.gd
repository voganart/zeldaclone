extends State

var player: Player
var anim_name: String = ""

func enter() -> void:
	player = entity as Player
	player.is_attacking = true
	player.can_attack = false
	player.combo_reset_timer.stop()
	
	_setup_combo_parameters()
	player.apply_attack_impulse()
	player.anim_player.play(anim_name, 0.0, player.primary_attack_speed)

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0, player.stop_speed * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, player.stop_speed * delta)
	player.rot_char(delta)
	
	# === ОТМЕНА АТАКИ В РОЛЛ ===
	# 1. Сначала проверяем, есть ли желание (кнопка нажата), НЕ СТИРАЯ буфер.
	if player.input_handler.is_roll_buffered:
		# 2. Проверяем, достигла ли анимация точки отмены (threshold)
		# И есть ли у нас стамина/заряды.
		if player.try_cancel_attack_for_roll() and player.can_roll():
			# 3. Если всё ок — "Тратим" нажатие и переходим.
			player.input_handler.check_roll()
			transitioned.emit(self, GameConstants.STATE_ROLL)
			return
			
	# Завершение атаки
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
