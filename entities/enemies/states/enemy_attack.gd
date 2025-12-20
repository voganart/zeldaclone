extends State

var enemy: Enemy
var is_performing_attack_anim: bool = false

func enter() -> void:
	enemy = entity as Enemy
	is_performing_attack_anim = false
	enemy.nav_agent.set_velocity(Vector3.ZERO) # Гарантированно останавливаем при входе
	enemy.attack_component.clear_retreat_state()

func physics_update(delta: float) -> void:
	# Если мы в процессе анимации удара — ничего не делаем, ждем await
	if is_performing_attack_anim:
		return
	
	# Если выпал шанс на тактическое отступление — выполняем его
	if enemy.attack_component.should_tactical_retreat:
		_handle_retreat(delta)
		return

	# Иначе — атакуем
	_perform_attack()

func _perform_attack() -> void:
	is_performing_attack_anim = true
	
	var anim_name = enemy.attack_component.get_next_attack_animation()
	var impulse = enemy.attack_component.register_attack()
	
	# Рывок вперед при атаке
	var forward = -enemy.global_transform.basis.z.normalized()
	enemy.receive_push(forward * impulse)
	
	enemy.play_animation(anim_name, 0.2, enemy.attack_component.attack_speed)
	
	# Ждем окончания анимации
	await enemy.anim_player.animation_finished
	
	# ЗАЩИТА: Если за время анимации нас "выбили" из этого состояния (например, ударом 3)
	if state_machine.current_state != self:
		return

	is_performing_attack_anim = false
	AIDirector.return_attack_token(enemy) 
	
	# Проверяем, нужно ли отступать после удара
	if enemy.attack_component.should_tactical_retreat:
		enemy.attack_component.calculate_retreat_target(enemy.player)
	else:
		transitioned.emit(self, GameConstants.STATE_CHASE)

func _handle_retreat(delta: float) -> void:
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	var dist_to_player = enemy.global_position.distance_to(enemy.player.global_position)
	
	# Если игрок слишком близко, отменяем отступление и идем в погоню (или атаку)
	if dist_to_player < enemy.attack_component.retreat_interrupt_range:
		enemy.attack_component.clear_retreat_state()
		transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	# Фаза 1: Пауза после отхода (стоим и смотрим на игрока)
	if enemy.attack_component.tactical_retreat_pause_timer > 0:
		enemy.attack_component.tactical_retreat_pause_timer -= delta
		enemy.nav_agent.set_velocity(Vector3.ZERO)
		enemy.play_animation(GameConstants.ANIM_ENEMY_ATTACK_IDLE, 0.2, 1.0)
		enemy.handle_rotation(delta, enemy.player.global_position)
		
		if enemy.attack_component.tactical_retreat_pause_timer <= 0:
			enemy.attack_component.clear_retreat_state()
			transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	# Фаза 2: Движение к точке отступления
	enemy.nav_agent.target_position = enemy.attack_component.tactical_retreat_target
	enemy.nav_agent.max_speed = enemy.retreat_speed 
	enemy.move_toward_path()
	
	# Поворот к игроку во время отхода (пятится назад)
	enemy.handle_rotation(delta, enemy.player.global_position)
	
	# Анимация движения (назад или обычная, если нет специальной)
	if enemy.anim_player.has_animation("Monstr_walk_backwards"):
		enemy.play_animation("Monstr_walk_backwards", 0.2)
	else:
		enemy.update_movement_animation(delta) 
	
	# Если достигли точки отхода — включаем таймер паузы
	if enemy.nav_agent.is_navigation_finished():
		enemy.attack_component.tactical_retreat_pause_timer = enemy.attack_component.get_random_retreat_pause_time()

func on_damage_taken() -> void:
	# Если нас ударили во время отступления — сбрасываем его и злимся
	if enemy.attack_component.should_tactical_retreat:
		enemy.attack_component.clear_retreat_state()
		transitioned.emit(self, GameConstants.STATE_CHASE)

func exit() -> void:
	is_performing_attack_anim = false
	AIDirector.return_attack_token(enemy)
