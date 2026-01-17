extends State

var player: Player
var roll_duration: float = 0.0
var elapsed_time: float = 0.0

var is_stuck_under_roof: bool = false

# Увеличим скорость вылета, чтобы проскакивать быстро (было 6-8, ставим 10-12)
@export var slide_out_speed: float = 12.0 

@export_group("Collision Timing")
@export_range(0.0, 1.0) var shrink_start_ratio: float = 0.15 
# Восстановление ставим поздно, но реальное восстановление будет зависеть от потолка
@export_range(0.0, 1.0) var restore_start_ratio: float = 0.85 

@export_group("Virtual Wall")
@export var dive_entry_margin: float = 1.2 

var default_roll_control: float = 0.0
var fixed_roll_direction: Vector3 = Vector3.ZERO
var head_wall_detector: ShapeCast3D 

var is_collider_shrunk: bool = false

func enter() -> void:
	player = entity as Player
	player.is_rolling = true
	player.is_invincible = true
	elapsed_time = 0.0
	is_stuck_under_roof = false
	is_collider_shrunk = false
	
	# Гарантируем, что визуально мы не приседаем на старте
	player.anim_controller.set_crouch_state(false)
	
	default_roll_control = player.roll_control
	player.roll_ability.consume_charge()
	
	_ensure_head_wall_detector()
	
	if player.shape_cast:
		player.shape_cast.enabled = true
		player.shape_cast.force_shapecast_update()

	# 1. ОПРЕДЕЛЯЕМ НАПРАВЛЕНИЕ РЫВКА
	var input_vec = player.get_movement_vector()
	if input_vec.length_squared() > 0.01:
		fixed_roll_direction = Vector3(input_vec.x, 0, input_vec.y).normalized()
	else:
		# Если ввода нет - катимся туда, куда смотрит модель
		fixed_roll_direction = -player.global_transform.basis.z.normalized()
		fixed_roll_direction.y = 0

	player.trigger_roll()
	
	if player.anim_player.has_animation(GameConstants.ANIM_PLAYER_ROLL):
		roll_duration = player.anim_player.get_animation(GameConstants.ANIM_PLAYER_ROLL).length
	else:
		roll_duration = 0.6
	
	player.sfx_roll.play_random()
	
	var current_speed_2d = Vector2(player.velocity.x, player.velocity.z).length()
	var speed_factor = clamp(current_speed_2d / player.run_speed, 0.0, 1.0)
	player.root_motion_speed_factor = lerp(player.roll_min_speed, player.roll_max_speed, speed_factor)

func physics_update(delta: float) -> void:
	elapsed_time += delta
	var progress = clamp(elapsed_time / roll_duration, 0.0, 1.0)
	
	# === 1. УПРАВЛЕНИЕ КОЛЛАЙДЕРОМ (СЖАТИЕ) ===
	if not is_collider_shrunk and progress >= shrink_start_ratio:
		player.shrink_collider()
		is_collider_shrunk = true
	
	# Проверяем потолок ТОЛЬКО если мы уже сжались (иначе shape_cast может врать)
	var has_roof = false
	if is_collider_shrunk:
		has_roof = player.is_roof_above()
	
	# === 2. ЛОГИКА "ПРОСКАЛЬЗЫВАНИЯ" (STUCK) ===
	if has_roof:
		is_stuck_under_roof = true
		
		# Отключаем управление
		player.roll_control = 0.0
		
		# ВИЗУАЛ: Принудительно ставим флаг приседания в аниматоре.
		# Это спасет, если анимация переката закончится, а мы все еще под столом.
		# Персонаж перейдет в Crouch/Crawl вместо Idle/Stand.
		player.anim_controller.set_crouch_state(true)
		
		# ФИЗИКА: Агрессивное движение вперед
		# Мы НЕ используем move_toward, мы жестко задаем скорость,
		# чтобы преодолеть трение и любые попытки физики вытолкнуть нас назад.
		player.velocity.x = fixed_roll_direction.x * slide_out_speed
		player.velocity.z = fixed_roll_direction.z * slide_out_speed
		
		# Гравитация нужна
		player.apply_gravity(delta)
		
		player.move_and_slide()
		
		# !!! КРИТИЧНО: RETURN !!!
		# Мы НЕ выходим из функции и НЕ проверяем таймер окончания переката.
		# Мы остаемся в этом состоянии, пока крыша не исчезнет.
		return 

	# === 3. ВЫХОД ИЗ ЗАСТРЕВАНИЯ ===
	# Если мы были застрявшими, но крыша кончилась -> ВЫЛЕТАЕМ
	if is_stuck_under_roof and not has_roof:
		# Восстанавливаем коллайдер
		if is_collider_shrunk:
			player.restore_collider()
			is_collider_shrunk = false
		
		# Сбрасываем флаг приседания
		player.anim_controller.set_crouch_state(false)
		
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return

	# === 4. ОБЫЧНОЕ ВОССТАНОВЛЕНИЕ (Если не застревали) ===
	if is_collider_shrunk and progress >= restore_start_ratio:
		# Восстанавливаем ТОЛЬКО если нет крыши (дублирующая проверка для безопасности)
		if not player.is_roof_above():
			player.restore_collider()
			is_collider_shrunk = false
	
	# === 5. ВИРТУАЛЬНАЯ СТЕНА (Перед входом) ===
	if not is_stuck_under_roof and is_collider_shrunk:
		if _check_head_collision(delta):
			player.velocity.x = 0
			player.velocity.z = 0
			
	# === 6. ЗАВЕРШЕНИЕ ПО ТАЙМЕРУ ===
	if elapsed_time < roll_duration:
		# Отмены
		if player.input_handler.check_jump():
			if progress >= player.roll_jump_cancel_threshold:
				player.perform_jump()
				transitioned.emit(self, GameConstants.STATE_AIR)
				return
		
		if player.input_handler.is_attack_pressed:
			var can_cancel_attack = progress >= (1.0 - player.attack_roll_cancel_threshold)
			if can_cancel_attack and player.can_attack:
				player.input_handler.check_attack()
				transitioned.emit(self, GameConstants.STATE_ATTACK)
				return
	else:
		transitioned.emit(self, GameConstants.STATE_MOVE)

func _ensure_head_wall_detector():
	if head_wall_detector: return
	head_wall_detector = ShapeCast3D.new()
	head_wall_detector.name = "HeadWallDetector"
	player.add_child(head_wall_detector)
	var sphere = SphereShape3D.new()
	sphere.radius = 0.4
	head_wall_detector.shape = sphere
	head_wall_detector.position = Vector3(0, 1.5, 0)
	head_wall_detector.add_exception(player)
	head_wall_detector.collision_mask = 1 
	head_wall_detector.enabled = false

func _check_head_collision(_delta: float) -> bool:
	if not head_wall_detector: return false
	head_wall_detector.enabled = true
	var cast_vec = fixed_roll_direction * dive_entry_margin
	head_wall_detector.target_position = cast_vec
	head_wall_detector.force_shapecast_update()
	if head_wall_detector.is_colliding():
		var hit_point = head_wall_detector.get_collision_point(0)
		var dist = player.global_position.distance_to(hit_point)
		if dist > 0.8:
			return true
	head_wall_detector.enabled = false
	return false

func exit() -> void:
	player.is_rolling = false
	player.is_invincible = false
	player.root_motion_speed_factor = 1.0
	
	# Финальная гарантия восстановления
	if is_collider_shrunk:
		player.restore_collider()
		is_collider_shrunk = false
	
	player.anim_controller.set_crouch_state(false)
	
	if player.shape_cast:
		player.shape_cast.enabled = false
	if head_wall_detector:
		head_wall_detector.enabled = false
		
	player.roll_control = default_roll_control
	
	var input_vec = player.input_handler.move_vector
	if input_vec.length() > 0.01:
		if player.is_trying_to_run:
			player.current_movement_blend = player.blend_value_run
		else:
			player.current_movement_blend = player.blend_value_walk
		player.set_locomotion_blend(player.current_movement_blend) 
