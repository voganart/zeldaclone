extends State

var player: Player
var anim_name: String = ""
var attack_friction: float = 25.0
var next_combo_queued: bool = false

func enter() -> void:
	player = entity as Player
	
	# 1. Важные флаги для работы хитбоксов и логики
	player.is_attacking = true
	player.can_attack = false
	next_combo_queued = false
	
	# 2. Останавливаем таймер сброса, так как мы продолжаем серию
	player.combo_reset_timer.stop()
	
	# 3. Настройка параметров (урон и анимация)
	_setup_combo_parameters()
	
	# 4. Физика рывка и звук
	player.apply_attack_impulse()
	player.sfx_attack.play_random()
	
	# 5. Запуск анимации
	player.anim_player.play(anim_name, 0.05, player.primary_attack_speed)

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	var current_pos = player.anim_player.current_animation_position
	var total_len = player.anim_player.current_animation_length
	
	var progress = 0.0
	if total_len > 0:
		progress = current_pos / total_len

	# --- 1. ПРЕРЫВАНИЕ АТАКИ РОЛЛОМ ---
	if player.input_handler.check_roll():
		if player.can_roll():
			if progress >= (1.0 - player.dodge_cancel_attack_threshold):
				transitioned.emit(self, GameConstants.STATE_ROLL)
				return

	# --- 2. ТРЕНИЕ (ТОРМОЖЕНИЕ) ---
	player.velocity.x = move_toward(player.velocity.x, 0, attack_friction * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, attack_friction * delta)
	
	# --- 3. БУФЕРИЗАЦИЯ СЛЕДУЮЩЕГО УДАРА ---
	if (total_len - current_pos) <= 0.2:
		if player.input_handler.check_attack():
			next_combo_queued = true

	# --- 4. ЗАВЕРШЕНИЕ АТАКИ ---
	if not player.anim_player.is_playing() or current_pos >= total_len:
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return

func _setup_combo_parameters() -> void:
	# Используем текущий combo_count (0, 1 или 2)
	player.current_attack_knockback_enabled = true
	
	if player.combo_count == 0:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_1
		player.current_attack_damage = 1.0
	elif player.combo_count == 1:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_2
		player.current_attack_damage = 1.0
	else:
		anim_name = GameConstants.ANIM_PLAYER_ATTACK_3
		player.current_attack_damage = 2.0 # х2 урон на оперкоте
		# Устанавливаем флаг кулдауна серии
		player.combo_cooldown_active = true

func exit() -> void:
	player.is_attacking = false
	
	# Увеличиваем счетчик
	player.combo_count += 1
	
	if player.combo_count >= 3:
		# Серия завершена - сброс и запуск долгого кулдауна
		player.combo_count = 0
		player.combo_cooldown_active = true
		player.can_attack = false
		player.combo_cooldown_timer.start() # combo_cooldown_after_combo
	else:
		# Серия продолжается
		player.combo_cooldown_active = false
		player.can_attack = true
		# Запускаем окно для следующего удара
		player.combo_reset_timer.start() # combo_window_time
