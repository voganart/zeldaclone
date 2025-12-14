class_name Player
extends CharacterBody3D

@onready var _mesh: Node3D = $character
var vfx_pull: Node3D
# ============================================================================
# EXPORTS & CONFIG
# ============================================================================
@export_group("Jump")
@export var jump_height: float = 1.25
@export var jump_time_to_peak: float = 0.45
@export var jump_time_to_descent: float = 0.28
@export var air_control: float = 0.05
@export var max_jump_count: int = 3
@export var second_jump_multiplier: float = 1.2

@export_group("Movement")
@export var base_speed: float = 3.0
@export var run_speed: float = 4.5
@export var stop_speed: float = 8.0
@export var acceleration: float = 0.3
@export var rot_speed: float = 5.0
@export var push_force: float = 0.5
@export var roll_push_multiplier: float = 2.5
@export var roll_speed: float = 6.0
@export var roll_control: float = 0.5
@export_range(0.0, 1.0) var roll_jump_cancel_threshold: float = 0.75
@export var buffered_jump_min_time: float = 0.0
@export var buffered_jump_max_time: float = 0.5
@export var auto_run_latch_time: float = 2.0
@export var roll_max_charges: int = 3
@export var roll_cooldown: float = 0.5
@export var roll_recharge_time: float = 3.0
@export var roll_chain_delay: float = 0.0
@export_range(0.0, 1.0) var roll_invincibility_duration: float = 0.6
@export_range(0.0, 1.0) var attack_roll_cancel_threshold: float = 1.0

@export_group("Animation Blending")
@export var walk_run_blend_smoothing: float = 8.0
@export var walk_run_blend_start_speed: float = 3.6
@export var walk_run_blend_end_speed: float = 4.2

@export_group("Combat")
@export var primary_attack_speed: float = 0.8
@export var attack_movement_influense: float = 0.15
@export var attack_cooldown: float = 0.15
@export var combo_window_time: float = 2.0
@export var combo_cooldown_after_combo: float = 0.5
@export var attack_knockback_strength: float = 5.0
@export var attack_knockback_height: float = 2.0
@export var knockback_duration: float = 0.2
@export var running_attack_impulse: float = 3.0
@export var walking_attack_impulse: float = 1.5
@export var idle_attack_impulse: float = 0.5
@export var attack_rotation_influence: float = 0.5

@export_group("Components")
@export var punch_hand_r: Area3D
@export var punch_hand_l: Area3D
@onready var health_component: Node = $HealthComponent

# КОМПОНЕНТЫ
@onready var state_machine: StateMachine = $StateMachine
@onready var air_dash_ability: AirDashAbility = $AirDashAbility
@onready var ground_slam_ability: GroundSlamAbility = $GroundSlamAbility
@onready var anim_player: AnimationPlayer = $character/AnimationPlayer
@onready var input_handler: PlayerInput = $PlayerInput
@onready var attack_timer: Timer = $FirstAttackTimer
@onready var sprint_timer: Timer = $SprintTimer

# ============================================================================
# RUNTIME VARIABLES
# ============================================================================
# Physics cache
@onready var jump_velocity: float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity: float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity: float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

# Movement State Data
var current_jump_count: int = 0
var movement_input: Vector2 = Vector2.ZERO
var is_running: bool = false
var is_trying_to_run: bool = false
var is_auto_running: bool = false
var is_stopping: bool = false
var shift_pressed_time: float = 0.0
var was_on_floor: bool = true
var air_speed: float = 0.0

# Combat State Data
var is_attacking: bool = false
var can_attack: bool = true
var combo_count: int = 0
var current_attack_damage: float = 1.0
var current_attack_knockback_enabled: bool = false
var combo_reset_timer: Timer
var combo_cooldown_active: bool = false
var combo_cooldown_timer: Timer

# Roll / Dodge Data
var is_rolling: bool = false
var current_roll_charges: int = 3
var roll_penalty_timer: float = 0.0
var roll_regen_timer: float = 0.0
var is_roll_recharging: bool = false
var roll_interval_timer: float = 0.0
var is_invincible: bool = false
var roll_threshold: float = 0.18

# Stun / Damage Data
var current_knockback_timer: float = 0.0
var is_knockbacked: bool = false
var is_knockback_stun: bool = false
var is_passing_through: bool = false

# Animation Blending
var current_movement_blend: float = 0.0
var target_movement_blend: float = 0.0

signal roll_charges_changed(current: int, max_val: int, is_recharging_penalty: bool)

func _ready() -> void:
	# Безопасный поиск пула эффектов
	var pool_node = get_tree().get_first_node_in_group("vfx_pool")
	if pool_node:
		vfx_pull = pool_node
	
	# Инициализация таймеров комбо (оставляем как было)
	combo_reset_timer = Timer.new()
	combo_reset_timer.one_shot = true
	combo_reset_timer.wait_time = combo_window_time
	combo_reset_timer.timeout.connect(func(): combo_count = 0)
	add_child(combo_reset_timer)
	
	combo_cooldown_timer = Timer.new()
	combo_cooldown_timer.one_shot = true
	combo_cooldown_timer.wait_time = combo_cooldown_after_combo
	combo_cooldown_timer.timeout.connect(func():
		combo_cooldown_active = false
		can_attack = true
		print("Combo cooldown ended"))
	add_child(combo_cooldown_timer)

	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
		_on_health_changed(health_component.get_health())

	current_roll_charges = roll_max_charges
	state_machine.init(self)

# ============================================================================
# PHYSICS PROCESS (CONTROLLER)
# ============================================================================
func _physics_process(delta: float) -> void:
	_update_stun_timer(delta)
	_update_roll_timers(delta)
	
	if is_knockback_stun:
		apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
		move_and_slide()
		return
		
	RenderingServer.global_shader_parameter_set(GameConstants.SHADER_PARAM_PLAYER_POS, global_transform.origin)
	
	move_and_slide()
	
	push_obj()
	check_jump_pass_through()
	
	if is_on_floor() and not was_on_floor:
		air_dash_ability.reset_air_state()
		current_jump_count = 0
	was_on_floor = is_on_floor()

func apply_movement_velocity(delta: float, input_dir: Vector2, target_speed: float) -> void:
	# Логика авто-бега и попытки бега перенесена в расчет target_speed внутри State
	var velocity_2d = Vector2(velocity.x, velocity.z)
	
	if input_dir != Vector2.ZERO:
		velocity_2d = velocity_2d.lerp(input_dir * target_speed, acceleration)
	else:
		velocity_2d = velocity_2d.move_toward(Vector2.ZERO, stop_speed * delta)
		
	velocity.x = velocity_2d.x
	velocity.z = velocity_2d.y
# ============================================================================
# HELPER FUNCTIONS (Called by States)
# ============================================================================
func get_movement_vector() -> Vector2:
	if input_handler:
		return input_handler.move_vector
	return Vector2.ZERO
func apply_gravity(delta: float) -> void:
	if air_dash_ability.is_dashing or ground_slam_ability.is_slamming:
		return
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y -= gravity * delta


func perform_jump() -> void:
	var jump_multiplier = second_jump_multiplier if current_jump_count == 1 else 1.0
	velocity.y = - jump_velocity * jump_multiplier
	current_jump_count += 1

func rot_char(delta: float) -> void:
	# if is_knockbacked or is_knockback_stun: return # Отключили, чтобы игрок сохранял контроль поворота
	var current_rot_speed = rot_speed
	if is_attacking: current_rot_speed *= attack_rotation_influence
	var vel_2d = Vector2(velocity.x, -velocity.z)
	if vel_2d.length_squared() > 0.001:
		var target_angle = vel_2d.angle() + PI / 2
		rotation.y = lerp_angle(rotation.y, target_angle, current_rot_speed * delta)

func tilt_character(delta: float) -> void:
	var tilt_angle = 10 if is_running and velocity.length() > base_speed + 1 else 3
	var move_vec = Vector3(velocity.x, 0, velocity.z)
	var local_move = global_transform.basis.inverse() * move_vec
	var target_tilt = clamp(-local_move.x, -1, 1) * deg_to_rad(tilt_angle)
	_mesh.rotation.z = lerp_angle(_mesh.rotation.z, target_tilt, 15 * delta)

func apply_attack_impulse() -> void:
	# (Код без изменений)
	var forward = global_transform.basis.z.normalized()
	var impulse = 0.0
	var speed_2d = Vector2(velocity.x, velocity.z).length()
	if is_running: impulse = running_attack_impulse
	elif get_movement_vector().length() > 0.1 and speed_2d > base_speed * 0.5: impulse = walking_attack_impulse
	else: impulse = idle_attack_impulse
	velocity.x += forward.x * impulse
	velocity.z += forward.z * impulse

func start_combo_cooldown() -> void:
	combo_cooldown_active = true
	can_attack = false
	combo_cooldown_timer.start()

func can_roll() -> bool:
	if current_roll_charges <= 0: return false
	if roll_interval_timer > 0: return false
	if is_roll_recharging: return false
	return true

func try_cancel_attack_for_roll() -> bool:
	if attack_roll_cancel_threshold >= 1.0: return true
	if attack_roll_cancel_threshold <= 0.0: return false
	
	var ratio = anim_player.current_animation_position / anim_player.current_animation_length
	return ratio >= (1.0 - attack_roll_cancel_threshold)

# ============================================================================
# ANIMATION & VISUALS (ИСПРАВЛЕНИЕ БАГА)
# ============================================================================

# !!! ИСПРАВЛЕНИЕ: Добавили аргумент current_input
func handle_move_animation(delta: float, current_input: Vector2) -> void:
	var speed_2d = Vector2(velocity.x, velocity.z).length()
	
	# !!! ИСПРАВЛЕНИЕ: Используем переданный аргумент, а не старую переменную movement_input
	var has_input = current_input.length_squared() > 0.01
	
	if speed_2d > 0.1:
		var blend = calculate_walk_run_blend(speed_2d)
		target_movement_blend = blend
		current_movement_blend = lerp(current_movement_blend, target_movement_blend, walk_run_blend_smoothing * delta)
	
	# 1. Если есть ввод - бежим/идем
	if has_input:
		is_stopping = false
		if current_movement_blend < 0.5:
			var walk_scale = lerp(0.5, 1.5, speed_2d / base_speed) if base_speed > 0 else 1.0
			play_anim(GameConstants.ANIM_PLAYER_WALK, 0.2, walk_scale)
		else:
			var run_scale = lerp(0.5, 1.5, speed_2d / run_speed) if run_speed > 0 else 1.0
			play_anim(GameConstants.ANIM_PLAYER_RUN, 0.2, run_scale)
			
	# 2. Ввода нет, но скорость еще есть - тормозим
	elif speed_2d > 3.0:
		if not is_stopping:
			is_stopping = true
			anim_player.play(GameConstants.ANIM_PLAYER_STOPPING, 0.2, 0.1)
			
	# 3. Стоим
	else:
		is_stopping = false
		play_anim(GameConstants.ANIM_PLAYER_IDLE, 0.2)

# !!! ИСПРАВЛЕНИЕ: Переименовали аргумент name -> anim_name
func play_anim(anim_name: String, blend: float = -1.0, speed: float = 1.0) -> void:
	if anim_player.current_animation == anim_name:
		anim_player.play(anim_name, blend, speed)
		return
	anim_player.play(anim_name, blend, speed)
	if anim_player.current_animation_length > 0:
		anim_player.seek(randf() * anim_player.current_animation_length)

func calculate_walk_run_blend(speed: float) -> float:
	var blend = inverse_lerp(walk_run_blend_start_speed, walk_run_blend_end_speed, speed)
	return clamp(blend, 0.0, 1.0)

# ============================================================================
# HEALTH & DAMAGE (ИСПРАВЛЕНИЕ КРАША)
# ============================================================================
func take_damage(amount: float, knockback_force: Vector3) -> void:
	if ground_slam_ability.is_slamming or is_invincible: return
	
	# !!! ИСПРАВЛЕНИЕ: Проверка на null перед использованием
	if vfx_pull:
		vfx_pull.spawn_effect(0, self.global_position + Vector3(0, 1.5, 0))
	
	if health_component: health_component.take_damage(amount)
	$HitFlash.flash()
	
	velocity += knockback_force
	velocity.y = max(velocity.y, 2.0)
	
	is_knockback_stun = true
	is_knockbacked = true
	current_knockback_timer = knockback_duration

func _on_health_changed(val: float) -> void:
	if health_component:
		GameEvents.player_health_changed.emit(val, health_component.get_max_health())

func _on_died() -> void:
	print("Player Died Signal Received")
	
	# 1. Отправляем глобальный сигнал всем врагам
	GameEvents.player_died.emit()
	
	# 2. Удаляем игрока из группы "player"
	# Это автоматически заставит VisionComponent врагов перестать "видеть" игрока,
	# так как они обычно ищут цели в этой группе.
	if is_in_group(GameConstants.GROUP_PLAYER):
		remove_from_group(GameConstants.GROUP_PLAYER)
	
	# 3. Переход в состояние смерти (анимация и отключение управления)
	state_machine.change_state(GameConstants.STATE_DEAD)

func _update_stun_timer(delta: float) -> void:
	if current_knockback_timer > 0:
		current_knockback_timer -= delta
		if current_knockback_timer <= 0:
			is_knockback_stun = false
			is_knockbacked = false

func _update_roll_timers(delta: float) -> void:
	var prev_charges = current_roll_charges
	var was_recharging = is_roll_recharging
	
	if is_roll_recharging:
		roll_penalty_timer -= delta
		if roll_penalty_timer <= 0:
			is_roll_recharging = false
			current_roll_charges = roll_max_charges
			# Сигнал: Полностью восстановились после штрафа
			roll_charges_changed.emit(current_roll_charges, roll_max_charges, false)
			
	elif current_roll_charges < roll_max_charges:
		roll_regen_timer -= delta
		if roll_regen_timer <= 0:
			current_roll_charges += 1
			roll_regen_timer = roll_cooldown
			# Сигнал: Восстановили один заряд
			roll_charges_changed.emit(current_roll_charges, roll_max_charges, false)
			
	if roll_interval_timer > 0:
		roll_interval_timer -= delta

	# Дополнительная отправка сигнала, если состояние штрафа только началось
	# (это состояние переключается в player_roll.gd, поэтому там тоже надо добавить emit, но можно отловить и здесь)

# ============================================================================
# COLLISIONS & MISC
# ============================================================================
func push_obj():
	var force = push_force * (roll_push_multiplier if is_rolling else 1.0)
	for i in range(get_slide_collision_count()):
		var c = get_slide_collision(i)
		var collider = c.get_collider()
		if collider is RigidBody3D:
			collider.apply_central_impulse(-c.get_normal() * force)
		if collider is CharacterBody3D and collider.has_method("receive_push"):
			collider.receive_push(-c.get_normal() * force)

func check_jump_pass_through() -> void:
	# 1. Если мы уже "проваливаемся" (маска врагов отключена)
	if is_passing_through:
		# Ждем, пока коснемся "настоящего" пола (World/Ground)
		# Так как маска врагов отключена, is_on_floor() вернет true ИСКЛЮЧИТЕЛЬНО от земли/стен
		if is_on_floor():
			is_passing_through = false
			set_collision_mask_value(3, true) # Включаем врагов обратно
		return

	# 2. Если мы стоим на чем-то (проверяем, не враг ли это)
	if is_on_floor():
		for i in get_slide_collision_count():
			var c = get_slide_collision(i)
			if c.get_collider().is_in_group(GameConstants.GROUP_ENEMIES):
				# Если мы сверху (нормаль вверх)
				if c.get_normal().y > 0.6:
					# !!! FIX: Pass Through !!!
					# Отключаем коллизию с врагами, чтобы провалиться сквозь них
					is_passing_through = true
					set_collision_mask_value(3, false)
					
					# Чуть сдвигаем вниз, чтобы гарантированно "войти" в коллайдер врага и не застрять на грани
					global_position.y -= 0.05
					break

func _check_attack_hit() -> void:
	var hits = false
	if punch_hand_r and _check_single_hand_hit(punch_hand_r): hits = true
	if not hits and punch_hand_l: _check_single_hand_hit(punch_hand_l)

func _check_single_hand_hit(hand: Area3D) -> bool:
	for body in hand.get_overlapping_bodies():
		if body.is_in_group(GameConstants.GROUP_ENEMIES):
			punch_collision(body, hand)
			return true
	return false

func punch_collision(body: Node3D, hand: Area3D) -> void:
	if not is_attacking: return
	if not body.is_in_group(GameConstants.GROUP_ENEMIES): return
	var dir = (body.global_transform.origin - hand.global_transform.origin).normalized()
	if body.has_method("take_damage"):
		var is_finisher = (current_attack_damage >= 2.0)
		var knockback_vec = Vector3.ZERO
		if current_attack_knockback_enabled:
			knockback_vec = dir * attack_knockback_strength
			if is_finisher:
				# Подбрасываем вверх!
				# Было 10.0, уменьшаем по просьбе (например до 6.0)
				knockback_vec.y = 6.0
				
				# Можно немного уменьшить отталкивание назад, чтобы он подлетел "на месте"
				knockback_vec.x *= 0.5
				knockback_vec.z *= 0.5
			else:
				# Обычный удар - легкий подскок
				knockback_vec.y = attack_knockback_height # (например 2.0)
		
		# Передаем вектор
		body.take_damage(current_attack_damage, knockback_vec, is_finisher)
		var recoil_force = 2.0 # Сила отдачи
		if is_finisher: recoil_force = 4.0
		# Применяем импульс обратно вектору атаки
		velocity -= dir * recoil_force
