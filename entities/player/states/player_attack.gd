extends State

var player: Player
var anim_name: String = ""

func enter() -> void:
	player = entity as Player
	player.is_attacking = true
	player.can_attack = false
	player.combo_reset_timer.stop()
	
	# 1. Определяем анимацию и параметры комбо
	_setup_combo_parameters()
	
	# 2. Применяем импульс движения (рывок при ударе)
	player.apply_attack_impulse()
	
	# 3. Запуск анимации
	player.anim_player.play(anim_name, 0.0, player.primary_attack_speed)
	
	# print("[FSM] Player Attack: ", anim_name)

func physics_update(delta: float) -> void:
	# Гравитация (чтобы не зависать, если ударили на краю)
	player.apply_gravity(delta)
	
	# Трение (замедление рывка)
	player.velocity.x = move_toward(player.velocity.x, 0, player.stop_speed * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, player.stop_speed * delta)
	
	# Вращение (немного можно поворачивать во время удара)
	player.rot_char(delta)
	
	# --- ПЕРЕХОДЫ ---
	
	# Cancel -> Roll (Прерывание атаки кувырком)
	# Используем ту же логику проверки кнопки, что и в player_move
	var run_just_released = Input.is_action_just_released(GameConstants.INPUT_RUN)
	var roll_pressed = Input.is_action_just_pressed(GameConstants.INPUT_RUN) # Если есть отдельная кнопка
	
	var want_to_roll = roll_pressed or (run_just_released and player.shift_pressed_time <= player.roll_threshold)
	
	if want_to_roll:
		if player.try_cancel_attack_for_roll() and player.can_roll():
			transitioned.emit(self, GameConstants.STATE_ROLL)
			return
			
	# End of Animation
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
		
		# Финишер запускает кулдаун
		player.start_combo_cooldown()

	player.combo_count = (player.combo_count + 1) % 3

func _finish_attack() -> void:
	# Логика нормального завершения атаки
	player.is_attacking = false
	player.combo_reset_timer.start()
	
	# Если кулдаун не активен (не было финишера), разрешаем следующую атаку
	if not player.combo_cooldown_active:
		player.can_attack = true
		
	transitioned.emit(self, GameConstants.STATE_MOVE)

func exit() -> void:
	player.is_attacking = false
	
	# --- ИСПРАВЛЕНИЕ БАГА ---
	# Если мы вышли из состояния (например, через Roll) до завершения анимации,
	# нам нужно убедиться, что мы разблокировали возможность атаковать.
	# Исключение: если мы только что сделали финишер (3-й удар), то кулдаун уже тикает в Player.gd
	if not player.combo_cooldown_active:
		player.can_attack = true
