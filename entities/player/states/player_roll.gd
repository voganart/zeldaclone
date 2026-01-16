extends State

var player: Player
var roll_duration: float = 0.0
var elapsed_time: float = 0.0

var is_stuck_under_roof: bool = false
var slide_out_speed: float = 5.0 

var default_roll_control: float = 0.0
var fixed_roll_direction: Vector3 = Vector3.ZERO

# Настройка: С какого момента анимации (0.0 - 1.0) начинать проверять потолок.
# 0.5 = с середины переката. 
# Если поставить слишком рано, игрок может "прилипнуть" к полу в начале кувырка.
var early_check_threshold: float = 0.5 

func enter() -> void:
	player = entity as Player
	player.is_rolling = true
	player.is_invincible = true
	elapsed_time = 0.0
	is_stuck_under_roof = false
	
	# Сброс в стойку
	player.anim_controller.set_crouch_state(false)
	
	default_roll_control = player.roll_control
	player.roll_ability.consume_charge()
	player.shrink_collider()
	
	if player.shape_cast:
		player.shape_cast.enabled = true
		player.shape_cast.force_shapecast_update()

	var input_vec = player.get_movement_vector()
	if input_vec.length_squared() > 0.01:
		fixed_roll_direction = Vector3(input_vec.x, 0, input_vec.y).normalized()
	else:
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
	
	# 1. Сначала проверяем потолок
	var has_roof = player.is_roof_above()
	
	# === ЛОГИКА ЗАСТРЕВАНИЯ (ПРИОРИТЕТ) ===
	if has_roof:
		# Если мы только что влетели под потолок
		if not is_stuck_under_roof:
			_enter_stuck_state()
		
		# ПРИНУДИТЕЛЬНОЕ ДВИЖЕНИЕ (Sonic Mode)
		# Пока есть крыша, мы едем вперед
		player.velocity.x = fixed_roll_direction.x * slide_out_speed
		player.velocity.z = fixed_roll_direction.z * slide_out_speed
		player.velocity.y = -9.8 
		player.move_and_slide()
		
		return # Прерываем функцию, не даем сработать таймерам выхода
	
	# === ЛОГИКА ВЫХОДА ===
	
	# Если потолка НЕТ, но мы были в режиме застревания -> Сразу выходим!
	# (Иначе он может продолжить катиться, если таймер ролла еще не истек)
	if is_stuck_under_roof and not has_roof:
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return

	# === ЛОГИКА ОБЫЧНОГО ПЕРЕКАТА (ПО ТАЙМЕРУ) ===
	
	if elapsed_time < roll_duration:
		var progress = elapsed_time / roll_duration
		
		# Ранняя проверка (чтобы плавно войти в слайд до удара головой)
		if progress > early_check_threshold:
			# Тут мы ничего не делаем, так как has_roof проверяется в самом начале функции.
			# Если has_roof == true, мы бы уже ушли в блок if has_roof.
			pass

		# Прерывания (работают только на чистом месте)
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
		# Таймер вышел, потолка нет -> Выход
		transitioned.emit(self, GameConstants.STATE_MOVE)

# Вынес логику входа в застревание в отдельную функцию, чтобы вызывать её из разных мест
func _enter_stuck_state() -> void:
	is_stuck_under_roof = true
	player.roll_control = 0.0 
	
	# 1. Говорим дереву: "Подготовь анимацию ползания"
	player.anim_controller.set_crouch_state(true)
	
	# 2. Говорим дереву: "Прекрати играть перекат (вставание) ПРЯМО СЕЙЧАС"
	# Это заставит OneShot плавно исчезнуть (Fade Out), обнажив CrouchState под ним.
	player.anim_controller.abort_roll()

func exit() -> void:
	player.is_rolling = false
	player.is_invincible = false
	player.root_motion_speed_factor = 1.0
	
	# Возвращаем в стойку
	player.anim_controller.set_crouch_state(false)
	
	player.roll_control = default_roll_control
	player.restore_collider()
	
	if player.shape_cast:
		player.shape_cast.enabled = false
		
	var input_vec = player.input_handler.move_vector
	if input_vec.length() > 0.01:
		if player.is_trying_to_run:
			player.current_movement_blend = player.blend_value_run
		else:
			player.current_movement_blend = player.blend_value_walk
		player.set_locomotion_blend(player.current_movement_blend)
