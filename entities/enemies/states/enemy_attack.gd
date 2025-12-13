extends State

var enemy: Enemy
var is_performing_attack_anim: bool = false
var retreat_timer: float = 0.0

func enter() -> void:
	enemy = entity as Enemy
	is_performing_attack_anim = false
	enemy.nav_agent.set_velocity(Vector3.ZERO) # Гарантированно останавливаем
	enemy.attack_component.clear_retreat_state()

func physics_update(delta: float) -> void:
	# Если мы уже в процессе анимации атаки — просто ждем ее окончания.
	if is_performing_attack_anim:
		return
	
	# Логика тактического отступления
	if enemy.attack_component.should_tactical_retreat:
		_handle_retreat(delta)
		return

	_perform_attack()

func _perform_attack() -> void:
	is_performing_attack_anim = true
	
	# !!! ВАЖНО: Мы полностью убрали отсюда look_at и любую другую логику поворота.
	# Враг должен быть уже нацелен благодаря physics_update.
	
	var anim_name = enemy.attack_component.get_next_attack_animation()
	var impulse = enemy.attack_component.register_attack()
	
	# Используем -Z как "вперед", предполагая, что модель врага в редакторе
	# сориентирована правильно (смотрит в противоположную сторону от синей стрелки).
	var forward = -enemy.global_transform.basis.z.normalized()
	enemy.receive_push(forward * impulse)
	
	enemy.play_animation(anim_name, 0.2, enemy.attack_component.attack_speed)
	
	# Ждем окончания анимации
	await enemy.anim_player.animation_finished
	
	is_performing_attack_anim = false
	AIDirector.return_attack_token(enemy) 
	
	# Если после атаки выпал шанс отступить — вычисляем точку
	if enemy.attack_component.should_tactical_retreat:
		enemy.attack_component.calculate_retreat_target(enemy.player)
	else:
		# Если не отступаем, немедленно возвращаемся в Chase для переоценки обстановки.
		transitioned.emit(self, GameConstants.STATE_CHASE)

func _handle_retreat(delta: float) -> void:
	# !!! НОВЫЙ БЛОК ПРОВЕРКИ В САМОМ НАЧАЛЕ
	if is_instance_valid(enemy.player):
		var dist_to_player = enemy.global_position.distance_to(enemy.player.global_position)
		
		# Если игрок слишком близко, отменяем отступление и идем в погоню
		if dist_to_player < enemy.attack_component.retreat_interrupt_range:
			# Сбрасываем все флаги отступления
			enemy.attack_component.clear_retreat_state()
			# Переходим в состояние Chase. Оно само решит, атаковать сразу или нет.
			transitioned.emit(self, GameConstants.STATE_CHASE)
			return # Важно! Прекращаем выполнение остальной логики отступления
	# Фаза 1: Отступили и стоим в паузе, наблюдая за игроком
	if enemy.attack_component.tactical_retreat_pause_timer > 0:
		enemy.attack_component.tactical_retreat_pause_timer -= delta
		enemy.nav_agent.set_velocity(Vector3.ZERO)
		enemy.play_animation(GameConstants.ANIM_ENEMY_ATTACK_IDLE, 0.2, 1.0)
		
		# !!! ВАЖНО: Даже в паузе смотрим на игрока
		if is_instance_valid(enemy.player):
			enemy.handle_rotation(delta, enemy.player.global_position)
		
		if enemy.attack_component.tactical_retreat_pause_timer <= 0:
			enemy.attack_component.clear_retreat_state()
			transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	# Фаза 2: Движение к точке отступления (пятится назад)
	enemy.nav_agent.target_position = enemy.attack_component.tactical_retreat_target
	
	# Используем новую, настраиваемую скорость
	enemy.nav_agent.max_speed = enemy.retreat_speed 
	enemy.move_toward_path()
	
	# !!! КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: Смотрим на игрока, а не в сторону движения
	if is_instance_valid(enemy.player):
		enemy.handle_rotation(delta, enemy.player.global_position)
	
	# --- ВАЖНО: Анимация отступления ---
	# Здесь нужна анимация "ходьбы/бега назад" (backpedal).
	# Если у вас ее нет, можно временно использовать обычную анимацию ходьбы.
	# Назовем ее условно "Monstr_walk_backwards". Если ее нет, AnimationPlayer
	# просто ничего не сделает, но код не сломается.
	# В идеале - добавьте такую анимацию.
	if enemy.anim_player.has_animation("Monstr_walk_backwards"):
		var anim_speed = clamp(enemy.velocity.length() / enemy.walk_speed, 0.8, 1.2)
		enemy.play_animation("Monstr_walk_backwards", 0.2, anim_speed)
	else:
		# Запасной вариант, если анимации нет
		enemy.update_movement_animation(delta) 
	
	# Проверка достижения точки
	if enemy.nav_agent.is_navigation_finished():
		enemy.attack_component.tactical_retreat_pause_timer = enemy.attack_component.get_random_retreat_pause_time()

func on_damage_taken() -> void:
	# Прерываем отступление, только если мы находимся в процессе отступления
	if enemy.attack_component.should_tactical_retreat:
		print("AI: Retreat interrupted by damage!")
		# Сбрасываем флаги отступления
		enemy.attack_component.clear_retreat_state()
		# Переходим в Chase, чтобы немедленно переоценить ситуацию и, возможно, контратаковать
		transitioned.emit(self, GameConstants.STATE_CHASE)
func exit() -> void:
	# Всегда возвращаем токен при выходе из состояния атаки
	AIDirector.return_attack_token(enemy)
