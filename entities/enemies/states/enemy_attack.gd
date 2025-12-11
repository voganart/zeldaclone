extends State

var enemy: Enemy
var is_performing_attack_anim: bool = false
var retreat_timer: float = 0.0

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.set_velocity(Vector3.ZERO) # Стоп перед атакой
	is_performing_attack_anim = false
	
	# Сброс параметров отступления в компоненте
	enemy.attack_component.clear_retreat_state()
	
	# print("[FSM] Enter Attack")

func physics_update(delta: float) -> void:
	# Если мы в процессе анимации атаки — ждем
	if is_performing_attack_anim:
		return
	
	# 1. Логика тактического отступления (если активно)
	if enemy.attack_component.should_tactical_retreat:
		_handle_retreat(delta)
		return
	
	# 2. Проверка валидности цели
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, "patrol") # Или Idle
		return
		
	var dist = enemy.global_position.distance_to(enemy.player.global_position)
	
	# Если игрок убежал далеко -> Chase
	if dist > enemy.attack_component.attack_range * 1.5:
		transitioned.emit(self, "chase")
		return
	
	# 3. Атака или Ожидание
	if enemy.attack_component.is_attack_ready():
		_perform_attack()
	else:
		# Просто смотрим на игрока и ждем отката (Combat Idle)
		enemy.play_animation("Monstr_attack_idle", 0.2, 1.0)
		enemy.handle_rotation(delta, enemy.player.global_position)
		enemy.nav_agent.set_velocity(Vector3.ZERO)

func _perform_attack() -> void:
	is_performing_attack_anim = true
	var anim_name = enemy.attack_component.get_next_attack_animation()
	var impulse = enemy.attack_component.register_attack()
	
	# Применяем импульс вперед (рывок при ударе)
	var forward = enemy.global_transform.basis.z.normalized()
	enemy.receive_push(forward * impulse)
	
	enemy.play_animation(anim_name, 0.2, enemy.attack_component.attack_speed)
	
	# Ждем окончания анимации
	await enemy.anim_player.animation_finished
	
	is_performing_attack_anim = false
	
	# Если после атаки выпал шанс отступить — вычисляем точку
	if enemy.attack_component.should_tactical_retreat:
		enemy.attack_component.calculate_retreat_target(enemy.player)

func _handle_retreat(delta: float) -> void:
	# Если мы в фазе паузы (уже отступили и стоим)
	if enemy.attack_component.tactical_retreat_pause_timer > 0:
		enemy.attack_component.tactical_retreat_pause_timer -= delta
		enemy.nav_agent.set_velocity(Vector3.ZERO)
		enemy.play_animation("Monstr_attack_idle", 0.2, 1.0)
		
		if enemy.attack_component.tactical_retreat_pause_timer <= 0:
			# Пауза закончилась — возвращаемся в бой (Chase решит, атаковать или сблизиться)
			enemy.attack_component.clear_retreat_state()
			transitioned.emit(self, "chase")
		return

	# Движение к точке отступления
	enemy.nav_agent.target_position = enemy.attack_component.tactical_retreat_target
	enemy.nav_agent.max_speed = enemy.run_speed * 0.8
	enemy.move_toward_path()
	
	# Смотрим в сторону движения при отступлении, чтобы не пятиться странно
	enemy.handle_rotation(delta) 
	enemy.update_movement_animation(delta)
	
	# Проверка достижения точки
	if enemy.nav_agent.is_navigation_finished():
		# Достигли -> включаем таймер паузы
		enemy.attack_component.tactical_retreat_pause_timer = enemy.attack_component.get_random_retreat_pause_time()