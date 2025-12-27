extends State

var player: Player
var attack_friction: float = 25.0
var current_anim_length: float = 0.0
var elapsed_time: float = 0.0
var anim_resource_name: String = ""

# Флаг для предотвращения преждевременного выхода при self-transition
var is_chaining: bool = false

func enter() -> void:
	player = entity as Player
	player.is_attacking = true
	# Мы НЕ ставим can_attack = false здесь, если это чейнинг,
	# но так как мы контролируем это вручную, можно оставить как есть.
	player.can_attack = false
	
	# === ИСПРАВЛЕНИЕ НАЧАЛО ===
	# 1. Сбрасываем таймер активности хитбокса. 
	# Это предотвращает "перенос" активной фазы удара с предыдущей атаки на новую,
	# что вызывало мгновенную регистрацию удара на 1-м кадре и блокировку реального удара.
	player.hitbox_active_timer = 0.0
	
	# 2. Принудительно очищаем список, чтобы гарантировать, что враги могут получить урон снова.
	if player.hit_enemies_current_attack:
		player.hit_enemies_current_attack.clear()
	# === ИСПРАВЛЕНИЕ КОНЕЦ ===
	
	elapsed_time = 0.0
	is_chaining = false
	
	player.combo_reset_timer.stop()
	
	_setup_combo_parameters()
	
	# Поворот и импульс
	player.apply_attack_impulse()
	player.sfx_attack.play_random()
	
	# Скорость анимации
	player.set_tree_attack_speed(player.primary_attack_speed)
	
	# Запуск анимации в дереве
	player.trigger_attack(player.combo_count)
	
	# Расчет длительности
	if player.anim_player.has_animation(anim_resource_name):
		var raw_len = player.anim_player.get_animation(anim_resource_name).length
		var speed = player.primary_attack_speed
		if speed <= 0.01: speed = 0.01
		current_anim_length = raw_len / speed
	else:
		current_anim_length = 0.5
		push_warning("Animation not found: " + anim_resource_name)
	
	player.start_hitbox_monitoring()

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.rot_char(delta)
	
	elapsed_time += delta
	var progress = 0.0
	if current_anim_length > 0:
		progress = elapsed_time / current_anim_length

	# --- 1. ПРЕРЫВАНИЕ РОЛЛОМ ---
	if player.input_handler.check_roll():
		if player.can_roll():
			if player.try_cancel_attack_for_roll(progress):
				transitioned.emit(self, GameConstants.STATE_ROLL)
				return

	# --- 2. ЛОГИКА КОМБО (CHAINING) ---
	# Если это не финишер (combo_count 2 в примере, то есть 3-й удар)
	if player.combo_count < 2:
		# Проверяем, прошло ли минимальное время (Cancel Window)
		if elapsed_time >= player.attack_cooldown:
			# Если есть ввод атаки
			if player.input_handler.check_attack():
				is_chaining = true
				_advance_combo()
				# ПЕРЕЗАПУСК СОСТОЯНИЯ (Self-Transition)
				state_machine.change_state(GameConstants.STATE_ATTACK)
				return
	
	# --- 3. ФИЗИКА ТРЕНИЯ ---
	player.velocity.x = move_toward(player.velocity.x, 0, attack_friction * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, attack_friction * delta)
	
	# --- 4. ЗАВЕРШЕНИЕ АНИМАЦИИ ---
	if elapsed_time >= current_anim_length:
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return

func _setup_combo_parameters() -> void:
	player.current_attack_knockback_enabled = true
	
	if player.combo_count == 0:
		# Удар 1
		anim_resource_name = GameConstants.ANIM_PLAYER_ATTACK_1
		player.current_attack_damage = 1.0
		player.has_hyper_armor = false
		
		# Настройки отталкивания NORMAL
		player.current_knockback_strength = player.kb_strength_normal
		player.current_knockback_height = player.kb_height_normal
		
	elif player.combo_count == 1:
		# Удар 2
		anim_resource_name = GameConstants.ANIM_PLAYER_ATTACK_2
		player.current_attack_damage = 1.0
		player.has_hyper_armor = false
		
		# Настройки отталкивания NORMAL
		player.current_knockback_strength = player.kb_strength_normal
		player.current_knockback_height = player.kb_height_normal
		
	else:
		# === ФИНИШЕР (Удар 3) ===
		anim_resource_name = GameConstants.ANIM_PLAYER_ATTACK_3
		player.current_attack_damage = 2.0 
		player.combo_cooldown_active = true
		player.has_hyper_armor = true
		
		# Настройки отталкивания FINISHER
		player.current_knockback_strength = player.kb_strength_finisher
		player.current_knockback_height = player.kb_height_finisher

func _advance_combo() -> void:
	player.combo_count += 1

func exit() -> void:
	player.set_tree_attack_speed(1.0)
	player.has_hyper_armor = false
	
	if is_chaining:
		# !!! ВАЖНОЕ ИСПРАВЛЕНИЕ !!!
		# Если мы переходим в следующую атаку, НЕ выключаем хитбоксы,
		# чтобы избежать состояния "monitoring = false" на одном кадре,
		# что вызывает краш при вызове get_overlapping_bodies.
		# (Список попаданий очистится в enter -> start_hitbox_monitoring)
		pass
	else:
		player.stop_hitbox_monitoring()
		player.is_attacking = false
		player.combo_count += 1
		
		if player.combo_count >= 3:
			player.start_combo_cooldown() # Долгий откат после финишера
		else:
			player.combo_cooldown_active = false
			player.start_attack_cooldown() # Короткий откат между ударами вне чейна
			player.combo_reset_timer.start() # Таймер сброса серии
