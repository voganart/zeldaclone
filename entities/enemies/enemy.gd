class_name Enemy
extends CharacterBody3D

## ============================================================================
## ENEMY CONTROLLER (AnimationTree Refactor)
## ============================================================================

# ============================================================================
# EXPORTS
# ============================================================================
@export_group("Components")
@export var punch_hand_r: Area3D
@export var punch_hand_l: Area3D
@export var punch_area: Area3D
@export var can_flee: bool = true
@export_range(0.0, 1.0) var flee_health_threshold: float = 0.25
@export_range(0.0, 1.0) var flee_chance: float = 0.3

@export_group("Hit Stop Settings")
@export var hit_stop_lethal_time_scale: float = 0.5
@export var hit_stop_lethal_duration: float = 0.2
@export var hit_stop_local_duration: float = 0.08

@export_group("Movement")
@export var walk_speed: float = 1.5
@export var run_speed: float = 3.5
@export var retreat_speed: float = 2.5
@export var rotation_speed: float = 6.0
@export var combat_rotation_speed: float = 30.0
@export_range(0, 180) var strafe_view_angle: float = 45.0
@export var gravity: float = 30.0
@export var knockback_strength: float = 2.0
@export var knockback_duration: float = 0.5

@export_group("Animation Blending")
@export var walk_run_blend_smoothing: float = 8.0
@export var walk_run_blend_start_speed: float = 1.8
@export var walk_run_blend_end_speed: float = 3.2

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var state_machine: StateMachine = $StateMachine
@onready var vision_component: VisionComponent = $VisionComponent
@onready var attack_component: EnemyAttackComponent = $EnemyAttackComponent
@onready var health_component: Node = $HealthComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# --- ANIMATION SYSTEM ---
@onready var anim_player: AnimationPlayer = $Monstr/AnimationPlayer
@onready var anim_tree: AnimationTree = $Monstr/AnimationTree
# ------------------------

var vfx_pull: Node3D
@onready var player: Node3D = get_tree().get_first_node_in_group(GameConstants.GROUP_PLAYER)
@onready var patrol_zone: Area3D = get_parent() as Area3D
@onready var sfx_hurt_voice: RandomAudioPlayer3D = $SoundBank/SfxHurtVoice
@onready var sfx_flesh_hit: RandomAudioPlayer3D = $SoundBank/SfxFleshHit
@onready var sfx_death_impact: RandomAudioPlayer3D = $SoundBank/SfxDeathImpact
@onready var health_bar: EnemyHealthBar = $HealthBar3D

# ============================================================================
# ANIMATION TREE PATHS
# ============================================================================
const TREE_STATE = "parameters/state/transition_request" # alive, dead, angry
const TREE_MOVE_MODE = "parameters/move_mode/transition_request" # normal, strafe
const TREE_ATTACK_IDX = "parameters/attack_idx/transition_request" # Attack1, Attack2

const TREE_ONE_SHOT_ATTACK = "parameters/attack_oneshot/request"
const TREE_ONE_SHOT_HIT = "parameters/hit_oneshot/request"
const TREE_ONE_SHOT_KNOCKDOWN = "parameters/knockdown_oneshot/request"

const TREE_BLEND_LOCOMOTION = "parameters/locomotion_blend/blend_position"
const TREE_BLEND_STRAFE = "parameters/strafe_blend/blend_position"
const TREE_ANGRY_SEEK = "parameters/TimeSeek/seek_request"

# ============================================================================
# SHARED DATA
# ============================================================================
var vertical_velocity: float = 0.0
var external_push: Vector3 = Vector3.ZERO
var last_known_player_pos: Vector3 = Vector3.ZERO
var frustrated_cooldown: float = 0.0
var hurt_lock_timer: float = 0.0

var current_movement_blend: float = 0.0
var target_movement_blend: float = 0.0
var is_knocked_back: bool = false
var pending_death: bool = false
var knockback_timer: float = 0.0

signal died

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	nav_agent.max_speed = walk_speed
	state_machine.init(self)
	nav_agent.avoidance_enabled = true
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	
	await get_tree().process_frame
	nav_agent.set_navigation_map(get_world_3d().navigation_map)
	GameEvents.player_died.connect(_on_player_died)
	
	if health_component:
		health_component.died.connect(_on_died)
		health_component.health_changed.connect(_on_health_changed)
		
	if can_flee:
		can_flee = (randf() <= flee_chance)

	# Активируем дерево анимации
	anim_tree.active = true
	set_tree_state("alive")
	set_move_mode("normal")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Обработка нокбэка
	if is_knocked_back:
		knockback_timer -= delta
		if knockback_timer <= 0:
			is_knocked_back = false
			velocity.x = 0
			velocity.z = 0
			
			if pending_death:
				pending_death = false
				state_machine.change_state(GameConstants.STATE_DEAD)
				if health_bar: health_bar.visible = false
				emit_signal("died")
		
		velocity.x = move_toward(velocity.x, 0, 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 2.0 * delta)
		move_and_slide()
		return

	if frustrated_cooldown > 0:
		frustrated_cooldown -= delta

	# Управление движением через машину состояний
	var state_name = state_machine.current_state.name.to_lower()
	if state_name != "chase" and state_name != "patrol":
		move_and_slide()

# ============================================================================
# MOVEMENT HELPERS
# ============================================================================
func move_toward_path() -> void:
	if nav_agent.is_navigation_finished():
		nav_agent.set_velocity(Vector3.ZERO)
		return
	
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	direction.y = 0
	nav_agent.set_velocity(direction * nav_agent.max_speed)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if is_knocked_back: return
	var target_vel = safe_velocity
	target_vel.y = velocity.y
	velocity = velocity.move_toward(target_vel, 20.0 * get_physics_process_delta_time())
	move_and_slide()

func handle_rotation(delta: float, target_override: Vector3 = Vector3.ZERO, speed_override: float = -1.0) -> void:
	if target_override != Vector3.ZERO:
		if global_position.distance_squared_to(target_override) < 0.01: return
	
	var look_dir: Vector3
	if target_override != Vector3.ZERO:
		look_dir = (target_override - global_position).normalized()
	elif velocity.length_squared() > 0.1:
		look_dir = Vector3(velocity.x, 0, velocity.z).normalized()
	else:
		return

	look_dir.y = 0
	if look_dir.is_normalized():
		var current_forward = - global_transform.basis.z.normalized()
		var angle_to_target = current_forward.signed_angle_to(look_dir, Vector3.UP)
		var current_rotation_speed = speed_override if speed_override > 0 else rotation_speed
		var max_rotation_angle = current_rotation_speed * delta
		var rotation_angle = clamp(angle_to_target, -max_rotation_angle, max_rotation_angle)
		rotate_y(rotation_angle)

func receive_push(push: Vector3) -> void:
	external_push += push

# ============================================================================
# ANIMATION TREE WRAPPERS
# ============================================================================
func set_tree_state(state_name: String):
	anim_tree.set(TREE_STATE, state_name)

func set_move_mode(mode_name: String):
	# "normal" или "strafe"
	anim_tree.set(TREE_MOVE_MODE, mode_name)

func set_locomotion_blend(value: float):
	anim_tree.set(TREE_BLEND_LOCOMOTION, value)

func set_strafe_blend(value: float):
	anim_tree.set(TREE_BLEND_STRAFE, value)

func trigger_attack_oneshot(attack_name: String):
	# attack_name должен быть "Attack1" или "Attack2" согласно Transition в дереве
	anim_tree.set(TREE_ATTACK_IDX, attack_name)
	anim_tree.set(TREE_ONE_SHOT_ATTACK, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func trigger_hit_oneshot():
	anim_tree.set(TREE_ONE_SHOT_HIT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func trigger_knockdown_oneshot():
	anim_tree.set(TREE_ONE_SHOT_KNOCKDOWN, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func trigger_angry_seek(time: float):
	anim_tree.set(TREE_ANGRY_SEEK, time)

func update_movement_animation(delta: float) -> void:
	var speed_length = velocity.length()
	
	# Получаем локальную скорость для стрейфа
	var local_velocity = global_transform.basis.inverse() * velocity
	
	# Проверяем текущий режим в дереве, но это сложно, лучше полагаться на состояние FSM
	# Если мы в режиме стрейфа:
	if state_machine.current_state.name.to_lower() == "combatstance":
		# Strafe Logic: Left (-1) / Right (1)
		# Нормализуем локальную X скорость
		var strafe_val = clamp(local_velocity.x / walk_speed, -1.0, 1.0)
		# Инвертируем, если анимация требует (зависит от рига), обычно Left = +1 или -1
		# Предположим blend: -1 Left, 1 Right
		set_strafe_blend(-strafe_val) 
	else:
		# Locomotion Logic: Idle (0) -> Walk (1) -> Run (2) (примерно)
		# Используем твой блендинг
		var blend = inverse_lerp(walk_run_blend_start_speed, walk_run_blend_end_speed, speed_length)
		target_movement_blend = clamp(blend, 0.0, 1.0)
		current_movement_blend = lerp(current_movement_blend, target_movement_blend, walk_run_blend_smoothing * delta)
		
		# Маппинг на BlendSpace1D (предположим: 0=Idle, 1=Walk, 2=Run)
		# Если в blendspace 0..1, то просто передаем нормализованную скорость
		var tree_blend_val = 0.0
		if speed_length < 0.1:
			tree_blend_val = 0.0
		elif current_movement_blend < 0.5:
			tree_blend_val = clamp(speed_length / walk_speed, 0.0, 1.0) # Walk zone
		else:
			tree_blend_val = 1.0 + clamp(speed_length / run_speed, 0.0, 1.0) # Run zone (если space до 2.0)
		
		# Упрощенно, если BlendSpace от 0 до 1:
		set_locomotion_blend(speed_length / run_speed)

# ============================================================================
# COMBAT & DAMAGE
# ============================================================================
func take_damage(amount: float, knockback_force: Vector3, is_heavy_attack: bool = false) -> void:
	if is_dead(): return
	frustrated_cooldown = 0.0
	var is_lethal = (health_component.current_health - amount) <= 0
	var is_attacking = state_machine.current_state.name.to_lower() == "attack"

	if is_lethal:
		if hit_stop_lethal_time_scale < 1.0:
			GameManager.hit_stop_smooth(hit_stop_lethal_time_scale, hit_stop_lethal_duration)
	elif not is_lethal:
		if is_heavy_attack:
			# KNOCKDOWN
			if is_attacking:
				AIDirector.return_attack_token(self)
				state_machine.change_state(GameConstants.STATE_CHASE)
			
			trigger_knockdown_oneshot()
			hurt_lock_timer = 0.5
		else:
			# HIT (STUTTER)
			if is_attacking:
				# Для AnimationTree HitStop реализуем через паузу анимации или TimeScale
				# GameManager делает hit_stop_local на AnimationPlayer, это должно работать и с деревом
				GameManager.hit_stop_local([anim_player], 0.15)
			else:
				trigger_hit_oneshot()
				hurt_lock_timer = 0.2

	VfxPool.spawn_effect(0, global_position + Vector3(0, 1.5, 0))
	$HitFlash.flash()
	if sfx_hurt_voice: sfx_hurt_voice.play_random()
	if sfx_flesh_hit: sfx_flesh_hit.play_random()
	
	if health_component:
		health_component.take_damage(amount)
	
	if knockback_force.length() > 0.5:
		velocity = knockback_force
		is_knocked_back = true
		knockback_timer = 0.2

func _on_died() -> void:
	if is_knocked_back:
		pending_death = true
		return
	AIDirector.return_attack_token(self)
	emit_signal("died")
	if health_bar: health_bar.visible = false
	state_machine.change_state(GameConstants.STATE_DEAD)

# Animation Event Call
func _check_attack_hit() -> void:
	var hits_found = false
	if punch_hand_r and _check_single_hand_hit(punch_hand_r): hits_found = true
	if not hits_found and punch_hand_l: _check_single_hand_hit(punch_hand_l)

func _check_single_hand_hit(hand_area: Area3D) -> bool:
	if not hand_area.monitoring: return false
	if punch_area:
		var valid_targets = punch_area.get_overlapping_bodies()
		if not valid_targets.has(player): return false

	var bodies = hand_area.get_overlapping_bodies()
	for body in bodies:
		if body == player:
			var knockback_dir = (player.global_position - global_position).normalized()
			knockback_dir.y = 0.5
			knockback_dir = knockback_dir.normalized() * knockback_strength
			if player.has_method("take_damage"):
				player.take_damage(1.0, knockback_dir)
				return true
	return false

# ============================================================================
# UI & MISC
# ============================================================================
func _on_health_changed(new_health: float) -> void:
	if health_bar and health_component:
		health_bar.update_health(new_health, health_component.get_max_health())
	
	if not can_flee: return
	var max_hp = health_component.get_max_health()
	if max_hp <= 0: return
	
	var current_state_name = state_machine.current_state.name.to_lower()
	if current_state_name == "dead" or current_state_name == "flee": return
	
	if (new_health / max_hp) <= flee_health_threshold:
		state_machine.change_state("flee")
		
func _on_player_died() -> void:
	if state_machine.current_state.name.to_lower() == GameConstants.STATE_DEAD: return
	player = null
	if attack_component.has_method("clear_retreat_state"):
		attack_component.clear_retreat_state()
	state_machine.change_state(GameConstants.STATE_PATROL)

func is_dead() -> bool:
	if state_machine and state_machine.current_state:
		return state_machine.current_state.name.to_lower() == GameConstants.STATE_DEAD
	return false
