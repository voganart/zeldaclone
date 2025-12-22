extends State

var player: Player
var attack_friction: float = 25.0
var next_combo_queued: bool = false
var current_anim_length: float = 0.0
var elapsed_time: float = 0.0
var anim_resource_name: String = ""

func enter() -> void:
	player = entity as Player
	player.is_attacking = true
	player.can_attack = false
	next_combo_queued = false
	elapsed_time = 0.0
	
	player.combo_reset_timer.stop()
	
	# Вызов функции настройки (она определена ниже)
	_setup_combo_parameters()
	
	player.apply_attack_impulse()
	player.sfx_attack.play_random()
	
	# Устанавливаем скорость в дереве анимации (узел TimeScale)
	player.set_tree_attack_speed(player.primary_attack_speed)
	
	player.trigger_attack(player.combo_count)
	
	# Расчет времени таймера
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

	# Проверка попаданий
	if progress > 0.1 and progress < 0.8:
		player.process_hitbox_check()

	# Прерывание роллом
	if player.input_handler.check_roll():
		if player.can_roll():
			if player.try_cancel_attack_for_roll(progress):
				transitioned.emit(self, GameConstants.STATE_ROLL)
				return

	# Трение
	player.velocity.x = move_toward(player.velocity.x, 0, attack_friction * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, attack_friction * delta)
	
	# Буферизация следующего удара
	if (current_anim_length - elapsed_time) <= 0.25:
		if player.input_handler.check_attack():
			next_combo_queued = true

	# Выход
	if elapsed_time >= current_anim_length:
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return

# === ВОТ ЭТА ФУНКЦИЯ, КОТОРОЙ НЕ ХВАТАЛО ===
func _setup_combo_parameters() -> void:
	player.current_attack_knockback_enabled = true
	
	if player.combo_count == 0:
		anim_resource_name = GameConstants.ANIM_PLAYER_ATTACK_1
		player.current_attack_damage = 1.0
	elif player.combo_count == 1:
		anim_resource_name = GameConstants.ANIM_PLAYER_ATTACK_2
		player.current_attack_damage = 1.0
	else:
		anim_resource_name = GameConstants.ANIM_PLAYER_ATTACK_3
		player.current_attack_damage = 2.0 
		player.combo_cooldown_active = true
# ============================================

func exit() -> void:
	# Сбрасываем скорость дерева в 1.0
	player.set_tree_attack_speed(1.0)
	
	player.stop_hitbox_monitoring()
	player.is_attacking = false
	player.combo_count += 1
	
	if player.combo_count >= 3:
		player.start_combo_cooldown()
	else:
		player.combo_cooldown_active = false
		player.start_attack_cooldown()
		player.combo_reset_timer.start()
