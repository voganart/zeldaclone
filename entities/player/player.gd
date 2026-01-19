class_name Player
extends CharacterBody3D

@onready var _mesh: Node3D = $character

# ============================================================================
# EXPORTS & CONFIG
# ============================================================================
@export_group("Debug & Unlocks")
@export var debug_unlock_double_jump: bool = false
@export var debug_unlock_air_dash: bool = false
@export var debug_unlock_ground_slam: bool = false
@export var debug_unlock_roll: bool = false
@export var debug_unlock_3_hit_combo: bool = false

@export_group("Respawn Settings")
## Абсолютная высота, ниже которой игрок умрет гарантированно (например -100)
@export var absolute_fall_limit: float = -100.0 
## На сколько метров вниз от последней безопасной точки можно упасть, прежде чем включится проверка "Бездны"
@export var safe_fall_distance: float = 12.0
## Дистанция проверки земли внизу. Если в пределах этого луча нет земли - респавн.
@export var void_check_distance: float = 30.0

@export var fall_damage: float = 1.0 
@export var safe_ground_margin: float = 1.5 
@export var respawn_fade_duration: float = 0.5 
@export var respawn_hold_time: float = 0.8 

@export_group("Idle Animations")
@export var enable_idle_dance: bool = true 
@export var idle_dance_time: float = 10.0 

@export_group("Root Motion Tweaks")
@export var rm_walk_anim_speed: float = 1.0 
@export var rm_run_anim_speed: float = 1.3 

@export_group("Auto Run")
@export var auto_run_latch_time: float = 0.3

@export_group("Animation Blending")
@export var blend_value_walk: float = 0.5 
@export var blend_value_run: float = 1.0
@export var stopping_threshold: float = 0.6 

@export_group("Combat Assist")
@export var soft_lock_range: float = 4.0 
@export var soft_lock_angle: float = 90.0 
@export var wall_pushback_force: float = 5.0
 
# --- COMPONENTS ---
@onready var anim_controller: AnimationController = $Components/AnimationController 
@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var combat_component: CombatComponent = $Components/CombatComponent 
@onready var health_component: Node = $Components/HealthComponent
@onready var input_handler: PlayerInput = $PlayerInput
@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
var default_col_height: float = 2.0
var default_col_y: float = 1.0

var roll_col_height: float = 0.9
var roll_col_y: float = 0.45 

# Abilities
@onready var air_dash_ability: AirDashAbility = $Abilities/AirDashAbility
@onready var ground_slam_ability: GroundSlamAbility = $Abilities/GroundSlamAbility
@onready var roll_ability: RollAbility = $Abilities/RollAbility
# ------------------

@onready var anim_player: AnimationPlayer = $character/AnimationPlayer
@onready var anim_tree: AnimationTree = $character/AnimationTree

@onready var attack_timer: Timer = $FirstAttackTimer

@onready var sfx_footsteps = $SoundBank/SfxFootsteps
@onready var sfx_attack = $SoundBank/SfxAttack
@onready var sfx_jump = $SoundBank/SfxJump
@onready var sfx_roll = $SoundBank/SfxRoll
@onready var sfx_hurt = $SoundBank/SfxHurt
@onready var sfx_dash = $SoundBank/SfxDash
@onready var sfx_slam_impact = $SoundBank/SfxSlamImpact

@onready var shape_cast: ShapeCast3D = get_node_or_null("RollSafetyCast")
@onready var wall_detector: ShapeCast3D = $AttackWallDetector 

var last_safe_position: Vector3 = Vector3.ZERO
var safe_pos_timer: float = 0.0 

var movement_input: Vector2 = Vector2.ZERO
var is_running: bool = false
var is_trying_to_run: bool = false
var is_auto_running: bool = false
var is_stopping: bool = false
var shift_pressed_time: float = 0.0

var is_rolling: bool = false 
var is_invincible: bool = false
var roll_threshold: float = 0.18 

var current_knockback_timer: float = 0.0
var is_knockbacked: bool = false
var is_knockback_stun: bool = false
var is_respawning: bool = false 

var current_movement_blend: float = 0.0
var target_movement_blend: float = 0.0
var current_time_scale: float = 1.0

var current_rm_velocity: Vector3 = Vector3.ZERO
var current_wall_push_velocity: Vector3 = Vector3.ZERO

var root_motion_speed_factor: float = 1.0

var cached_camera: Camera3D = null

# Геттеры свойств
var base_speed: float:
	get: return movement_component.walk_speed 
var run_speed: float:
	get: return movement_component.run_speed
var current_jump_count: int:
	get: return movement_component.current_jump_count
	set(val): movement_component.current_jump_count = val
var is_attacking: bool:
	get: return combat_component.is_attacking
	set(val): 
		combat_component.is_attacking = val
		if wall_detector: wall_detector.enabled = val 
var can_attack: bool:
	get: return combat_component.can_attack
	set(val): combat_component.can_attack = val
var combo_count: int:
	get: return combat_component.combo_count
	set(val): combat_component.combo_count = val
var primary_attack_speed: float:
	get: return combat_component.primary_attack_speed
var attack_cooldown: float:
	get: return combat_component.attack_cooldown
var kb_strength_normal: float:
	get: return combat_component.kb_strength_normal
var kb_height_normal: float:
	get: return combat_component.kb_height_normal
var kb_strength_finisher: float:
	get: return combat_component.kb_strength_finisher
var kb_height_finisher: float:
	get: return combat_component.kb_height_finisher
var combo_window_time: float:
	get: return combat_component.combo_window_time
var combo_cooldown_after_combo: float:
	get: return combat_component.combo_cooldown_after_combo
var has_hyper_armor: bool:
	get: return combat_component.has_hyper_armor
	set(val): combat_component.has_hyper_armor = val
var current_attack_damage: float:
	get: return combat_component.current_attack_damage
	set(val): combat_component.current_attack_damage = val
var current_knockback_strength: float:
	get: return combat_component.current_knockback_strength
	set(val): combat_component.current_knockback_strength = val
var current_knockback_height: float:
	get: return combat_component.current_knockback_height
	set(val): combat_component.current_knockback_height = val
var current_attack_knockback_enabled: bool:
	get: return combat_component.current_attack_knockback_enabled
	set(val): combat_component.current_attack_knockback_enabled = val
var combo_reset_timer: Timer:
	get: return combat_component.combo_reset_timer
var combo_cooldown_active: bool:
	get: return not combat_component.combo_cooldown_timer.is_stopped()
	set(val): pass
var hitbox_active_timer: float:
	get: return combat_component.hitbox_active_timer
	set(val): combat_component.hitbox_active_timer = val
var hit_enemies_current_attack: Dictionary:
	get: return combat_component.hit_enemies_current_attack
	set(val): combat_component.hit_enemies_current_attack = val
var knockback_duration: float:
	get: return combat_component.knockback_duration
var running_attack_impulse: float:
	get: return combat_component.running_attack_impulse
var walking_attack_impulse: float:
	get: return combat_component.walking_attack_impulse
var attack_rotation_influence: float:
	get: return combat_component.attack_rotation_influence
var attack_roll_cancel_threshold: float:
	get: return combat_component.attack_roll_cancel_threshold
var current_roll_charges: int:
	get: return roll_ability.current_roll_charges
	set(val): roll_ability.current_roll_charges = val
var roll_max_charges: int:
	get: return roll_ability.roll_max_charges
var is_roll_recharging: bool:
	get: return roll_ability.is_roll_recharging
var roll_recharge_time: float:
	get: return roll_ability.roll_recharge_time
var roll_penalty_timer: float:
	get: return roll_ability.roll_penalty_timer
var roll_regen_timer: float:
	get: return roll_ability.roll_regen_timer
var roll_cooldown: float:
	get: return roll_ability.roll_cooldown
var roll_min_speed: float:
	get: return roll_ability.roll_min_speed
var roll_max_speed: float:
	get: return roll_ability.roll_max_speed
var roll_control: float:
	get: return roll_ability.roll_control
var roll_jump_cancel_threshold: float:
	get: return roll_ability.roll_jump_cancel_threshold
var roll_interval_timer: float:
	get: return roll_ability.roll_interval_timer
	set(val): roll_ability.roll_interval_timer = val

signal roll_charges_changed(current: int, max_val: int, is_recharging_penalty: bool)

func _ready() -> void:
	last_safe_position = global_position 
	movement_component.init(self)
	combat_component.init(self)
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		default_col_height = collision_shape.shape.height
		default_col_y = collision_shape.position.y
		
		roll_col_height = default_col_height / 2.0
		roll_col_y = default_col_y / 2.0
	
	call_deferred("_setup_roll_safety_cast")

	if roll_ability:
		roll_ability.roll_charges_changed.connect(func(c, m, p): roll_charges_changed.emit(c, m, p))

	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
		_on_health_changed(health_component.get_health(), health_component.get_max_health())

	state_machine.init(self)
	
	_apply_unlocks()

func _apply_unlocks() -> void:
	if movement_component:
		movement_component.max_jump_count = 2 if debug_unlock_double_jump else 1
	if air_dash_ability:
		air_dash_ability.is_unlocked = debug_unlock_air_dash
	if ground_slam_ability:
		ground_slam_ability.is_unlocked = debug_unlock_ground_slam
	if roll_ability:
		roll_ability.is_unlocked = debug_unlock_roll
	if combat_component:
		combat_component.max_combo_hits = 3 if debug_unlock_3_hit_combo else 2

func unlock_ability(ability_name: String) -> void:
	print("Player unlocking: ", ability_name)
	match ability_name:
		"roll_ability":
			if roll_ability: roll_ability.is_unlocked = true
		
		"double_jump":
			if movement_component: movement_component.unlock_double_jump()
				
		"ground_slam":
			if ground_slam_ability: ground_slam_ability.is_unlocked = true
				
		"air_dash":
			if air_dash_ability: air_dash_ability.is_unlocked = true
			
		"combo_finisher", "3_hit_combo":
			if combat_component: 
				combat_component.max_combo_hits = 3
				print("3-Hit Combo Unlocked!")

func _setup_roll_safety_cast() -> void:
	if not shape_cast:
		shape_cast = ShapeCast3D.new()
		shape_cast.name = "RollSafetyCast"
		add_child(shape_cast)
		shape_cast.add_exception(self)
		shape_cast.collision_mask = 1 
	
	shape_cast.position = Vector3(0, 0.5, 0)
	var check_distance = default_col_height - shape_cast.position.y - 0.1
	shape_cast.target_position = Vector3(0, check_distance, 0)
	
	if not shape_cast.shape or not (shape_cast.shape is SphereShape3D):
		var sphere = SphereShape3D.new()
		sphere.radius = 0.4 
		shape_cast.shape = sphere
	
	shape_cast.enabled = false 
	shape_cast.clear_exceptions()
	shape_cast.add_exception(self)

func _process(delta: float) -> void:
	_update_stun_timer(delta)
	
	if has_node("/root/SimpleGrass"):
		var grass_manager = get_node("/root/SimpleGrass")
		grass_manager.set_player_position(global_position)

func _physics_process(delta: float) -> void:
	if is_respawning: return

	var is_root_motion = false
	if state_machine.current_state and state_machine.current_state.is_root_motion:
		is_root_motion = true
		var rm_pos = anim_controller.get_root_motion_position()
		var rm_rot = anim_controller.get_root_motion_rotation()
		
		var state_name = state_machine.current_state.name.to_lower()
		var is_locomotion = state_name == "move"
		
		if is_locomotion:
			rot_char(delta)
			var velocity_vector = (global_transform.basis * rm_pos) / delta
			current_rm_velocity.x = velocity_vector.x
			current_rm_velocity.z = velocity_vector.z
		else:
			var current_transform = global_transform
			global_transform = current_transform * Transform3D(Basis(rm_rot), Vector3.ZERO)
			
			if state_name == "roll" and roll_control > 0.0:
				var input_dir = get_movement_vector() 
				if input_dir.length_squared() > 0.01:
					var target_angle = atan2(input_dir.x, input_dir.y)
					var steer_speed = movement_component.rotation_speed * roll_control
					rotation.y = lerp_angle(rotation.y, target_angle, steer_speed * delta)
			
			var velocity_vector = (global_transform.basis * rm_pos) / delta
			current_rm_velocity.x = velocity_vector.x * root_motion_speed_factor
			current_rm_velocity.z = velocity_vector.z * root_motion_speed_factor
	else:
		current_rm_velocity = Vector3.ZERO

	if is_knockback_stun:
		apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
		move_and_slide()
		return
		
	RenderingServer.global_shader_parameter_set(GameConstants.SHADER_PARAM_PLAYER_POS, global_transform.origin)
	
	if is_root_motion:
		velocity.x = current_rm_velocity.x
		velocity.z = current_rm_velocity.z
		
		if is_on_wall() and current_movement_blend < 0.1 and input_handler.move_vector.length() > 0.1:
			var manual_push = get_movement_vector() 
			if manual_push.length_squared() > 0.01:
				var push_vec3 = Vector3(manual_push.x, 0, manual_push.y).normalized() * 2.0
				velocity.x = push_vec3.x
				velocity.z = push_vec3.z
		
		_handle_wall_pushback(delta)
		apply_gravity(delta)
		move_and_slide()
	else:
		move_and_slide()
	
	movement_component.handle_pushing(is_rolling)

	if is_on_floor():
		safe_pos_timer += delta
		if safe_pos_timer > 0.2:
			if _is_position_safe_and_grounded():
				last_safe_position = global_position
			safe_pos_timer = 0.0
	else:
		safe_pos_timer = 0.0

	# === НОВАЯ ЛОГИКА ПРОВЕРКИ ПАДЕНИЯ ===
	_check_fall_logic()

# Функция проверки падения (вызывается каждый физический кадр)
func _check_fall_logic() -> void:
	# 1. Абсолютный предел (если игрок упал в бесконечность мимо всего)
	if global_position.y < absolute_fall_limit:
		_handle_fall_respawn()
		return

	# 2. Динамическая проверка "Бездны"
	# Проверяем только если падаем и не на земле
	if velocity.y < 0 and not is_on_floor():
		var dist_below_safe = last_safe_position.y - global_position.y
		
		# Если мы упали ниже "безопасной высоты" от последнего чекпоинта
		if dist_below_safe > safe_fall_distance:
			# Пускаем луч вниз, чтобы проверить, есть ли там земля
			if not _check_ground_below(void_check_distance):
				# Если земли нет - респавним
				_handle_fall_respawn()

func _check_ground_below(check_distance: float) -> bool:
	var space_state = get_world_3d().direct_space_state
	var from = global_position
	var to = from + Vector3.DOWN * check_distance
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self] # Игнорируем себя
	
	var result = space_state.intersect_ray(query)
	
	return not result.is_empty()

func _is_position_safe_and_grounded() -> bool:
	var space_state = get_world_3d().direct_space_state
	var offset_y = 0.5 
	var check_dist = 2.0 
	
	var checks = [
		Vector3(0, 0, 0), 
		Vector3(safe_ground_margin, 0, 0),
		Vector3(-safe_ground_margin, 0, 0),
		Vector3(0, 0, safe_ground_margin),
		Vector3(0, 0, -safe_ground_margin)
	]
	
	for offset in checks:
		var from = global_position + offset + Vector3(0, offset_y, 0)
		var to = from + Vector3(0, -check_dist, 0)
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [self] 
		
		var result = space_state.intersect_ray(query)
		if not result:
			return false 
	
	return true

func _handle_wall_pushback(delta: float) -> void:
	if not is_attacking or not wall_detector:
		current_wall_push_velocity = current_wall_push_velocity.move_toward(Vector3.ZERO, delta * 10.0)
		velocity += current_wall_push_velocity
		return
	
	wall_detector.force_shapecast_update()
	
	if wall_detector.is_colliding():
		var wall_normal = wall_detector.get_collision_normal(0)
		wall_normal.y = 0 
		
		if wall_normal.length_squared() > 0.01:
			wall_normal = wall_normal.normalized()
			if velocity.dot(wall_normal) < 0:
				velocity = velocity.slide(wall_normal)
		
		var push_dir = -global_transform.basis.z.normalized()
		push_dir.y = 0 
		var target_push = push_dir * wall_pushback_force
		current_wall_push_velocity = current_wall_push_velocity.move_toward(target_push, delta * 5.0)
	else:
		current_wall_push_velocity = current_wall_push_velocity.move_toward(Vector3.ZERO, delta * 5.0)
	
	velocity += current_wall_push_velocity

func _handle_fall_respawn() -> void:
	if is_respawning: return
	is_respawning = true
	
	if SceneManager:
		SceneManager.fade_screen_to_black(respawn_fade_duration)
		await get_tree().create_timer(respawn_fade_duration * 0.8).timeout
	
	take_damage(fall_damage, Vector3.ZERO, false, true)
	
	if health_component.current_health <= 0:
		is_respawning = false
		return

	if ground_slam_ability:
		ground_slam_ability.reset_state()
	if air_dash_ability:
		air_dash_ability.reset_ability_completely()

	global_position = last_safe_position
	
	velocity = Vector3.ZERO
	current_rm_velocity = Vector3.ZERO
	
	state_machine.change_state(GameConstants.STATE_MOVE)
	anim_controller.set_state("alive")
	anim_controller.set_air_state("ground")
	anim_controller.set_jump_state("End")
	anim_controller.set_locomotion_blend(0.0)
	
	velocity = Vector3.DOWN * 10.0
	move_and_slide() 
	velocity = Vector3.ZERO 
	
	await get_tree().create_timer(respawn_hold_time).timeout
	
	if SceneManager:
		await SceneManager.fade_screen_from_black(respawn_fade_duration)
	
	is_invincible = false
	is_respawning = false

func apply_movement_velocity(delta: float, input_dir: Vector2, target_speed: float) -> void:
	movement_component.move(delta, input_dir, target_speed, state_machine.current_state.is_root_motion)

func handle_move_animation(delta: float, current_input: Vector2) -> void:
	var has_input = current_input.length() > 0.01
	var target_time_scale_rm = 1.0 
	
	if has_input:
		if is_auto_running or is_trying_to_run:
			target_movement_blend = blend_value_run
			target_time_scale_rm = rm_run_anim_speed 
		else:
			target_movement_blend = blend_value_walk
			target_time_scale_rm = rm_walk_anim_speed 
	else:
		target_movement_blend = 0.0
		target_time_scale_rm = 1.0
	
	if has_input and is_on_wall():
		var real_vel = get_real_velocity()
		var real_speed_h = Vector2(real_vel.x, real_vel.z).length()
		var wall_factor = clamp(real_speed_h / movement_component.run_speed, 0.0, 1.0)
		target_movement_blend = min(target_movement_blend, wall_factor)
	
	var change_rate = 0.0
	if target_movement_blend > current_movement_blend:
		change_rate = movement_component.acceleration / max(movement_component.run_speed, 0.1)
	else:
		change_rate = movement_component.friction / max(movement_component.run_speed, 0.1)
	
	current_movement_blend = move_toward(current_movement_blend, target_movement_blend, change_rate * delta)
	
	if current_movement_blend < 0.01: current_movement_blend = 0.0
	
	set_locomotion_blend(current_movement_blend)
	
	if state_machine.current_state.is_root_motion:
		current_time_scale = lerp(current_time_scale, target_time_scale_rm, 5.0 * delta)
		anim_controller.set_locomotion_speed_scale(current_time_scale) 
	else:
		var speed_2d = Vector2(velocity.x, velocity.z).length()
		var target_scale = 1.0
		if speed_2d > 0.1:
			target_scale = clamp(speed_2d / movement_component.walk_speed, 0.5, 3.0)
		anim_controller.set_locomotion_speed_scale(target_scale) 
	
	if not has_input and current_movement_blend > stopping_threshold:
		if not is_stopping:
			is_stopping = true
			trigger_stopping()
	else:
		is_stopping = false

func set_life_state(state_name: String) -> void:
	anim_controller.set_state(state_name)

func set_air_state(state_name: String) -> void:
	anim_controller.set_air_state(state_name)

func set_locomotion_blend(value: float) -> void:
	anim_controller.set_locomotion_blend(value)

func trigger_stopping() -> void:
	anim_controller.trigger_stopping()

func set_jump_state(state_name: String) -> void:
	anim_controller.set_jump_state(state_name)

func trigger_attack(combo_index: int) -> void:
	anim_controller.trigger_attack(combo_index)

func set_tree_attack_speed(value: float) -> void:
	anim_controller.set_attack_speed(value)

func trigger_roll() -> void:
	anim_controller.trigger_roll()

func trigger_air_dash() -> void:
	anim_controller.trigger_dash()

func set_slam_state(state_name: String) -> void:
	anim_controller.set_slam_state(state_name)

func trigger_hit() -> void:
	anim_controller.trigger_hit()
	
func get_movement_vector() -> Vector2:
	if not input_handler: return Vector2.ZERO
	var raw_input = input_handler.move_vector
	if raw_input.length_squared() < 0.01: return Vector2.ZERO
	if not is_instance_valid(cached_camera):
		cached_camera = get_viewport().get_camera_3d()
	if not cached_camera:
		cached_camera = get_tree().get_first_node_in_group("main_camera")
	if not cached_camera:
		return raw_input
	var cam_basis = cached_camera.global_transform.basis
	var forward = -cam_basis.z
	var right = cam_basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	if forward.is_zero_approx() or right.is_zero_approx():
		return raw_input
	var direction_3d = (forward * -raw_input.y) + (right * raw_input.x)
	return Vector2(direction_3d.x, direction_3d.z)

func play_footstep_event() -> void:
	if is_on_floor() and velocity.length() > 0.1:
		if sfx_footsteps:
			sfx_footsteps.play_random()
			
func apply_gravity(delta: float) -> void:
	if air_dash_ability.is_dashing or ground_slam_ability.is_slamming: return
	movement_component.apply_gravity(delta)

func perform_jump() -> void:
	var bonus_jump = false
	if current_jump_count == 2 and air_dash_ability.bonus_jump_granted:
		bonus_jump = true
	if movement_component.jump(bonus_jump):
		sfx_jump.play_random()

func reset_air_abilities() -> void:
	air_dash_ability.reset_air_state()

func rot_char(delta: float) -> void:
	if is_knockback_stun: return
	var speed_mod = 1.0
	if is_attacking: speed_mod = attack_rotation_influence
	var move_dir = get_movement_vector()
	movement_component.rotate_towards(delta, move_dir, speed_mod)

func tilt_character(delta: float) -> void:
	movement_component.tilt_character(delta, _mesh, is_running)

func apply_attack_impulse() -> void:
	var target = _find_soft_lock_target()
	if target:
		var dir_to_enemy = (target.global_position - global_position).normalized()
		var target_angle = atan2(dir_to_enemy.x, dir_to_enemy.z)
		rotation.y = target_angle
	
	if state_machine.current_state and not state_machine.current_state.is_root_motion:
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
	combat_component.combo_count = 0
	combat_component.can_attack = false
	combat_component.combo_cooldown_timer.start(combat_component.combo_cooldown_after_combo)

func start_attack_cooldown() -> void:
	combat_component.can_attack = false
	combat_component.attack_interval_timer.start(combat_component.attack_cooldown)

func can_roll() -> bool:
	return roll_ability.can_roll()

func try_cancel_attack_for_roll(progress_ratio: float) -> bool:
	if attack_roll_cancel_threshold >= 1.0: return true
	if attack_roll_cancel_threshold <= 0.0: return false
	return progress_ratio >= (1.0 - attack_roll_cancel_threshold)

func start_hitbox_monitoring() -> void:
	combat_component.start_hitbox_monitoring()

func stop_hitbox_monitoring() -> void:
	combat_component._stop_hitbox_monitoring()

func _check_attack_hit() -> void:
	combat_component.activate_hitbox_check(0.1)

func take_damage(amount: float, knockback_force: Vector3, _is_heavy_attack: bool = false, silent: bool = false) -> void:
	if ground_slam_ability.is_slamming or is_invincible: return
	
	if health_component: health_component.take_damage(amount)
	
	if silent: return

	VfxPool.spawn_effect(0, global_position + Vector3(0, 1.5, 0))
	$HitFlash.flash()
	sfx_hurt.play_random()
	
	if has_hyper_armor: return
	
	trigger_hit()
	
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
	
	await get_tree().create_timer(2.0).timeout
	SceneManager.open_game_over()
func _update_stun_timer(delta: float) -> void:
	if current_knockback_timer > 0:
		current_knockback_timer -= delta
		if current_knockback_timer <= 0:
			is_knockback_stun = false
			is_knockbacked = false

func _update_roll_timers(_delta: float) -> void:
	pass

func push_obj():
	pass

func get_closest_nav_point() -> Vector3:
	var map = get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, global_position)

func apply_safety_nudge(direction: Vector3, force: float = 5.0):
	velocity = direction * force
	move_and_slide()

func shrink_collider() -> void:
	if not collision_shape: return
	if not collision_shape.shape is CapsuleShape3D: return
	
	collision_shape.shape.height = roll_col_height
	collision_shape.position.y = roll_col_y

func restore_collider() -> void:
	if not collision_shape: return
	if not collision_shape.shape is CapsuleShape3D: return
	
	collision_shape.shape.height = default_col_height
	collision_shape.position.y = default_col_y

func is_roof_above() -> bool:
	if not shape_cast: return false
	shape_cast.force_shapecast_update()
	return shape_cast.is_colliding()
