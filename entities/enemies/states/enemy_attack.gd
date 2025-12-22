extends State

var enemy: Enemy
var is_performing_attack_anim: bool = false
var attack_timer: float = 0.0

func enter() -> void:
	enemy = entity as Enemy
	is_performing_attack_anim = false
	attack_timer = 0.0
	
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	enemy.attack_component.clear_retreat_state()
	enemy.set_move_mode("normal") # Для надежности

func physics_update(delta: float) -> void:
	# Если таймер атаки тикает
	if is_performing_attack_anim:
		attack_timer -= delta
		if attack_timer <= 0:
			_finish_attack()
		return
	
	if enemy.attack_component.should_tactical_retreat:
		_handle_retreat(delta)
		return

	_perform_attack()

func _perform_attack() -> void:
	is_performing_attack_anim = true
	
	# 1. Получаем имя анимации (например "Monstr_attack_1")
	var anim_name_full = enemy.attack_component.get_next_attack_animation()
	
	# 2. Маппим имя на индекс в дереве ("Attack1" или "Attack2")
	var tree_attack_idx = "Attack1"
	if "2" in anim_name_full:
		tree_attack_idx = "Attack2"
	
	# 3. Применяем импульс
	var impulse = enemy.attack_component.register_attack()
	var forward = -enemy.global_transform.basis.z.normalized()
	enemy.receive_push(forward * impulse)
	
	# 4. Запускаем OneShot в дереве
	enemy.trigger_attack_oneshot(tree_attack_idx)
	
	# 5. Рассчитываем длительность анимации
	# AnimationTree не дает сигнала finished для веток, поэтому используем таймер
	var anim_length = 1.0 # Дефолт
	if enemy.anim_player.has_animation(anim_name_full):
		anim_length = enemy.anim_player.get_animation(anim_name_full).length
	
	# Учитываем скорость атаки (если мы меняем TimeScale в дереве, но пока просто делим)
	attack_timer = anim_length / enemy.attack_component.attack_speed

func _finish_attack() -> void:
	# Проверка на то, что мы всё еще в этом стейте
	if state_machine.current_state != self: return

	is_performing_attack_anim = false
	AIDirector.return_attack_token(enemy) 
	
	if enemy.attack_component.should_tactical_retreat:
		enemy.attack_component.calculate_retreat_target(enemy.player)
	else:
		transitioned.emit(self, GameConstants.STATE_CHASE)

func _handle_retreat(delta: float) -> void:
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	var dist_to_player = enemy.global_position.distance_to(enemy.player.global_position)
	
	if dist_to_player < enemy.attack_component.retreat_interrupt_range:
		enemy.attack_component.clear_retreat_state()
		transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	# Фаза 1: Пауза
	if enemy.attack_component.tactical_retreat_pause_timer > 0:
		enemy.attack_component.tactical_retreat_pause_timer -= delta
		enemy.nav_agent.set_velocity(Vector3.ZERO)
		# Idle в дереве (move_mode normal, blend 0)
		enemy.set_move_mode("normal")
		enemy.set_locomotion_blend(0.0)
		enemy.handle_rotation(delta, enemy.player.global_position)
		
		if enemy.attack_component.tactical_retreat_pause_timer <= 0:
			enemy.attack_component.clear_retreat_state()
			transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	# Фаза 2: Движение
	enemy.nav_agent.target_position = enemy.attack_component.tactical_retreat_target
	enemy.nav_agent.max_speed = enemy.retreat_speed 
	enemy.move_toward_path()
	enemy.handle_rotation(delta, enemy.player.global_position)
	
	# Анимация: просто ставим Blend Walk, так как "Walking Backwards" нет в дереве пока
	# Если бы была, нужна была бы ветка в BlendSpace (-1)
	enemy.update_movement_animation(delta) 
	
	if enemy.nav_agent.is_navigation_finished():
		enemy.attack_component.tactical_retreat_pause_timer = enemy.attack_component.get_random_retreat_pause_time()

func on_damage_taken() -> void:
	if enemy.attack_component.should_tactical_retreat:
		enemy.attack_component.clear_retreat_state()
		transitioned.emit(self, GameConstants.STATE_CHASE)

func exit() -> void:
	is_performing_attack_anim = false
	AIDirector.return_attack_token(enemy)
