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
	
	# Торможение во время атаки
	player.velocity.x = move_toward(player.velocity.x, 0, player.stop_speed * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, player.stop_speed * delta)
	
	player.rot_char(delta)
	
# Cancel -> Roll
	# Мы хотим делать перекат из атаки, ТОЛЬКО если игрок:
	# 1. Отпустил кнопку (тапнул)
	# 2. Или нажал её заново (если бы это была отдельная кнопка)
	# Но мы НЕ должны делать ролл, если кнопка просто зажата (бег).
	
	var want_to_roll = player.input_handler.is_run_just_released
	
	if want_to_roll:
		# Проверяем, можно ли отменить атаку на этой стадии (Animation Cancel)
		# И есть ли у нас заряды (can_roll)
		if player.try_cancel_attack_for_roll() and player.can_roll():
			# Просто переходим. Списание заряда произойдет внутри состояния Roll (в методе enter)
			transitioned.emit(self, GameConstants.STATE_ROLL)
			return
	
	if want_to_roll:
		if player.try_cancel_attack_for_roll() and player.can_roll():
			transitioned.emit(self, GameConstants.STATE_ROLL)
			return
			
	if not player.anim_player.is_playing() or player.anim_player.current_animation != anim_name:
		_finish_attack()

func _setup_combo_parameters() -> void:
	# ... (без изменений)
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
	# Нормальное завершение — переходим в Move, а exit() сделает очистку
	transitioned.emit(self, GameConstants.STATE_MOVE)

func exit() -> void:
	# !!! ИЗМЕНЕНИЕ: Гарантированная очистка флагов
	player.is_attacking = false
	
	# Сбрасываем параметры урона, чтобы они не перенеслись случайно
	player.current_attack_knockback_enabled = false
	
	# Если мы прервали атаку (например, кувырком), таймер сброса комбо должен пойти
	if player.combo_reset_timer.is_stopped():
		player.combo_reset_timer.start()

	# Логика кулдауна
	if not player.combo_cooldown_active:
		player.can_attack = true
	
	# На всякий случай отключаем хитбоксы рук, если анимация прервалась на середине
	# (Если Area3D управляются через AnimationPlayer, при смене анимации они сами сбросятся,
	# но если через код - нужно добавить здесь: player.punch_hand_r.monitoring = false)
