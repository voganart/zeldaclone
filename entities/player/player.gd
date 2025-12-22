class_name Player
extends CharacterBody3D

@onready var _mesh: Node3D = $character
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
@export var roll_min_speed: float = 8.0
@export var roll_max_speed: float = 12.0
@export var roll_speed: float = 6.0 
@export var roll_control: float = 0.5
@export_range(0.0, 1.0) var roll_jump_cancel_threshold: float = 0.75
@export var buffered_jump_min_time: float = 0.0
@export var buffered_jump_max_time: float = 0.5
@export var auto_run_latch_time: float = 2.0
@export var roll_max_charges: int = 3
@export var roll_cooldown: float = 0.5
@export var roll_recharge_time: float = 3.0
@export_range(0.0, 1.0) var attack_roll_cancel_threshold: float = 1.0
@export_range(0.0, 1.0) var dodge_cancel_attack_threshold: float = 0.1


@export_group("Animation Blending")
@export var walk_run_blend_smoothing: float = 8.0
@export var walk_run_blend_start_speed: float = 3.6
@export var walk_run_blend_end_speed: float = 4.2

@export_group("Combat")
@export var primary_attack_speed: float = 0.8
@export var attack_cooldown: float = 0.15
@export var combo_window_time: float = 2.0
@export var combo_cooldown_after_combo: float = 0.5
@export var attack_knockback_strength: float = 5.0
@export var attack_knockback_height: float = 2.0
@export var knockback_duration: float = 0.2
@export var running_attack_impulse: float = 3.0
@export var walking_attack_impulse: float = 1.5
@export var attack_rotation_influence: float = 0.5

@export_group("Combat Assist")
@export var soft_lock_range: float = 4.0 
@export var soft_lock_angle: float = 90.0 
 
@export_group("Components")
@export var punch_hand_r: Area3D
@export var punch_hand_l: Area3D
@onready var health_component: Node = $HealthComponent

# КОМПОНЕНТЫ
@onready var state_machine: StateMachine = $StateMachine
@onready var air_dash_ability: AirDashAbility = $AirDashAbility
@onready var ground_slam_ability: GroundSlamAbility = $GroundSlamAbility
@onready var anim_player: AnimationPlayer = $character/AnimationPlayer
@onready var anim_tree: AnimationTree = $character/AnimationTree # <-- НОВОЕ
@onready var input_handler: PlayerInput = $PlayerInput
@onready var attack_timer: Timer = $FirstAttackTimer

@onready var sfx_footsteps: RandomAudioPlayer3D = $SoundBank/SfxFootsteps
@onready var sfx_attack: RandomAudioPlayer3D = $SoundBank/SfxAttack
@onready var sfx_jump: RandomAudioPlayer3D = $SoundBank/SfxJump
@onready var sfx_roll: RandomAudioPlayer3D = $SoundBank/SfxRoll
@onready var sfx_hurt: RandomAudioPlayer3D = $SoundBank/SfxHurt
@onready var sfx_dash: RandomAudioPlayer3D = $SoundBank/SfxDash
@onready var sfx_slam_impact: RandomAudioPlayer3D = $SoundBank/SfxSlamImpact
@onready var shape_cast: ShapeCast3D = $RollSafetyCast

# ============================================================================
# RUNTIME VARIABLES
# ============================================================================
@onready var jump_velocity: float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity: float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity: float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

var current_jump_count: int = 0
var movement_input: Vector2 = Vector2.ZERO
var is_running: bool = false
var is_trying_to_run: bool = false
var is_auto_running: bool = false
var is_stopping: bool = false
var shift_pressed_time: float = 0.0
var was_on_floor: bool = true
var air_speed: float = 0.0

var is_attacking: bool = false
var can_attack: bool = true
var combo_count: int = 0
var current_attack_damage: float = 1.0
var current_attack_knockback_enabled: bool = false
var combo_reset_timer: Timer
var combo_cooldown_active: bool = false
var combo_cooldown_timer: Timer
var attack_interval_timer: Timer

var is_rolling: bool = false
var current_roll_charges: int = 3
var roll_penalty_timer: float = 0.0
var roll_regen_timer: float = 0.0
var is_roll_recharging: bool = false
var roll_interval_timer: float = 0.0
var is_invincible: bool = false
var roll_threshold: float = 0.18

var current_knockback_timer: float = 0.0
var is_knockbacked: bool = false
var is_knockback_stun: bool = false
var is_passing_through: bool = false
var hit_enemies_current_attack: Dictionary = {}

var current_movement_blend: float = 0.0
var target_movement_blend: float = 0.0

signal roll_charges_changed(current: int, max_val: int, is_recharging_penalty: bool)

func _ready() -> void:
	# Активация AnimationTree
	anim_tree.active = true
	
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
	
	attack_interval_timer = Timer.new()
	attack_interval_timer.one_shot = true
	attack_interval_timer.timeout.connect(func():
		if not combo_cooldown_active:
			can_attack = true)
	add_child(attack_interval_timer)

	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
		_on_health_changed(health_component.get_health(), health_component.get_max_health())

	current_roll_charges = roll_max_charges
	state_machine.init(self)

# ============================================================================
# PHYSICS PROCESS (CONTROLLER)
# ============================================================================
func _physics_process(delta: float) -> void:
	_update_stun_timer(delta)
	_update_roll_timers(delta)
	
	if has_node("/root/SimpleGrass"):
		var grass_manager = get_node("/root/SimpleGrass")
		grass_manager.set_player_position(global_position)
	else:
		# print_rich("[color=red]ERROR: SimpleGrass Autoload не найден![/color]")
		pass

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
	var velocity_2d = Vector2(velocity.x, velocity.z)
	
	if input_dir != Vector2.ZERO:
		velocity_2d = velocity_2d.lerp(input_dir * target_speed, acceleration)
	else:
		velocity_2d = velocity_2d.move_toward(Vector2.ZERO, stop_speed * delta)
		
	velocity.x = velocity_2d.x
	velocity.z = velocity_2d.y

# ============================================================================
# ANIMATION TREE WRAPPERS (UPDATED FOR SCREENSHOT)
# ============================================================================

## Главное состояние: "alive" или "dead"
func set_life_state(state_name: String) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_STATE, state_name)

## Переключатель Земля/Воздух: "ground" или "air"
func set_air_state(state_name: String) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_AIR_TRANSITION, state_name)

## Смешивание бега: -1..1
func set_locomotion_blend(value: float) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_LOCOMOTION, value)

## Торможение
func trigger_stopping() -> void:
	anim_tree.set(GameConstants.TREE_PARAM_STOPPING_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

## Состояние прыжка: "Start", "Mid", "End" (Важно: С большой буквы, как на скрине)
func set_jump_state(state_name: String) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_JUMP_STATE, state_name)

## Атака
func trigger_attack(combo_index: int) -> void:
	# 0 -> Attack1, 1 -> Attack2, 2 -> Attack3
	var idx_str = "Attack1"
	if combo_index == 1: idx_str = "Attack2"
	elif combo_index == 2: idx_str = "Attack3"
	
	anim_tree.set(GameConstants.TREE_PARAM_ATTACK_IDX, idx_str)
	anim_tree.set(GameConstants.TREE_PARAM_ATTACK_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func set_tree_attack_speed(value: float) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_ATTACK_SPEED, value)
## Перекат
func trigger_roll() -> void:
	anim_tree.set(GameConstants.TREE_PARAM_ROLL_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

## Рывок в воздухе
func trigger_air_dash() -> void:
	anim_tree.set(GameConstants.TREE_PARAM_DASH_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

## Ground Slam: "start", "mid", "end", "off"
func set_slam_state(state_name: String) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_SLAM_STATE, state_name)

## Получение урона
func trigger_hit() -> void:
	anim_tree.set(GameConstants.TREE_PARAM_HIT_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# ============================================================================
# HELPER FUNCTIONS
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
	sfx_jump.play_random()

func rot_char(delta: float) -> void:
	if is_knockback_stun: return

	var current_rot_speed = rot_speed
	if is_attacking: current_rot_speed *= attack_rotation_influence
	
	var input_dir = input_handler.move_vector
	if input_dir.length_squared() > 0.001:
		var target_angle = atan2(input_dir.x, input_dir.y)
		rotation.y = lerp_angle(rotation.y, target_angle, current_rot_speed * delta)

func tilt_character(delta: float) -> void:
	# 1. Если мы не двигаемся или стоим на месте - выравниваемся в 0
	if input_handler.move_vector.length() < 0.1 or not is_running:
		_mesh.rotation.z = lerp_angle(_mesh.rotation.z, 0.0, 10.0 * delta)
		return

	# 2. Получаем вектор ввода в 3D (относительно камеры, как в get_movement_vector)
	# Нам нужно понять, жмет ли игрок "влево/вправо" относительно того, куда смотрит модель.
	
	# Вектор, куда смотрит модель персонажа (Z - вперед, X - право)
	var char_basis = global_transform.basis
	
	# Вектор, куда хочет идти игрок (из input_handler)
	var input_dir_2d = input_handler.move_vector
	var input_dir_3d = Vector3(input_dir_2d.x, 0, input_dir_2d.y).normalized()
	
	# Если камера вращается, нужно скорректировать input_dir_3d под камеру, 
	# но обычно move_and_slide уже учитывает это в velocity. 
	# Давай возьмем velocity, но нормализованную (чистое направление).
	var move_dir = velocity.normalized()
	
	# Переводим глобальное движение в локальное пространство персонажа
	# local_move.x > 0 — движение вправо
	# local_move.x < 0 — движение влево
	var local_move = char_basis.inverse() * move_dir
	
	# 3. Настройка силы наклона
	var tilt_amount = 0.0
	
	# Если мы бежим и есть боковая составляющая движения (поворот)
	if abs(local_move.x) > 0.1:
		# Угол наклона в градусах (можно вынести в export var tilt_angle = 15.0)
		var max_tilt_deg = 15.0 
		
		# -local_move.x: инвертируем, чтобы наклон был "внутрь" поворота (как мотоцикл)
		# Если персонаж наклоняется не туда — убери минус перед local_move.x
		tilt_amount = deg_to_rad(max_tilt_deg) * -sign(local_move.x)
	
	# 4. Применяем вращение к Visuals
	_mesh.rotation.z = lerp_angle(_mesh.rotation.z, tilt_amount, 10.0 * delta)

# ============================================================================
# COMBAT HELPERS
# ============================================================================
func apply_attack_impulse() -> void:
	velocity.x = 0
	velocity.z = 0
	
	var target = _find_soft_lock_target()
	if target:
		var dir_to_enemy = (target.global_position - global_position).normalized()
		var target_angle = atan2(dir_to_enemy.x, dir_to_enemy.z)
		rotation.y = target_angle
	
	var attack_dir = global_transform.basis.z.normalized()
	var impulse = walking_attack_impulse
	if is_trying_to_run: impulse = running_attack_impulse
	
	velocity += attack_dir * impulse

func _find_soft_lock_target() -> Node3D:
	var enemies = get_tree().get_nodes_in_group(GameConstants.GROUP_ENEMIES)
	var best_target: Node3D = null
	var min_dist: float = soft_lock_range
	var search_dir = Vector3.ZERO
	
	if input_handler.move_vector.length() > 0.1:
		var input_vec = input_handler.move_vector
		search_dir = Vector3(input_vec.x, 0, input_vec.y).normalized()
	else:
		search_dir = global_transform.basis.z.normalized()

	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		if enemy.has_method("is_dead") and enemy.is_dead(): continue
		
		var dir_to_enemy = (enemy.global_position - global_position).normalized()
		var dist = global_position.distance_to(enemy.global_position)
		
		if dist > soft_lock_range: continue
		var angle_to = rad_to_deg(search_dir.angle_to(dir_to_enemy))
		var current_fov = soft_lock_angle
		if dist < 2.5: current_fov = 160.0
		if angle_to > (current_fov / 2.0): continue
		
		if dist < min_dist:
			min_dist = dist
			best_target = enemy
			
	return best_target

func start_combo_cooldown() -> void:
	combo_count = 0
	combo_cooldown_active = true
	can_attack = false
	combo_cooldown_timer.start(combo_cooldown_after_combo)

func start_attack_cooldown() -> void:
	can_attack = false
	attack_interval_timer.start(attack_cooldown)

func can_roll() -> bool:
	if current_roll_charges <= 0: return false
	if roll_interval_timer > 0: return false
	if is_roll_recharging: return false
	return true

func try_cancel_attack_for_roll(progress_ratio: float) -> bool:
	if attack_roll_cancel_threshold >= 1.0: return true
	if attack_roll_cancel_threshold <= 0.0: return false
	return progress_ratio >= (1.0 - attack_roll_cancel_threshold)

func start_hitbox_monitoring() -> void:
	hit_enemies_current_attack.clear()
	# Включаем мониторинг хитбоксов принудительно
	if punch_hand_r: punch_hand_r.monitoring = true
	if punch_hand_l: punch_hand_l.monitoring = true

## Вызывается в конце атаки (из стейта Attack)
func stop_hitbox_monitoring() -> void:
	hit_enemies_current_attack.clear()
	# Выключаем, чтобы не тратить ресурсы
	if punch_hand_r: punch_hand_r.set_deferred("monitoring", false)
	if punch_hand_l: punch_hand_l.set_deferred("monitoring", false)

## Вызывается каждый кадр во время атаки (из стейта Attack)
func process_hitbox_check() -> void:
	var hits_occurred = false
	if punch_hand_r: hits_occurred = _check_hand_overlap(punch_hand_r) or hits_occurred
	if punch_hand_l: hits_occurred = _check_hand_overlap(punch_hand_l) or hits_occurred

func _check_hand_overlap(hand: Area3D) -> bool:
	var hit_something = false
	for body in hand.get_overlapping_bodies():
		# Пропускаем себя
		if body == self: continue
		
		# Пропускаем тех, кого уже ударили в этом замахе
		if hit_enemies_current_attack.has(body.get_instance_id()): continue
		
		if body.has_method("take_damage") or body is RigidBody3D:
			# Наносим урон
			punch_collision(body, hand)
			# Запоминаем, что этого врага ударили
			hit_enemies_current_attack[body.get_instance_id()] = true
			hit_something = true
			
	return hit_something
# ============================================================================
# ANIMATION LOGIC (UPDATED FOR TREE)
# ============================================================================
func handle_move_animation(delta: float, current_input: Vector2) -> void:
	var speed_2d = Vector2(velocity.x, velocity.z).length()
	var has_input = current_input.length_squared() > 0.01
	
	# !!! ИСПРАВЛЕНИЕ: !!!
	if has_input:
		# Если жмем кнопки — считаем анимацию от скорости
		target_movement_blend = calculate_walk_run_blend(speed_2d)
	else:
		# Если кнопки отпустили — анимация должна стремиться к Idle (0.0), 
		# даже если персонаж еще немного скользит по инерции.
		target_movement_blend = 0.0
	
	# Плавная интерполяция
	current_movement_blend = lerp(current_movement_blend, target_movement_blend, walk_run_blend_smoothing * delta)
	
	# Если значение очень маленькое, обрубаем его в 0, чтобы не висело 0.001
	if current_movement_blend < 0.01:
		current_movement_blend = 0.0

	set_locomotion_blend(current_movement_blend)
	
	# Логика анимации остановки (Stopping)
	if has_input:
		is_stopping = false
	elif speed_2d > 3.0: # Если скорость все еще большая, но ввода нет — тормозим
		if not is_stopping:
			is_stopping = true
			trigger_stopping()
	else:
		is_stopping = false

func calculate_walk_run_blend(speed: float) -> float:
	# Если скорость мизерная — считаем, что стоим
	if speed < 0.1:
		return 0.0

	# 1. Зона от ИДЛА (0.0) до ХОДЬБЫ (0.5)
	if speed <= base_speed:
		if base_speed <= 0: return 0.0
		return (speed / base_speed) * 0.5
		
	# 2. Зона от ХОДЬБЫ (0.5) до БЕГА (1.0)
	else:
		var speed_range = run_speed - base_speed
		if speed_range <= 0: return 1.0
		var excess_speed = speed - base_speed
		var t = excess_speed / speed_range
		return clamp(0.5 + (t * 0.5), 0.5, 1.0)
# ============================================================================
# HEALTH & DAMAGE
# ============================================================================
func take_damage(amount: float, knockback_force: Vector3) -> void:
	if ground_slam_ability.is_slamming or is_invincible: return

	VfxPool.spawn_effect(0, global_position + Vector3(0, 1.5, 0))
	
	if health_component: health_component.take_damage(amount)
	$HitFlash.flash()
	sfx_hurt.play_random()
	
	trigger_hit() # <-- Триггер анимации получения урона
	
	velocity += knockback_force
	velocity.y = max(velocity.y, 2.0)
	
	is_knockback_stun = true
	is_knockbacked = true
	current_knockback_timer = knockback_duration

func _on_health_changed(val: float, max_hp: float) -> void:
	GameEvents.player_health_changed.emit(val, max_hp)

func _on_died() -> void:
	GameEvents.player_died.emit()
	if is_in_group(GameConstants.GROUP_PLAYER):
		remove_from_group(GameConstants.GROUP_PLAYER)
	state_machine.change_state(GameConstants.STATE_DEAD)

func _update_stun_timer(delta: float) -> void:
	if current_knockback_timer > 0:
		current_knockback_timer -= delta
		if current_knockback_timer <= 0:
			is_knockback_stun = false
			is_knockbacked = false

func _update_roll_timers(delta: float) -> void:
	if is_roll_recharging:
		roll_penalty_timer -= delta
		if roll_penalty_timer <= 0:
			is_roll_recharging = false
			current_roll_charges = roll_max_charges
			roll_charges_changed.emit(current_roll_charges, roll_max_charges, false)
			
	elif current_roll_charges < roll_max_charges:
		roll_regen_timer -= delta
		if roll_regen_timer <= 0:
			current_roll_charges += 1
			roll_regen_timer = roll_cooldown
			roll_charges_changed.emit(current_roll_charges, roll_max_charges, false)
			
	if roll_interval_timer > 0:
		roll_interval_timer -= delta

# ============================================================================
# COLLISIONS & MISC
# ============================================================================
func push_obj():
	var force = push_force * (roll_push_multiplier if is_rolling else 1.0)
	var collision_count = get_slide_collision_count()
	
	for i in range(collision_count):
		var c = get_slide_collision(i)
		var collider = c.get_collider()
		
		if collider is RigidBody3D:
			collider.apply_central_impulse(-c.get_normal() * force)
			
		if collider is CharacterBody3D and collider.has_method("receive_push"):
			var push_dir = -c.get_normal()
			push_dir.y = 0
			collider.receive_push(push_dir.normalized() * force)
			
			if is_rolling:
				velocity *= 0.5
				var current_state = state_machine.current_state
				if "current_roll_speed" in current_state:
					current_state.current_roll_speed *= 0.5

func check_jump_pass_through() -> void:
	if is_passing_through:
		if is_on_floor():
			is_passing_through = false
			set_collision_mask_value(3, true)
		return

	if is_on_floor():
		for i in get_slide_collision_count():
			var c = get_slide_collision(i)
			if c.get_collider().is_in_group(GameConstants.GROUP_ENEMIES):
				if c.get_normal().y > 0.6:
					is_passing_through = true
					set_collision_mask_value(3, false)
					global_position.y -= 0.05
					break

func _check_attack_hit() -> void:
	var hits = false
	if punch_hand_r and _check_single_hand_hit(punch_hand_r): hits = true
	if not hits and punch_hand_l: _check_single_hand_hit(punch_hand_l)

func _check_single_hand_hit(hand: Area3D) -> bool:
	for body in hand.get_overlapping_bodies():
		if body != self and body.has_method("take_damage"):
			punch_collision(body, hand)
			return true
	return false

func punch_collision(body: Node3D, hand: Area3D) -> void:
	if not is_attacking: return
	if body == self: return
	var dir = (body.global_transform.origin - hand.global_transform.origin).normalized()
	if body.has_method("take_damage"):
		var is_finisher = (current_attack_damage >= 2.0)
		var knockback_vec = Vector3.ZERO
		if current_attack_knockback_enabled:
			knockback_vec = dir * attack_knockback_strength
			if is_finisher:
				knockback_vec.y = 6.0
				knockback_vec.x *= 0.5
				knockback_vec.z *= 0.5
			else:
				knockback_vec.y = attack_knockback_height
		
		body.take_damage(current_attack_damage, knockback_vec, is_finisher)
		var recoil_force = 2.0
		if is_finisher: recoil_force = 4.0
		velocity -= dir * recoil_force

func play_step_sound():
	if is_on_floor():
		sfx_footsteps.play_random()

func get_closest_nav_point() -> Vector3:
	var map = get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, global_position)

func apply_safety_nudge(direction: Vector3, force: float = 5.0):
	velocity = direction * force
	move_and_slide()
