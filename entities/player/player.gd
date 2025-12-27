class_name Player
extends CharacterBody3D

@onready var _mesh: Node3D = $character

# ============================================================================
# EXPORTS & CONFIG
# ============================================================================
@export_group("Hit Stop Settings (Juice)")

@export_subgroup("Props / Objects")
@export var hs_prop_time_scale: float = 0.1 
@export var hs_prop_duration: float = 0.02 

@export_subgroup("Enemy: Normal Hit")
@export var hs_normal_time_scale: float = 0.1
@export var hs_normal_duration: float = 0.04

@export_subgroup("Enemy: Finisher Hit")
@export var hs_finisher_time_scale: float = 0.1
@export var hs_finisher_duration: float = 0.08

@export_subgroup("Enemy: Lethal Hit (Kill)")
@export var hs_lethal_time_scale: float = 0.05
@export var hs_lethal_duration: float = 0.15
@export_group("Jump")
@export var jump_height: float = 1.25
@export var jump_time_to_peak: float = 0.45
@export var jump_time_to_descent: float = 0.28
@export var max_jump_count: int = 3
@export var second_jump_multiplier: float = 1.2

@export_group("Movement")
@export var base_speed: float = 3.0
@export var run_speed: float = 4.5
@export var stop_speed: float = 8.0
@export var acceleration: float = 0.3
@export var rot_speed: float = 10.0
@export var push_force: float = 120.0 
@export var roll_push_multiplier: float = 3.0 

@export_group("Root Motion Tweaks")
@export var rm_walk_anim_speed: float = 1.0 
@export var rm_run_anim_speed: float = 1.3 

@export_subgroup("Roll Settings")
@export var roll_min_speed: float = 1.0 
@export var roll_max_speed: float = 1.4
@export var roll_control: float = 0.5 
@export_range(0.0, 1.0) var roll_jump_cancel_threshold: float = 0.75 
@export var roll_max_charges: int = 3
@export var roll_cooldown: float = 0.5
@export var roll_recharge_time: float = 3.0

@export_group("Auto Run")
@export var auto_run_latch_time: float = 0.3

@export_group("Animation Blending")
@export var walk_run_blend_smoothing: float = 5.0
@export var blend_value_walk: float = 0.5 
@export var blend_value_run: float = 1.0
@export var stopping_threshold: float = 0.6 

@export_group("Combat")
@export var primary_attack_speed: float = 0.8
@export var attack_cooldown: float = 0.15
@export var combo_window_time: float = 2.0
@export var combo_cooldown_after_combo: float = 0.5

@export_subgroup("Knockback: Normal Hit (1 & 2)")
@export var kb_strength_normal: float = 4.0 
@export var kb_height_normal: float = 2.0   

@export_subgroup("Knockback: Finisher (3)")
@export var kb_strength_finisher: float = 10.0 
@export var kb_height_finisher: float = 6.0    

@export_subgroup("Misc Combat")
@export var knockback_duration: float = 0.2 
@export var running_attack_impulse: float = 3.0
@export var walking_attack_impulse: float = 1.5
@export var attack_rotation_influence: float = 0.5
@export_range(0.0, 1.0) var attack_roll_cancel_threshold: float = 1.0 
@export_group("Combat Assist")
@export var soft_lock_range: float = 4.0 
@export var soft_lock_angle: float = 90.0 
 
@export_group("Components")
@export var punch_hand_r: Area3D
@export var punch_hand_l: Area3D
@onready var health_component: Node = $HealthComponent
@export var attack_area: Area3D 
@onready var state_machine: StateMachine = $StateMachine
@onready var air_dash_ability: AirDashAbility = $AirDashAbility
@onready var ground_slam_ability: GroundSlamAbility = $GroundSlamAbility
@onready var anim_player: AnimationPlayer = $character/AnimationPlayer
@onready var anim_tree: AnimationTree = $character/AnimationTree
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

var is_attacking: bool = false
var can_attack: bool = true
var combo_count: int = 0
var current_attack_damage: float = 1.0
var current_knockback_strength: float = 0.0 
var current_knockback_height: float = 0.0
var current_attack_knockback_enabled: bool = true
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
var hitbox_active_timer: float = 0.0



var current_movement_blend: float = 0.0
var target_movement_blend: float = 0.0
var current_time_scale: float = 1.0

var current_rm_velocity: Vector3 = Vector3.ZERO
var has_hyper_armor: bool = false 

var root_motion_speed_factor: float = 1.0

signal roll_charges_changed(current: int, max_val: int, is_recharging_penalty: bool)

func _ready() -> void:
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
# VISUAL PROCESS
# ============================================================================
func _process(delta: float) -> void:
	if state_machine.current_state and state_machine.current_state.is_root_motion:
		var rm_pos = anim_tree.get_root_motion_position()
		var rm_rot = anim_tree.get_root_motion_rotation()
		
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
				var input_dir = input_handler.move_vector
				if input_dir.length_squared() > 0.01:
					var target_angle = atan2(input_dir.x, input_dir.y)
					var steer_speed = rot_speed * roll_control
					rotation.y = lerp_angle(rotation.y, target_angle, steer_speed * delta)
			
			var velocity_vector = (global_transform.basis * rm_pos) / delta
			current_rm_velocity.x = velocity_vector.x * root_motion_speed_factor
			current_rm_velocity.z = velocity_vector.z * root_motion_speed_factor
	else:
		current_rm_velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	_update_stun_timer(delta)
	_update_roll_timers(delta)
	
	if hitbox_active_timer > 0:
		hitbox_active_timer -= delta
		process_hitbox_check()
		
	if has_node("/root/SimpleGrass"):
		var grass_manager = get_node("/root/SimpleGrass")
		grass_manager.set_player_position(global_position)

	if is_knockback_stun:
		apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
		move_and_slide()
		return
		
	RenderingServer.global_shader_parameter_set(GameConstants.SHADER_PARAM_PLAYER_POS, global_transform.origin)
	
	if state_machine.current_state and state_machine.current_state.is_root_motion:
		velocity.x = current_rm_velocity.x
		velocity.z = current_rm_velocity.z
		apply_gravity(delta)
		move_and_slide()
	else:
		move_and_slide()
	
	push_obj()
	check_jump_pass_through()
	
	if is_on_floor() and not was_on_floor:
		air_dash_ability.reset_air_state()
		current_jump_count = 0
	was_on_floor = is_on_floor()

func apply_movement_velocity(delta: float, input_dir: Vector2, target_speed: float) -> void:
	if state_machine.current_state.is_root_motion and is_on_floor():
		return 

	var velocity_2d = Vector2(velocity.x, velocity.z)
	
	if input_dir != Vector2.ZERO:
		velocity_2d = velocity_2d.lerp(input_dir * target_speed, acceleration)
	else:
		velocity_2d = velocity_2d.move_toward(Vector2.ZERO, stop_speed * delta)
		
	velocity.x = velocity_2d.x
	velocity.z = velocity_2d.y

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
	
	current_movement_blend = lerp(current_movement_blend, target_movement_blend, walk_run_blend_smoothing * delta)
	if current_movement_blend < 0.01: current_movement_blend = 0.0
	
	set_locomotion_blend(current_movement_blend)
	
	if state_machine.current_state.is_root_motion:
		current_time_scale = lerp(current_time_scale, target_time_scale_rm, 5.0 * delta)
		anim_tree.set(GameConstants.TREE_PARAM_LOCOMOTION_SPEED, current_time_scale)
	else:
		var speed_2d = Vector2(velocity.x, velocity.z).length()
		var target_scale = 1.0
		if speed_2d > 0.1:
			target_scale = clamp(speed_2d / base_speed, 0.5, 3.0)
		anim_tree.set(GameConstants.TREE_PARAM_LOCOMOTION_SPEED, target_scale)
	
	if not has_input and current_movement_blend > stopping_threshold:
		if not is_stopping:
			is_stopping = true
			trigger_stopping()
	else:
		is_stopping = false

# --- Wrappers ---
func set_life_state(state_name: String) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_STATE, state_name)

func set_air_state(state_name: String) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_AIR_TRANSITION, state_name)

func set_locomotion_blend(value: float) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_LOCOMOTION, value)

func trigger_stopping() -> void:
	anim_tree.set(GameConstants.TREE_PARAM_STOPPING_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func set_jump_state(state_name: String) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_JUMP_STATE, state_name)

func trigger_attack(combo_index: int) -> void:
	var idx_str = "Attack1"
	if combo_index == 1: idx_str = "Attack2"
	elif combo_index == 2: idx_str = "Attack3"
	
	anim_tree.set(GameConstants.TREE_PARAM_ATTACK_IDX, idx_str)
	anim_tree.set(GameConstants.TREE_PARAM_ATTACK_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func set_tree_attack_speed(value: float) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_ATTACK_SPEED, value)

func trigger_roll() -> void:
	anim_tree.set(GameConstants.TREE_PARAM_ROLL_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func trigger_air_dash() -> void:
	anim_tree.set(GameConstants.TREE_PARAM_DASH_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func set_slam_state(state_name: String) -> void:
	anim_tree.set(GameConstants.TREE_PARAM_SLAM_STATE, state_name)

func trigger_hit() -> void:
	anim_tree.set(GameConstants.TREE_PARAM_HIT_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# --- Helpers ---
func get_movement_vector() -> Vector2:
	if input_handler: return input_handler.move_vector
	return Vector2.ZERO

func apply_gravity(delta: float) -> void:
	if air_dash_ability.is_dashing or ground_slam_ability.is_slamming: return
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
	var target_tilt = 0.0
	if is_on_floor():
		var tilt_angle = 10 if is_running and velocity.length() > base_speed + 1 else 3
		var move_vec = Vector3(velocity.x, 0, velocity.z)
		var local_move = global_transform.basis.inverse() * move_vec
		target_tilt = clamp(-local_move.x, -1, 1) * deg_to_rad(tilt_angle)
	_mesh.rotation.z = lerp_angle(_mesh.rotation.z, target_tilt, 10.0 * delta)

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

# ============================================================================
# COMBAT HELPERS
# ============================================================================

func start_combo_cooldown() -> void:
	combo_count = 0
	combo_cooldown_active = true
	can_attack = false
	combo_cooldown_timer.start(combo_cooldown_after_combo)

func start_attack_cooldown() -> void:
	can_attack = false
	attack_interval_timer.start(0.1) 

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
	if punch_hand_r: punch_hand_r.monitoring = true
	if punch_hand_l: punch_hand_l.monitoring = true

func stop_hitbox_monitoring() -> void:
	hit_enemies_current_attack.clear()
	if punch_hand_r: punch_hand_r.set_deferred("monitoring", false)
	if punch_hand_l: punch_hand_l.set_deferred("monitoring", false)

func process_hitbox_check() -> void:
	var hits_occurred = false
	if punch_hand_r: hits_occurred = _check_hand_overlap(punch_hand_r) or hits_occurred
	if punch_hand_l: hits_occurred = _check_hand_overlap(punch_hand_l) or hits_occurred

func _check_hand_overlap(hand: Area3D) -> bool:
	# !!! ВАЖНОЕ ИСПРАВЛЕНИЕ: ПРОВЕРКА ВКЛЮЧЕН ЛИ МОНИТОРИНГ !!!
	if not hand.monitoring: return false
	# --------------------------------------------------------

	var max_enemies_per_hit = 1
	var max_props_per_hit = 1
	var enemies_hit_count = 0
	var props_hit_count = 0
	
	for type in hit_enemies_current_attack.values():
		if type == "enemy": enemies_hit_count += 1
		elif type == "prop": props_hit_count += 1
	
	if enemies_hit_count >= max_enemies_per_hit and props_hit_count >= max_props_per_hit:
		return false

	var candidates_enemies: Array[Node3D] = []
	var candidates_props: Array[Node3D] = []
	
	var bodies_in_front_zone = []
	if attack_area:
		bodies_in_front_zone = attack_area.get_overlapping_bodies()
	
	for body in hand.get_overlapping_bodies():
		if body == self: continue
		if hit_enemies_current_attack.has(body.get_instance_id()): continue
		if attack_area and not body in bodies_in_front_zone:
			continue
		
		# --- НОВАЯ ПРОВЕРКА: Линия видимости (СКВОЗЬ СТЕНЫ БИТЬ НЕЛЬЗЯ) ---
		if not _has_line_of_sight(body):
			continue
		# ------------------------------------------------------------------
		
		if body.is_in_group(GameConstants.GROUP_ENEMIES):
			candidates_enemies.append(body)
		elif body is RigidBody3D or body.has_method("take_damage"):
			candidates_props.append(body)
	
	var sort_func = func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
		
	if not candidates_enemies.is_empty(): candidates_enemies.sort_custom(sort_func)
	if not candidates_props.is_empty(): candidates_props.sort_custom(sort_func)
	
	var hit_occurred = false
	
	if enemies_hit_count < max_enemies_per_hit and not candidates_enemies.is_empty():
		var target = candidates_enemies[0]
		punch_collision(target, hand)
		hit_enemies_current_attack[target.get_instance_id()] = "enemy"
		hit_occurred = true

	if props_hit_count < max_props_per_hit and not candidates_props.is_empty():
		var target = candidates_props[0]
		punch_collision(target, hand)
		hit_enemies_current_attack[target.get_instance_id()] = "prop"
		hit_occurred = true
		
	return hit_occurred

# --- НОВАЯ ФУНКЦИЯ: Проверка препятствий ---
func _has_line_of_sight(target: Node3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	
	# Пускаем луч от груди игрока к центру врага (чуть выше ног)
	var origin = global_position + Vector3(0, 1.0, 0)
	var dest = target.global_position + Vector3(0, 0.5, 0) 
	
	var query = PhysicsRayQueryParameters3D.create(origin, dest)
	# Игнорируем только самого игрока. 
	# Луч должен удариться либо во врага, либо в стену.
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Если луч попал во врага или в объект, который является врагом
		if result.collider == target:
			return true
		# Если попали во что-то другое (стену) раньше врага
		return false
	
	# Если луч вообще ни во что не попал (редко, но бывает если враг без коллизии)
	return false
# -------------------------------------------

func punch_collision(body: Node3D, hand: Area3D) -> void:
	if not is_attacking: return
	if body == self: return
	
	var dir = (body.global_position - global_position)
	dir.y = 0
	dir = dir.normalized()
	
	if body.has_method("take_damage"):
		var is_finisher = (combo_count >= 2) 
		var knockback_vec = Vector3.ZERO
		
		if current_attack_knockback_enabled:
			knockback_vec = dir * current_knockback_strength
			knockback_vec.y = current_knockback_height
		
		# Hit Stop logic
		var is_enemy = body.is_in_group(GameConstants.GROUP_ENEMIES)
		if is_enemy:
			var enemy_hp_comp = body.get_node_or_null("HealthComponent")
			var is_lethal = false
			if enemy_hp_comp:
				is_lethal = (enemy_hp_comp.current_health - current_attack_damage) <= 0
			if is_lethal:
				GameManager.hit_stop_smooth(hs_lethal_time_scale, hs_lethal_duration, 0.0, 0.1) 
				GameEvents.camera_shake_requested.emit(0.6, 0.2)
			elif is_finisher:
				GameManager.hit_stop_smooth(hs_finisher_time_scale, hs_finisher_duration, 0.0, 0.05) 
				GameEvents.camera_shake_requested.emit(0.4, 0.15)
			else:
				GameManager.hit_stop_smooth(hs_normal_time_scale, hs_normal_duration, 0.0, 0.02) 
				GameEvents.camera_shake_requested.emit(0.2, 0.1)
		else:
			GameManager.hit_stop_smooth(hs_prop_time_scale, hs_prop_duration, 0.0, 0.0) 
			GameEvents.camera_shake_requested.emit(0.1, 0.05)

		# Передаем рассчитанный вектор во врага
		body.take_damage(current_attack_damage, knockback_vec, is_finisher)
		
		# === ОТДАЧА (RECOIL) ===
		var recoil_force = 15.0  # Усиленная отдача
		if is_finisher: recoil_force = 25.0 
		
		velocity -= dir * recoil_force
		# =======================

func take_damage(amount: float, knockback_force: Vector3) -> void:
	if ground_slam_ability.is_slamming or is_invincible: return
	VfxPool.spawn_effect(0, global_position + Vector3(0, 1.5, 0))
	if health_component: health_component.take_damage(amount)
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

func push_obj():
	var dt = get_physics_process_delta_time()
	var collision_count = get_slide_collision_count()
	
	for i in range(collision_count):
		var c = get_slide_collision(i)
		
		if c.get_normal().y > 0.7:
			continue
		
		var collider = c.get_collider()
		var push_dir = -c.get_normal()
		push_dir.y = 0 
		
		if push_dir.length_squared() < 0.001:
			continue
			
		push_dir = push_dir.normalized()
		
		if collider is RigidBody3D:
			var current_force = push_force
			if is_rolling: current_force *= roll_push_multiplier
			collider.apply_central_impulse(push_dir * current_force * dt)
			
		elif collider is CharacterBody3D and collider.has_method("receive_push"):
			var nudge_strength = 10.0 * dt
			if is_rolling: 
				nudge_strength *= 3.0 
				velocity *= 0.95
			collider.receive_push(push_dir * nudge_strength)

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

func get_closest_nav_point() -> Vector3:
	var map = get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, global_position)

func apply_safety_nudge(direction: Vector3, force: float = 5.0):
	velocity = direction * force
	move_and_slide()

func _check_attack_hit() -> void:
	hitbox_active_timer = 0.1
	process_hitbox_check()
