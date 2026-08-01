extends State

enum AttackPhase { WINDUP, ACTIVE, RECOVERY, RETREAT }

var enemy: Enemy
var is_performing_attack_anim: bool = false
var attack_timer: float = 0.0
var attack_elapsed: float = 0.0
var hit_time: float = 0.0
var active_end_time: float = 0.0
var direction_lock_time: float = 0.0
var recovery_timer: float = 0.0
var attack_phase: AttackPhase = AttackPhase.WINDUP

# НАСТРОЙКА: За сколько секунд до удара показать "!"
# 0.4 - оптимально для реакции.
# Если поставить 0.0, знак появится ровно в момент удара.
# Если поставить отрицательное число (не надо), логика сломается.
@export var warning_lead_time: float = 0.4 
@export var direction_lock_lead_time: float = 0.15
@export var recovery_duration: float = 0.5

func enter() -> void:
	enemy = entity as Enemy
	is_performing_attack_anim = false
	attack_timer = 0.0
	attack_elapsed = 0.0
	recovery_timer = recovery_duration
	attack_phase = AttackPhase.WINDUP
	
	# Полная остановка и подготовка
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	enemy.set_move_mode("chase")
	
	# Включаем "радар" хитбоксов (урон нанесется только при вызове из анимации)
	if enemy.combat_component:
		enemy.combat_component.start_hitbox_monitoring()
		
	# Запускаем атаку сразу
	_perform_attack()

func physics_update(delta: float) -> void:
	enemy.update_movement_animation(delta) 

	if attack_phase == AttackPhase.RETREAT:
		_handle_retreat(delta)
		return

	attack_elapsed += delta
	attack_timer = max(attack_timer - delta, 0.0)

	if attack_phase == AttackPhase.WINDUP:
		if is_instance_valid(enemy.player) and attack_elapsed < direction_lock_time:
			enemy.handle_rotation(delta, enemy.player.global_position, enemy.attack_rotation_speed)
		if attack_elapsed >= hit_time:
			attack_phase = AttackPhase.ACTIVE

	if attack_phase == AttackPhase.ACTIVE and attack_elapsed >= active_end_time:
		attack_phase = AttackPhase.RECOVERY

	if attack_phase == AttackPhase.RECOVERY and attack_timer <= 0:
		is_performing_attack_anim = false
		enemy.nav_agent.set_velocity(Vector3.ZERO)
		recovery_timer -= delta
		if recovery_timer <= 0:
			_finish_attack()

func _perform_attack() -> void:
	is_performing_attack_anim = true
	
	# 1. Получаем имя анимации (например, "Monstr_attack_1")
	var anim_name_full = enemy.attack_component.get_next_attack_animation()
	
	# 2. === АВТО-РАСЧЕТ ТАЙМИНГА ===
	# Ищем, на какой секунде стоит вызов _check_attack_hit
	var attack_speed = max(enemy.attack_component.attack_speed, 0.01)
	hit_time = _get_hit_time_from_animation(anim_name_full) / attack_speed
	active_end_time = hit_time + 0.1
	direction_lock_time = max(hit_time - direction_lock_lead_time, 0.0)
	
	# Считаем задержку: (Время удара) - (Время на реакцию)
	# Пример: Удар на 0.8с, предупредить за 0.4с -> ждем 0.4с и показываем знак.
	var icon_delay = hit_time - warning_lead_time
	
	# Защита от отрицательных чисел (если удар слишком быстрый)
	if icon_delay < 0: icon_delay = 0.0
	
	# Запускаем показ иконки
	_spawn_warning_icon(icon_delay)
	# ==============================
	
	# 3. Применяем рывок (импульс)
	var impulse = enemy.attack_component.register_attack()
	var forward = enemy.global_transform.basis.z.normalized()
	enemy.receive_push(forward * impulse)
	
	# 4. Запускаем анимацию в дереве
	var tree_attack_idx = "Attack1"
	if "2" in anim_name_full: tree_attack_idx = "Attack2"
	enemy.trigger_attack_oneshot(tree_attack_idx)
	
	# 5. Считаем длительность всего стейта
	var anim_length = 1.0
	if enemy.anim_player.has_animation(anim_name_full):
		anim_length = enemy.anim_player.get_animation(anim_name_full).length
	
	attack_timer = anim_length / attack_speed

## Функция-ищейка: находит время удара внутри анимации
func _get_hit_time_from_animation(anim_name: String) -> float:
	if not enemy.anim_player.has_animation(anim_name):
		return 0.5 # Запасной вариант
		
	var anim = enemy.anim_player.get_animation(anim_name)
	
	# Перебираем все треки
	for track_idx in range(anim.get_track_count()):
		# Ищем трек вызова методов (Call Method Track)
		if anim.track_get_type(track_idx) != Animation.TYPE_METHOD:
			continue
			
		# Перебираем ключи в треке
		for key_idx in range(anim.track_get_key_count(track_idx)):
			var key_data = anim.track_get_key_value(track_idx, key_idx)
			# Если нашли функцию удара - возвращаем её время
			if key_data["method"] == "_check_attack_hit":
				return anim.track_get_key_time(track_idx, key_idx)
	
	# Если ключа нет, возвращаем начало анимации (сразу предупреждаем)
	return 0.0

## Асинхронный спавн иконки
func _spawn_warning_icon(delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	
	# Если враг умер или его ударили во время ожидания - отмена
	if state_machine.current_state != self: return
	
	if enemy.has_node("AlertIndicator"):
		# Показываем красный восклицательный знак на 0.4 сек
		enemy.alert_indicator.play_attack_warning(0.4)

func _finish_attack() -> void:
	if state_machine.current_state != self: return

	is_performing_attack_anim = false
	AIDirector.return_attack_token(enemy) 
	
	if enemy.attack_component.should_tactical_retreat:
		enemy.attack_component.calculate_retreat_target(enemy.player)
		attack_phase = AttackPhase.RETREAT
	else:
		transitioned.emit(self, GameConstants.STATE_CHASE)

func _handle_retreat(delta: float) -> void:
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	var dist_to_player = enemy.global_position.distance_to(enemy.player.global_position)
	
	# Если игрок подошел слишком близко - прерываем отступление
	if dist_to_player < enemy.attack_component.retreat_interrupt_range:
		enemy.attack_component.clear_retreat_state()
		transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	# Фаза паузы (враг стоит и смотрит)
	if enemy.attack_component.tactical_retreat_pause_timer > 0:
		enemy.attack_component.tactical_retreat_pause_timer -= delta
		enemy.nav_agent.set_velocity(Vector3.ZERO)
		enemy.set_move_mode("chase") 
		enemy.handle_rotation(delta, enemy.player.global_position)
		
		if enemy.attack_component.tactical_retreat_pause_timer <= 0:
			enemy.attack_component.clear_retreat_state()
			transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	# Фаза движения (враг убегает на позицию)
	enemy.nav_agent.target_position = enemy.attack_component.tactical_retreat_target
	enemy.nav_agent.max_speed = enemy.retreat_speed 
	enemy.move_toward_path()
	enemy.handle_rotation(delta, enemy.player.global_position)
	enemy.set_move_mode("chase")
	enemy.update_movement_animation(delta) 
	
	if enemy.nav_agent.is_navigation_finished():
		enemy.attack_component.tactical_retreat_pause_timer = enemy.attack_component.get_random_retreat_pause_time()

# --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
func on_damage_taken(is_heavy: bool = false) -> void:
	# Прерываем атаку ТОЛЬКО если удар был тяжелым
	if is_heavy:
		is_performing_attack_anim = false
		AIDirector.return_attack_token(enemy)
		transitioned.emit(self, GameConstants.STATE_CHASE)
	# В противном случае ничего не делаем, враг продолжает атаку (Hyper Armor)

func exit() -> void:
	is_performing_attack_anim = false
	attack_phase = AttackPhase.RECOVERY
	AIDirector.return_attack_token(enemy)
	if enemy.combat_component:
		enemy.combat_component._stop_hitbox_monitoring()
