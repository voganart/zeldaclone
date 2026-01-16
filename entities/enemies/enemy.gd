class_name Enemy
extends CharacterBody3D

## ============================================================================
## ENEMY CONTROLLER
## ============================================================================

# ============================================================================
# EXPORTS
# ============================================================================
@export_group("Debug")
@export var show_debug_label: bool = true

@export_group("AI Settings")
@export var can_flee: bool = true
@export_range(0.0, 1.0) var flee_health_threshold: float = 0.25
@export_range(0.0, 1.0) var flee_chance: float = 0.3
@export var help_radius: float = 15.0 

@export_group("Navigation Avoidance")
@export var enable_avoidance: bool = true 
@export var agent_radius: float = 0.6 

@export_group("Hit Stop Settings")
@export var hit_stop_lethal_time_scale: float = 0.5
@export var hit_stop_lethal_duration: float = 0.2
@export var hit_stop_local_duration: float = 0.08

@export_group("AI Specific Movement")
# Базовые Walk/Run/Accel/Rotation теперь в MovementComponent!
@export var retreat_speed: float = 2.5 ## Скорость отступления (AI)
@export var combat_rotation_speed: float = 20.0 ## Быстрый поворот в бою
@export var attack_rotation_speed: float = 2.0 ## Медленный поворот при ударе
@export_range(0, 180) var strafe_view_angle: float = 45.0

@export var knockback_strength: float = 2.0
@export var knockback_duration: float = 0.5

@export_group("Animation Blending")
@export var walk_run_blend_smoothing: float = 8.0

# ============================================================================
# COMPONENT PROXIES (GETTERS)
# ============================================================================
# Это связывает скрипты состояний (States) с данными компонента
var walk_speed: float:
	get: return movement_component.walk_speed
var run_speed: float:
	get: return movement_component.run_speed
var rotation_speed: float:
	get: return movement_component.rotation_speed
var acceleration: float:
	get: return movement_component.acceleration
var friction: float:
	get: return movement_component.friction

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var anim_controller: AnimationController = $Components/AnimationController
@onready var combat_component: CombatComponent = $Components/CombatComponent 
@onready var attack_component: EnemyAttackComponent = $Components/EnemyAttackComponent
@onready var skeleton: Skeleton3D = $Monstr/root/Skeleton3D
@onready var bone_simulator: PhysicalBoneSimulator3D = $Monstr/root/Skeleton3D/PhysicalBoneSimulator3D 

@onready var debug_label: Label3D = $DebugLabel
@onready var state_machine: StateMachine = $StateMachine
@onready var vision_component: VisionComponent = $Components/VisionComponent
@onready var health_component: Node = $Components/HealthComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var alert_indicator = $AlertIndicator

@onready var anim_player: AnimationPlayer = $Monstr/AnimationPlayer
@onready var anim_tree: AnimationTree = $Monstr/AnimationTree 

var vfx_pull: Node3D
@onready var player: Node3D = get_tree().get_first_node_in_group(GameConstants.GROUP_PLAYER)
@onready var patrol_zone: Area3D = get_parent() as Area3D
@onready var sfx_hurt_voice: RandomAudioPlayer3D = $SoundBank/SfxHurtVoice
@onready var sfx_flesh_hit: RandomAudioPlayer3D = $SoundBank/SfxFleshHit
@onready var sfx_death_impact: RandomAudioPlayer3D = $SoundBank/SfxDeathImpact
@onready var health_bar: EnemyHealthBar = $HealthBar3D

# ============================================================================
# SHARED DATA
# ============================================================================
var last_known_player_pos: Vector3 = Vector3.ZERO
var frustrated_cooldown: float = 0.0
var hurt_lock_timer: float = 0.0

var current_movement_blend: float = 0.0
var is_knocked_back: bool = false
var pending_death: bool = false
var knockback_timer: float = 0.0

var physics_update_counter: int = 0
var physics_lod_distance_sq: float = 30.0 * 30.0 
var physics_lod_skip_frames: int = 10 

signal died

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	if movement_component:
		movement_component.init(self)
		# Значения по умолчанию для врага (можно менять в Инспекторе сцены Enemy)
		# movement_component.push_force = 15.0 # (Лучше настроить в сцене)
	
	if combat_component:
		combat_component.init(self)
	
	nav_agent.max_speed = walk_speed
	nav_agent.avoidance_enabled = enable_avoidance
	nav_agent.radius = agent_radius
	nav_agent.neighbor_distance = 10.0 
	nav_agent.time_horizon_obstacles = 1.0 
	nav_agent.time_horizon_agents = 1.0    
	
	if not nav_agent.velocity_computed.is_connected(_on_velocity_computed):
		nav_agent.velocity_computed.connect(_on_velocity_computed)
	
	if not is_in_group(GameConstants.GROUP_ENEMIES):
		add_to_group(GameConstants.GROUP_ENEMIES)
	
	state_machine.init(self)
	
	GraphicsManager.quality_changed.connect(_on_quality_changed)
	
	await get_tree().process_frame
	nav_agent.set_navigation_map(get_world_3d().navigation_map)
	GameEvents.player_died.connect(_on_player_died)
	
	if health_component:
		health_component.died.connect(_on_died)
		health_component.health_changed.connect(_on_health_changed)
		
	if can_flee:
		can_flee = (randf() <= flee_chance)

	if anim_tree: anim_tree.active = true 
	set_tree_state("alive")
	set_move_mode("normal")
	
	physics_update_counter = randi() % physics_lod_skip_frames
	
	AIDirector.register_enemy(self)

func _on_quality_changed(settings: Dictionary):
	if settings.has("ai_phys_lod_dist_sq"):
		physics_lod_distance_sq = settings["ai_phys_lod_dist_sq"]
	if settings.has("ai_phys_lod_skip"):
		physics_lod_skip_frames = settings["ai_phys_lod_skip"]
	print("Enemy %s: Physics LODs updated." % name)

func _exit_tree() -> void:
	AIDirector.unregister_enemy(self)

func _physics_process(delta: float) -> void:
	if is_instance_valid(player):
		var dist_sq = global_position.distance_squared_to(player.global_position)
		if dist_sq > physics_lod_distance_sq: 
			physics_update_counter += 1
			if physics_update_counter < physics_lod_skip_frames:
				if not is_on_floor():
					movement_component.apply_gravity(delta)
					move_and_slide()
				return 
			else:
				physics_update_counter = 0 

	if show_debug_label and debug_label:
		debug_label.visible = true
		_update_debug_info()
	elif debug_label:
		debug_label.visible = false
		
	if movement_component:
		movement_component.apply_gravity(delta)

	if is_knocked_back:
		if knockback_timer > 0:
			knockback_timer -= delta
		
		# Торможение при откидывании (используем friction из компонента)
		var friction_val = friction if movement_component else 2.0
		velocity.x = move_toward(velocity.x, 0, friction_val * delta)
		velocity.z = move_toward(velocity.z, 0, friction_val * delta)
		
		move_and_slide()
		if knockback_timer <= 0 and is_on_floor():
			is_knocked_back = false
			velocity = Vector3.ZERO
			if pending_death:
				_finalize_death()
		return

	if frustrated_cooldown > 0:
		frustrated_cooldown -= delta

	var state_name = state_machine.current_state.name.to_lower()
	if state_name != "dead":
		move_and_slide()
		
	if movement_component:
		movement_component.handle_pushing(false)

func set_animation_process_mode(is_manual: bool):
	if anim_tree:
		if is_manual:
			anim_tree.process_callback = AnimationPlayer.ANIMATION_PROCESS_MANUAL
		else:
			anim_tree.process_callback = AnimationPlayer.ANIMATION_PROCESS_PHYSICS

func manual_animation_advance(delta: float):
	if anim_tree and anim_tree.process_callback == AnimationPlayer.ANIMATION_PROCESS_MANUAL:
		anim_tree.advance(delta)

func _on_visible_on_screen_notifier_3d_screen_entered():
	if anim_tree:
		anim_tree.active = true

func _on_visible_on_screen_notifier_3d_screen_exited():
	if anim_tree:
		anim_tree.active = false

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
	
	var desired_velocity = direction * nav_agent.max_speed
	nav_agent.set_velocity(desired_velocity)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if is_knocked_back: return
	
	var target_vel = safe_velocity
	target_vel.y = velocity.y
	
	var current_state = state_machine.current_state.name.to_lower()
	
	# Агрессивное преследование сквозь препятствия
	if current_state == "chase":
		if safe_velocity.length() < 0.5:
			var next_pos = nav_agent.get_next_path_position()
			var raw_dir = (next_pos - global_position).normalized()
			raw_dir.y = 0
			target_vel = raw_dir * (walk_speed * 0.8)
			target_vel.y = velocity.y
	
	# ИСПОЛЬЗУЕМ ACCELERATION ИЗ КОМПОНЕНТА!
	# Это обеспечивает плавный разгон и остановку согласно настройкам.
	var accel = acceleration if movement_component else 20.0
	velocity = velocity.move_toward(target_vel, accel * get_physics_process_delta_time())

func handle_rotation(delta: float, target_override: Vector3 = Vector3.ZERO, speed_override: float = -1.0) -> void:
	var look_dir: Vector2 = Vector2.ZERO
	
	if target_override != Vector3.ZERO:
		var dir_3d = (target_override - global_position).normalized()
		look_dir = Vector2(dir_3d.x, dir_3d.z)
	elif velocity.length_squared() > 0.1:
		look_dir = Vector2(velocity.x, velocity.z).normalized()
	else:
		return

	# Если speed_override не задан, используем базовый rotation_speed из компонента
	var current_speed = speed_override
	if current_speed <= 0:
		current_speed = rotation_speed # Геттер берет из компонента
		
	if look_dir.length_squared() > 0.001:
		var target_angle = atan2(look_dir.x, look_dir.y)
		rotation.y = lerp_angle(rotation.y, target_angle, current_speed * delta)

func receive_push(push: Vector3) -> void:
	velocity += push

# ============================================================================
# ANIMATION & STATE WRAPPERS
# ============================================================================
func set_tree_state(state_name: String):
	anim_controller.set_state(state_name)

func set_move_mode(mode_name: String):
	anim_controller.set_move_mode(mode_name)

func set_locomotion_blend(value: float):
	anim_controller.set_locomotion_blend(value)
	anim_tree.set("parameters/chase_blend/blend_position", value)

func set_strafe_blend(value: float):
	anim_tree.set("parameters/strafe_blend/blend_position", value)

func trigger_attack_oneshot(attack_name: String):
	var idx = 0
	if "2" in attack_name: idx = 1
	if "3" in attack_name: idx = 2
	anim_controller.trigger_attack(idx)

func trigger_hit_oneshot():
	anim_controller.trigger_hit()

func trigger_knockdown_oneshot():
	anim_tree.set(GameConstants.TREE_ONE_SHOT_KNOCKDOWN, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func trigger_angry_seek(time: float):
	anim_tree.set(GameConstants.TREE_ANGRY_SEEK, time)

func update_movement_animation(delta: float) -> void:
	var current_state_name = state_machine.current_state.name.to_lower()
	var speed_length = velocity.length()

	var should_force_idle = is_knocked_back or current_state_name == "hit"
	if current_state_name == "attack" and speed_length < 0.5:
		should_force_idle = true

	if should_force_idle:
		current_movement_blend = move_toward(current_movement_blend, 0.0, delta * 5.0)
		set_locomotion_blend(current_movement_blend)
		return

	var local_velocity = global_transform.basis.inverse() * velocity
	
	if current_state_name == "combatstance":
		var strafe_val = clamp(local_velocity.x / walk_speed, -1.0, 1.0)
		set_strafe_blend(-strafe_val) 
	else:
		var target_val = 0.0
		var is_moving_backwards = local_velocity.z < -0.1
		
		if speed_length < 0.1:
			target_val = 0.0
		else:
			if is_moving_backwards:
				var back_intensity = clamp(speed_length / walk_speed, 0.0, 1.0)
				target_val = -back_intensity 
			else:
				if speed_length <= walk_speed * 1.2:
					target_val = clamp(speed_length / walk_speed, 0.0, 1.0)
				else:
					target_val = 1.0 + clamp((speed_length - walk_speed) / (run_speed - walk_speed), 0.0, 1.0)

		current_movement_blend = lerp(current_movement_blend, target_val, walk_run_blend_smoothing * delta)
		set_locomotion_blend(current_movement_blend)

# ============================================================================
# COMBAT & DAMAGE
# ============================================================================

func _check_attack_hit() -> void:
	if combat_component:
		combat_component.activate_hitbox_check(0.1)

func take_damage(amount: float, knockback_force: Vector3, is_heavy_attack: bool = false) -> void:
	if is_dead(): return
	frustrated_cooldown = 0.0
	
	_cry_for_help()
	
	var is_lethal = (health_component.current_health - amount) <= 0
	var is_attacking = state_machine.current_state.name.to_lower() == "attack"

	if is_lethal:
		trigger_knockdown_oneshot()
		hurt_lock_timer = 0.5
	elif not is_lethal:
		if is_heavy_attack:
			# Тяжелая атака всегда сбивает врага с ног и прерывает атаку
			if is_attacking:
				AIDirector.return_attack_token(self)
				state_machine.change_state(GameConstants.STATE_CHASE)
			trigger_knockdown_oneshot()
			hurt_lock_timer = 0.5
		else:
			# --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
			# Hyper Armor: Если враг атакует, обычный удар НЕ вызывает анимацию боли (Hit),
			# и, следовательно, НЕ прерывает его атаку.
			if is_attacking:
				# Урон проходит, вспышка есть, но анимация продолжается.
				# Это позволит врагу завершить удар и нанести урон игроку (Trade).
				pass
			else:
				# Если враг просто стоит/бежит, он вздрагивает.
				trigger_hit_oneshot()
				hurt_lock_timer = 0.2
			# -------------------------

	VfxPool.spawn_effect(0, global_position + Vector3(0, 1.5, 0))
	$HitFlash.flash()
	if sfx_hurt_voice: sfx_hurt_voice.play_random()
	if sfx_flesh_hit: sfx_flesh_hit.play_random()
	
	if health_component:
		health_component.take_damage(amount)
		
	state_machine.current_state.on_damage_taken(is_heavy_attack)
	
	var final_force = knockback_force
	
	if is_lethal:
		if final_force.length() < 1.0:
			final_force = -global_transform.basis.z * 5.0
		final_force.y = max(final_force.y, 6.0) 
		
		var horiz = Vector2(final_force.x, final_force.z)
		if horiz.length() < 3.0:
			horiz = horiz.normalized() * 5.0
			final_force.x = horiz.x
			final_force.z = horiz.y

	if final_force.length() > 0.5:
		velocity = final_force
		is_knocked_back = true
		knockback_timer = 0.2 

func _cry_for_help() -> void:
	var enemies = get_tree().get_nodes_in_group(GameConstants.GROUP_ENEMIES)
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead():
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= help_radius:
			enemy.hear_alert(player)

func hear_alert(_target: Node3D) -> void:
	if is_dead(): return
	var current_state = state_machine.current_state.name.to_lower()
	if current_state in ["attack", "chase", "combatstance", "hit", "dead"]:
		return
	print(name, " heard call for help!")
	state_machine.change_state(GameConstants.STATE_CHASE)

func _on_died() -> void:
	if is_knocked_back:
		pending_death = true
		return
	_finalize_death()

func _finalize_death() -> void:
	pending_death = false
	AIDirector.return_attack_token(self)
	MusicBrain.set_combat_state(false)
	emit_signal("died")
	if health_bar: health_bar.visible = false
	if combat_component: combat_component._stop_hitbox_monitoring()
	
	# --- НОВОЕ: СПАВН ЛУТА ---
	# Спавним Вабо (индекс 1)
	# Шанс дропа 100% для теста, потом можно сделать рандом
	if ItemPool.has_method("spawn_item"):
		var pickup = ItemPool.spawn_item(1, global_position + Vector3(0, 0.5, 0))
		
		# Делаем красивый вылет (если предмет заспавнился)
		if pickup:
			var rng_dir = Vector3(randf_range(-1, 1), 5.0, randf_range(-1, 1)).normalized()
			pickup.apply_impulse(rng_dir * 5.0)
	# -------------------------
	
	state_machine.change_state(GameConstants.STATE_DEAD)

# ============================================================================
# UI & MISC
# ============================================================================
func _on_health_changed(new_health: float, _max_hp: float) -> void:
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

func _update_debug_info() -> void:
	var state_name = "None"
	if state_machine.current_state:
		state_name = state_machine.current_state.name
	
	var raw_move_mode = anim_tree.get("parameters/move_mode/transition_request")
	var move_mode_idx = 0
	if typeof(raw_move_mode) == TYPE_INT:
		move_mode_idx = raw_move_mode
	
	var move_mode_str = "Normal"
	if move_mode_idx == 1: move_mode_str = "Strafe"
	elif move_mode_idx == 2: move_mode_str = "Chase"
	
	var hp = 0
	if health_component: hp = ceil(health_component.current_health)
	
	debug_label.text = "State: %s\nMode: %s\nHP: %d" % [state_name, move_mode_str, hp]
	
	if state_name.to_lower() == "attack": debug_label.modulate = Color.RED
	elif state_name.to_lower() == "chase": debug_label.modulate = Color.ORANGE
	elif state_name.to_lower() == "patrol": debug_label.modulate = Color.GREEN
	else: debug_label.modulate = Color.WHITE
	
func activate_ragdoll(force_vector: Vector3) -> void:
	print("--- RAGDOLL ACTIVATION (SIMULATOR MODE) ---")
	
	$CollisionShape3D.set_deferred("disabled", true)
	nav_agent.velocity = Vector3.ZERO
	
	if anim_tree:
		anim_tree.active = false
	if anim_player:
		anim_player.stop()
	
	if bone_simulator:
		bone_simulator.physical_bones_start_simulation()
		
		var pushed = false
		for child in bone_simulator.get_children():
			if child is PhysicalBone3D:
				if "Hips" in child.name or "Spine" in child.name or "Pelvis" in child.name:
					child.apply_central_impulse(force_vector * 30.0)
					pushed = true
					break
		
		if not pushed and bone_simulator.get_child_count() > 0:
			var first_bone = bone_simulator.get_child(0) as PhysicalBone3D
			if first_bone:
				first_bone.apply_central_impulse(force_vector * 30.0)
	else:
		printerr("ERROR: PhysicalBoneSimulator3D не найден! Проверь путь в скрипте!")
