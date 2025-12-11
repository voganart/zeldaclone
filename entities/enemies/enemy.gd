extends CharacterBody3D

## ============================================================================
## ENEMY AI - Refactored for Robustness & Maintainability
## ============================================================================

# ============================================================================
# ENUMS & CONSTANTS
# ============================================================================
enum State {IDLE, PATROL, CHASE, FRUSTRATED, ATTACK, FLEE, KNOCKBACK, DEAD}
# ---------------- Debug AI ----------------
@export var debug_ai: bool = true
@export var debug_ai_interval: float = 0.5 # seconds between prints
var _debug_ai_acc: float = 0.0
# ------------------------------------------
# ============================================================================
# EXPORTS - Grouped for Designer UX
# ============================================================================
@export_group("Health & Damage")
@onready var vfx_pull: Node3D = $"../../../VfxPull"

# @export var max_hp: float = 10.0 # Use HealthComponent for max_hp!

@export var health_bar_visible_time: float = 1.0 # сколько секунд бар остаётся видимым после урона
@export var health_bar_fade_speed: float = 3.0 # скорость ухода в прозрачность


@export_group("Movement")
@export var walk_speed: float = 1.5
@export var run_speed: float = 3.5
@export var rotation_speed: float = 6.0
@export var obstacle_face_angle_deg: float = 60.0

@export_group("Combat")
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var tactical_retreat_chance: float = 0.3 # 30% chance to retreat after attack
@export var tactical_retreat_distance: float = 4.0
@export var tactical_retreat_pause_min: float = 0.5
@export var tactical_retreat_pause_max: float = 1.5
@export var attack_speed: float = 1.0
@export var attack_impulse: float = 2.0 # Forward impulse applied when performing attack

@export_group("Detection")
@export var sight_range: float = 10.0
@export var lost_sight_range: float = 15.0
@export_range(0, 360) var sight_angle: float = 120.0 # Field of view in degrees
@export var proximity_detection_range: float = 3.0 # Detect player in 360 degrees if overly close
@export var eye_height_offset: float = 1.0 # Height of enemy eyes
@export var player_height_offset: float = 0.5 # Height of player target point
@export var chase_memory_duration: float = 7.0 # Remember player position
@export var debug_vision: bool = false # Draw debug info for vision

@export_group("Behavior Timers")
@export var idle_duration_min: float = 3.0
@export var idle_duration_max: float = 7.0
@export var idle_chance: float = 0.8 # 80% chance to idle after patrol
@export var frustration_duration: float = 3.0 # Time before getting frustrated
@export var give_up_duration: float = 5.0 # Total time before giving up
@export var chase_cooldown_duration: float = 2.0 # Time to ignore player after frustration
var frustrated_cooldown: float = 0.0

# Flee settings
@export var flee_charges_max: int = 1
@export var flee_duration: float = 3.0
@export var flee_heal_delay: float = 10.0 # seconds without taking damage before passive heal
@export var flee_heal_per_second: float = 1.0 # HP per second healed when idle
@export var flee_hp_threshold: float = 0.3 # Flee when HP < 30%
@export var flee_chance: float = 0.5 # 50% chance to flee
var current_flee_charges: int = 1
var time_since_last_damaged: float = 9999.0

@export_group("Animation Blending")
@export var walk_run_blend_smoothing: float = 8.0
@export var walk_run_blend_start_speed: float = 1.8
@export var walk_run_blend_end_speed: float = 3.2

var current_movement_blend: float = 0.0
var target_movement_blend: float = 0.0


@export_group("Physics")
@export var gravity: float = 100.0
@export var knockback_strength: float = 2.0
@export var knockback_height: float = 5.0
@export var knockback_duration: float = 0.5
@export var stuck_threshold: float = 0.1 # Time before considered stuck

# ============================================================================
# STATE VARIABLES
# ============================================================================
var current_state: State = State.IDLE
var state_timer: float = 0.0 # Robust timer for state durations
var last_dist_to_target: float = INF


# ============================================================================
# RUNTIME VARIABLES
# ============================================================================
var will_flee: bool = false
var last_known_player_pos: Vector3 = Vector3.ZERO
var time_since_player_seen: float = 0.0
var last_attack_time: float = -999.0
var time_stuck: float = 0.0

var frustration_total_time: float = 0.0

# Attack state
var is_attacking: bool = false
var should_tactical_retreat: bool = false
var tactical_retreat_pause_timer: float = 0.0
var tactical_retreat_target: Vector3 = Vector3.ZERO
var is_in_tactical_retreat: bool = false # Used to prevent animation update conflicts
var monster_attacks = ["Monstr_attack_1", "Monstr_attack_2"]
var last_attack_index = -1
var anim_to_play = "" # Will be set by get_next_attack()

# Idle state
var idle_look_timer: float = 0.0
var idle_target_angle: float = 0.0
var is_looking_around: bool = false

# Physics
var vertical_velocity: float = 0.0
var external_push: Vector3 = Vector3.ZERO

# Debug Visuals
var debug_sight_mesh: MeshInstance3D
var debug_proximity_mesh: MeshInstance3D

# Navigation
var nav_ready: bool = false

# UI
var health_bar_mesh: MeshInstance3D
var health_bar_opacity: float = 0.0
var health_bar_timer: float = 0.0
var health_bar_enabled: bool = true
var health: float = 1.0
var delayed_health: float = 1.0

signal died


# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var patrol_zone: Area3D = get_parent() as Area3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var anim_player: AnimationPlayer = $Monstr/AnimationPlayer
@export var punch_hand_r: Area3D # Assign in editor!
@export var punch_hand_l: Area3D # Assign in editor!
@export var punch_area: Area3D # Main attack cone for hit validation
@onready var health_component: Node = $HealthComponent
@onready var health_bar_node: Node3D = $HealthBar3D

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	# Инициализация переменных здоровья и бара
	health = health_component.get_health() / health_component.get_max_health() if health_component else 1.0
	delayed_health = health
	health_bar_opacity = 0.0  # изначально невидим

	initialize_navigation()
	will_flee = randf() < flee_chance

	# Flee charges initialization
	current_flee_charges = flee_charges_max
	time_since_last_damaged = flee_heal_delay + 1.0

	# Connect to HealthComponent signals
	if health_component:
		health_component.died.connect(die)
		health_component.health_changed.connect(_on_health_changed)

	# Setup Health Bar
	if health_bar_node:
		# Найти MeshInstance3D внутри health_bar_node
		for child in health_bar_node.get_children():
			if child is MeshInstance3D:
				health_bar_mesh = child
				break
		# Если нашли mesh и есть health_component, обновляем визуально
		if health_bar_mesh:
			_update_health_bar_visuals(health, delayed_health, health_bar_opacity)

	# Setup navigation
	nav_agent.max_speed = walk_speed
	nav_agent.avoidance_enabled = true
	nav_agent.velocity_computed.connect(_on_velocity_computed)

	if debug_vision:
		_setup_debug_meshes()


func initialize_navigation():
	await get_tree().process_frame
	nav_agent.set_navigation_map(get_world_3d().navigation_map)
	nav_ready = true
	
#func _on_navmesh_ready(_map_rid) -> void:
	#if is_inside_tree():
		#nav_ready = true
		#enter_state(State.PATROL)
		#
	#if is_inside_tree():
		#nav_ready = true
		#enter_state(State.PATROL)
		#
		## Initialize punch hand
		#if punch_hand_r:
			## Signal no longer needed - using Animation Event
			#pass

# Called by AnimationPlayer Call Method Track
func _check_attack_hit() -> void:
	var hits_found = false
	
	# Check Right Hand
	if punch_hand_r:
		if _check_single_hand_hit(punch_hand_r):
			hits_found = true
			
	# Check Left Hand (if we haven't hit yet, or if we want double hits - usually one hit per event is safer, but checking both ensures we catch whatever hits)
	# If we want strictly one hit per event frame regardless of how many hands touch:
	if not hits_found and punch_hand_l:
		_check_single_hand_hit(punch_hand_l)

func _check_single_hand_hit(hand_area: Area3D) -> bool:
	if not hand_area.monitoring:
		return false
	
	# If punch_area is assigned, ensure the target is also within this general attack cone
	# This prevents backward hits or hits when the enemy isn't facing the target properly
	if punch_area:
		var valid_targets = punch_area.get_overlapping_bodies()
		var is_target_in_cone = false
		for body in valid_targets:
			if body == player:
				is_target_in_cone = true
				break
		if not is_target_in_cone:
			return false

	var overlapping_bodies = hand_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body == player:
			# Calculate knockback direction (away from enemy)
			var knockback_dir = (player.global_position - global_position).normalized()
			# Add some upward force
			knockback_dir.y = 0.5
			knockback_dir = knockback_dir.normalized() * knockback_strength
			
			if player.has_method("take_damage"):
				player.take_damage(1.0, knockback_dir)
				return true # Hit successful
	return false

# ============================================================================
# MAIN LOOP
# ============================================================================
func _physics_process(delta: float) -> void:
	# --- debug ticking ---
	if debug_ai:
		_debug_ai_acc += delta
		if _debug_ai_acc >= debug_ai_interval:
			_debug_ai_acc = 0.0
			_debug_ai_log()
	if not nav_ready:
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	vertical_velocity = velocity.y
	
	# Update player visibility
	var player_visible = _can_see_player()
	if player_visible:
		time_since_player_seen = 0.0
	else:
		time_since_player_seen += delta

	# Passive heal when idle (no damage for configured delay)
	time_since_last_damaged += delta
	if time_since_last_damaged > flee_heal_delay and health_component:
		var cur = health_component.get_health()
		var maxh = health_component.get_max_health()
		if cur < maxh:
			# Heal gradually
			health_component.heal(min(flee_heal_per_second * delta, maxh - cur))
	
	# Detect stuck
	_update_stuck_detection(delta)
	
	# Update current state
	state_timer -= delta
	_update_state(delta, player_visible)
	
	# Handle rotation
	_update_rotation(delta)

	# Update movement animations (walk <-> run blending)
	enemy_animation_update(delta)
	
	if debug_vision:
		_update_debug_meshes()

	_update_health_bar_process(delta)

# ============================================================================
# STATE MACHINE - Enter/Update/Exit Pattern
# ============================================================================
func enter_state(new_state: State) -> void:
	var prev_state = current_state
	# Exit old state
	match current_state:
		State.IDLE:
			is_looking_around = false
		State.ATTACK:
			is_attacking = false
			should_tactical_retreat = false
			tactical_retreat_pause_timer = 0.0

	current_state = new_state
	state_timer = 0.0

	# Enter new state
	match current_state:
		State.IDLE:
			nav_agent.max_speed = 0.0
			play_with_random_offset("Monstr_idle", 0.2, 1.0)
			state_timer = randf_range(idle_duration_min, idle_duration_max)
			idle_look_timer = randf_range(1.5, 4.0)

		State.PATROL:
			nav_agent.max_speed = walk_speed
			play_with_random_offset("Monstr_walk", 0.2, 1.0)
			_set_random_patrol_target()

		State.CHASE:
			# Reset stuck timer if moving normally
			if velocity.length() > 0.2:
				time_stuck = 0.0
			# init last dist so chase stuck logic starts sane
			if is_instance_valid(player):
				last_dist_to_target = global_position.distance_to(player.global_position)
			else:
				last_dist_to_target = INF
			nav_agent.max_speed = run_speed
			play_with_random_offset("Monstr_walk", 0.2, 1.0)
			state_timer = 0.0

		State.FRUSTRATED:
			print("[AI] ENTER FRUSTRATED at pos=%.2f,%.2f,%.2f; last_dist=%.2f time_stuck=%.2f" % [global_position.x, global_position.y, global_position.z, last_dist_to_target, time_stuck])
			frustration_total_time = 0.0
			nav_agent.max_speed = 0.0
			last_dist_to_target = INF
			anim_player.play("Monstr_angry", 0.2, 1.0)
			state_timer = frustration_duration

		State.ATTACK:
			frustration_total_time = 0.0
			nav_agent.max_speed = 0.0

		State.FLEE:
			nav_agent.max_speed = run_speed * 0.6
			play_with_random_offset("Monstr_walk", 0.2, 1.0)
			state_timer = flee_duration
			if current_flee_charges > 0:
				current_flee_charges -= 1

		State.KNOCKBACK:
			anim_player.play("Monstr_knockdown", 0.5, 1.0)
			state_timer = knockback_duration
	print("[AI] enter_state -> %s (from %s)" % [str(current_state), str(prev_state) if "prev_state" in self else "unknown"])
	


func _update_state(delta: float, player_visible: bool) -> void:
	match current_state:
		State.IDLE:
			_update_idle(delta, player_visible)
		State.PATROL:
			_update_patrol(delta, player_visible)
		State.CHASE:
			_update_chase(delta, player_visible)
		State.FRUSTRATED:
			_update_frustrated(delta)
		State.ATTACK:
			_update_attack(delta)
		State.FLEE:
			_update_flee(delta)
		State.KNOCKBACK:
			_update_knockback(delta)

# ============================================================================
# STATE UPDATE FUNCTIONS
# ============================================================================
func _update_idle(delta: float, player_visible: bool) -> void:
	nav_agent.set_velocity(Vector3.ZERO)
	
	# Spot player
	if player_visible:
		enter_state(State.CHASE)
		return
	
	# Look around behavior
	idle_look_timer -= delta
	if idle_look_timer <= 0:
		is_looking_around = !is_looking_around
		idle_look_timer = randf_range(1.5, 4.0)
		if is_looking_around:
			idle_target_angle = rotation.y + randf_range(-PI / 3, PI / 3)
	
	if is_looking_around:
		rotation.y = lerp_angle(rotation.y, idle_target_angle, delta * 2.0)
	
	# Timeout -> Patrol
	if state_timer <= 0:
		enter_state(State.PATROL)

func _update_patrol(_delta: float, player_visible: bool) -> void:
	# Уменьшаем кулдаун если он есть, но не делаем врага полностью слепым
	if frustrated_cooldown > 0:
		frustrated_cooldown = max(frustrated_cooldown - _delta, 0.0)

	# Spot player (патруль может всё ещё увидеть игрока)
	if player_visible and frustrated_cooldown <= 0:
		enter_state(State.CHASE)
		return

	# Проверка застревания по скорости
	if velocity.length() < 0.1:
		time_stuck += _delta
	else:
		time_stuck = 0.0

	# Проверка достижения текущей патрульной точки
	if nav_agent.is_navigation_finished():
		if randf() < idle_chance:
			enter_state(State.IDLE)
		else:
			_set_random_patrol_target()
		return

	# Stuck recovery (если застряли при патруле)
	if time_stuck > stuck_threshold:
		time_stuck = 0.0
		_set_random_patrol_target()
		return

	# Движение к цели патруля
	_move_toward_target()



func _update_chase(delta: float, player_visible: bool) -> void:
	var path = nav_agent.get_current_navigation_path()
	print("[CHASE PATH] finished=", nav_agent.is_navigation_finished(),
		" path_points=", path.size(),
		" target=", nav_agent.target_position)
	# Если фрустрация ещё не остыла — просто уменьшаем кулдаун и не насильно переключаем стейт
	if frustrated_cooldown > 0:
		frustrated_cooldown = max(frustrated_cooldown - delta, 0.0)
		# не делать enter_state тут
		return

	state_timer += delta
	
	# Проверка на валидность игрока
	if not is_instance_valid(player):
		enter_state(State.PATROL)
		return

	# Update last known position
	if player_visible:
		last_known_player_pos = player.global_position

	var dist_to_player = global_position.distance_to(player.global_position)

	# --- Проверка прогресса приближения (стабильная логика stuck) ---
	# Инициализируем last_dist_to_target при первом заходе в chase
	if last_dist_to_target == INF:
		last_dist_to_target = dist_to_player

	if dist_to_player > last_dist_to_target + 0.1:
		time_stuck += delta
	else:
		# если есть прогресс — уменьшать time_stuck
		time_stuck = max(time_stuck - delta * 2.0, 0.0)

	# сохраняем для следующего кадра
	last_dist_to_target = dist_to_player

	var time_now = Time.get_ticks_msec() / 1000.0

	# 1. Проверка на Атаку / Кружение (Attack or Orbit)
	if dist_to_player <= attack_range:
		if time_now - last_attack_time >= attack_cooldown:
			enter_state(State.ATTACK)
			return
		else:
			var player_dir = (player.global_position - global_position).normalized()
			var orbit_dir = Vector3(player_dir.z, 0, -player_dir.x)
			nav_agent.max_speed = walk_speed * 0.7
			var orbit_target = global_position + orbit_dir * attack_range * 0.5
			nav_agent.target_position = orbit_target
			_move_toward_target()
			play_with_random_offset("Monstr_walk", 0.2, 1.0)
			return # движение обработано

	# 2. Потеря игрока по памяти / дальности
	if time_since_player_seen > chase_memory_duration:
		enter_state(State.PATROL)
		return

	if dist_to_player > lost_sight_range:
		enter_state(State.PATROL)
		return

	if time_stuck > 0:
		print("[AI] chase progress: dist=%.2f last_dist=%.2f time_stuck=%.2f" % [dist_to_player, last_dist_to_target, time_stuck])
	# 3. Проверка на Застревание -> FRUSTRATED
	if time_stuck > stuck_threshold:
		time_stuck = 0.0
		# готовим last_dist_to_target на будущее
		last_dist_to_target = INF
		enter_state(State.FRUSTRATED)
		return

	# 5. Движение Погони
	if is_instance_valid(player):
		nav_agent.target_position = player.global_position
		nav_agent.max_speed = run_speed
		_move_toward_target()


func _update_frustrated(delta: float) -> void:
	nav_agent.set_velocity(Vector3.ZERO)

	frustration_total_time += delta
	state_timer -= delta

	if _can_reach_player_again():
		print("[AI] player reachable again from FRUSTRATED -> CHASE")
		_exit_frustration_to_chase()
		return

	if frustration_total_time >= give_up_duration:
		_exit_frustration_to_patrol()
		return

	if state_timer <= 0.0:
		_exit_frustration_to_patrol()
		return
	if state_timer <= 0.0:
		print("[AI] frustrated timer ended -> going to PATROL")
		_exit_frustration_to_patrol()
		return

func _exit_frustration_to_patrol():
	frustration_total_time = 0.0
	frustrated_cooldown = chase_cooldown_duration
	enter_state(State.PATROL)
	print("State: Patrol from Frustrated")

func _exit_frustration_to_chase():
	frustration_total_time = 0.0
	frustrated_cooldown = 0.0
	enter_state(State.CHASE)
	print("State: Chase from Frustrated")

func _update_attack(delta: float) -> void:
	# Wait for attack animation
	if is_attacking:
		nav_agent.set_velocity(Vector3.ZERO)
		return
	
	# Tactical retreat phase
	if should_tactical_retreat:
		is_in_tactical_retreat = true
		nav_agent.max_speed = run_speed * 0.8

		# Use the precomputed retreat target (set when retreat was triggered).
		# Fallback: compute local retreat target if none set.
		if tactical_retreat_target == Vector3.ZERO and is_instance_valid(player):
			var retreat_dir = (global_position - player.global_position).normalized()
			tactical_retreat_target = global_position + retreat_dir * tactical_retreat_distance

		nav_agent.target_position = tactical_retreat_target
			
		# Двигаемся к цели отступления
		_move_toward_target()
		# Note: enemy_animation_update will handle animation based on velocity (no explicit anim call)

		# Проверка, достигнута ли цель отступления
		if nav_agent.is_navigation_finished() and tactical_retreat_pause_timer <= 0:
			# Пауза в точке отступления
			nav_agent.set_velocity(Vector3.ZERO)
			anim_player.play("Monstr_attack_idle", 0.2, 1.0)
			tactical_retreat_pause_timer = randf_range(tactical_retreat_pause_min, tactical_retreat_pause_max)

		# Пауза в точке отступления
		if tactical_retreat_pause_timer > 0:
			tactical_retreat_pause_timer -= delta
			nav_agent.set_velocity(Vector3.ZERO)
			anim_player.play("Monstr_attack_idle", 0.2, 1.0)
			
			if tactical_retreat_pause_timer <= 0:
				should_tactical_retreat = false
				is_in_tactical_retreat = false
				tactical_retreat_target = Vector3.ZERO
				enter_state(State.CHASE) # Возврат в погоню
			return
		
		return # Выход из _update_attack, пока идет отступление/пауза
	
	# Check if player still in range
	if not is_instance_valid(player):
		enter_state(State.CHASE)
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	# Player too far - chase
	if dist > attack_range * 1.5:
		enter_state(State.CHASE)
		return
	
	# Player in range - check cooldown and attack
	var time_now = Time.get_ticks_msec() / 1000.0
	if time_now - last_attack_time >= attack_cooldown:
		_execute_attack()
	else:
		# Wait for cooldown, stay still and face player
		anim_player.play("Monstr_attack_idle", 0.2, 1.0)
		nav_agent.set_velocity(Vector3.ZERO)

func _can_reach_player_again() -> bool:
	if not is_instance_valid(player):
		return false

	# Проверяем видимость
	if not _can_see_player():
		return false

	# Игрок достаточно близко (можно настроить порог)
	var dist = global_position.distance_to(player.global_position)
	if dist > lost_sight_range:
		return false

	# Навигация говорит, что путь есть
	nav_agent.target_position = player.global_position
	return not nav_agent.is_navigation_finished()

func _update_flee(_delta: float) -> void:
	# Move to a precomputed flee target (set when entering FLEE or on damage)
	if tactical_retreat_target != Vector3.ZERO:
		nav_agent.target_position = tactical_retreat_target
	else:
		# Fallback: pick a nearby random point away from player
		if is_instance_valid(player):
			var fallback_dir = (global_position - player.global_position).normalized()
			var candidate = global_position + fallback_dir * tactical_retreat_distance
			# try to snap to navmesh
			var nav_map = nav_agent.get_navigation_map()
			if nav_map:
				var valid_point = NavigationServer3D.map_get_closest_point(nav_map, candidate)
				if valid_point != Vector3.ZERO:
					nav_agent.target_position = valid_point
				else:
					nav_agent.target_position = candidate
			else:
				nav_agent.target_position = candidate

	# Move towards chosen flee target
	_move_toward_target()

	# Flee timer: when expired, return to chase if player visible nearby, else patrol
	state_timer -= _delta
	if state_timer <= 0:
		# Clear tactical_retreat_target so next time it's recomputed
		tactical_retreat_target = Vector3.ZERO
		# After flee duration, decide next state
		if time_since_player_seen <= chase_memory_duration and is_instance_valid(player) and global_position.distance_to(player.global_position) <= lost_sight_range:
			enter_state(State.CHASE)
		else:
			enter_state(State.PATROL)

func _update_knockback(_delta: float) -> void:
	move_and_slide()
	
	# Knockback finished
	if state_timer <= 0:
		var current_hp = health_component.get_health() if health_component else 0.0
		var max_health = health_component.get_max_health() if health_component else 10.0

		# Convert percent threshold to integer minimal HP
		var flee_hp_raw = max_health * flee_hp_threshold
		var flee_hp_limit = int(ceil(flee_hp_raw))

		if current_hp <= flee_hp_limit and will_flee:
			enter_state(State.FLEE)
		elif is_instance_valid(player) and global_position.distance_to(player.global_position) < 10.0:
			enter_state(State.CHASE)
		else:
			enter_state(State.PATROL)

# ============================================================================
# MOVEMENT HELPERS
# ============================================================================
func _move_toward_target() -> void:
	print("[MOVE] finished=", nav_agent.is_navigation_finished(),
	  " next_pos=", nav_agent.get_next_path_position())

	if nav_agent.is_navigation_finished():
		nav_agent.set_velocity(Vector3.ZERO)
		return
	
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	direction.y = 0
	nav_agent.set_velocity(direction * nav_agent.max_speed)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if current_state == State.KNOCKBACK or current_state == State.DEAD:
		return
	
	velocity.x = safe_velocity.x + external_push.x
	velocity.z = safe_velocity.z + external_push.z
	velocity.y = vertical_velocity
	
	move_and_slide()
	vertical_velocity = velocity.y
	external_push = external_push.lerp(Vector3.ZERO, 0.1)

# ============================================================================
# ROTATION
# ============================================================================
func _update_rotation(delta: float) -> void:
	# Lock rotation in certain states
	if current_state == State.KNOCKBACK:
		return
	if current_state == State.ATTACK and is_attacking:
		return
	if current_state == State.IDLE and is_looking_around:
		return # Handled in idle update
	
	var look_dir = Vector3.ZERO

	# During tactical retreat, always face movement direction (velocity)
	# to avoid jerky rotation between player and retreat direction.
	if is_in_tactical_retreat and velocity.length_squared() > 0.1:
		look_dir = velocity
	# In combat states prefer to face the player, but if we're actively
	# navigating around an obstacle (velocity direction differs significantly
	# from direct player direction) prefer facing along velocity while moving.
	elif is_instance_valid(player) and current_state in [State.CHASE, State.ATTACK, State.FRUSTRATED]:
		var player_dir = player.global_position - global_position
		player_dir.y = 0
		# If we're currently moving along a path (nav_agent has a target)
		# and our velocity direction is very different from the direct player
		# direction, face along velocity so the enemy looks like it's skirting
		# an obstacle. Otherwise face the player.
		if velocity.length_squared() > 0.1 and nav_agent and not nav_agent.is_navigation_finished():
			var vel_dir = velocity.normalized()
			var pd_norm = player_dir.normalized()
			var angle_diff = rad_to_deg(vel_dir.angle_to(pd_norm))
			if angle_diff > obstacle_face_angle_deg:
				look_dir = velocity
			else:
				look_dir = player_dir
		else:
			look_dir = player_dir
	elif velocity.length_squared() > 0.1:
		look_dir = velocity
	else:
		return
	
	look_dir.y = 0
	if look_dir.length() > 0.001:
		var target_angle = atan2(look_dir.x, look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)

# ============================================================================
# COMBAT
# ============================================================================
func get_next_attack() -> String:
	last_attack_index = (last_attack_index + 1) % monster_attacks.size()
	return monster_attacks[last_attack_index]

func _execute_attack() -> void:
	if is_attacking:
		return
	
	is_attacking = true
	anim_to_play = get_next_attack()
	# Apply a forward impulse while attacking so the monster advances into the
	# player instead of standing still. Use `attack_impulse` exported parameter.
	var forward = global_transform.basis.z.normalized()
	# Add forward push; nav_agent velocity is set to zero during attack so
	# external_push is applied by _on_velocity_computed and moves the enemy.
	external_push += forward * attack_impulse

	anim_player.play(anim_to_play, 0.2, attack_speed)
	await anim_player.animation_finished

	# Clear the temporary attack push so enemy doesn't keep sliding after attack
	external_push = external_push.lerp(Vector3.ZERO, 1.0)
	is_attacking = false
	
	# Record attack time
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	# Chance to do tactical retreat
	if randf() < tactical_retreat_chance:
		if is_instance_valid(player):
			# Compute a fixed retreat target now so it doesn't chase the player
			var retreat_dir = (global_position - player.global_position).normalized()
			# Place target at a distance from current pos in retreat_dir
			# Use tactical_retreat_distance as offset from current position
			tactical_retreat_target = global_position + retreat_dir * tactical_retreat_distance
		else:
			tactical_retreat_target = global_position
		should_tactical_retreat = true
		tactical_retreat_pause_timer = 0.0 # Will be set when reaching position

func take_damage(amount: float, knockback_force: Vector3) -> void:
	if current_state == State.DEAD:
		return
	vfx_pull.spawn_effect(0, self.global_position + Vector3(0, 1.5, 0))
	print("Monster received damage:", amount)
	
	$HitFlash.flash()
	
	# Delegate to HealthComponent
	if health_component:
		health_component.take_damage(amount)
	
	# CRITICAL FIX: If we died during take_damage, abort immediately to prevent overwriting DEAD state
	if current_state == State.DEAD:
		return
	
	# Death is handled by signal from HealthComponent
	
	# Apply knockback only if force is sufficient
	if knockback_force.length() > 0.1:
		velocity += knockback_force
		# Short stun/knockback state
		enter_state(State.KNOCKBACK)

	# Flee logic update: Check against component health
	var current_hp = health_component.get_health() if health_component else 0.0
	var max_health = health_component.get_max_health() if health_component else 10.0

	# Reset damage timer used for passive healing
	time_since_last_damaged = 0.0

	# If health below threshold and we have flee charges, enter FLEE
	if current_hp <= max_health * flee_hp_threshold and current_flee_charges > 0 and will_flee:
		# Choose a flee target that is not relative to the player: sample random directions
		var chosen = Vector3.ZERO
		var nav_map = nav_agent.get_navigation_map()
		for i in range(12):
			var ang = randf() * TAU
			var dir = Vector3(cos(ang), 0, sin(ang))
			var candidate = global_position + dir * tactical_retreat_distance
			if nav_map:
				var valid_point = NavigationServer3D.map_get_closest_point(nav_map, candidate)
				if valid_point != Vector3.ZERO:
					chosen = valid_point
					break
			else:
				chosen = candidate
				break
		# Fallback if nothing found
		if chosen == Vector3.ZERO:
			chosen = global_position + Vector3(0,0, tactical_retreat_distance)

		tactical_retreat_target = chosen
		enter_state(State.FLEE)
		current_flee_charges = max(current_flee_charges - 1, 0)
		return
	else:
		# do nothing special; tactical retreat remains managed by attack flow
		should_tactical_retreat = should_tactical_retreat

func receive_push(push: Vector3) -> void:
	external_push += push

# ============================================================================
# UI UPDATES
# ============================================================================
func _on_health_changed(_new_health: float) -> void:
	if not health_component:
		return
	# обновляем нормализованное здоровье
	health = clamp(health_component.get_health() / health_component.get_max_health(), 0.0, 1.0)
	# при получении урона бар проявляется полностью
	health_bar_timer = health_bar_visible_time
	health_bar_opacity = 1.0
	_update_health_bar_visuals(health, delayed_health, health_bar_opacity)

func _update_health_bar_process(delta: float) -> void:
	if not health_bar_mesh or not health_component or not health_bar_enabled:
		return

	# плавное уменьшение delayed_health
	delayed_health = lerp(delayed_health, health, delta * 4.0)

	if health_bar_timer > 0.0:
		health_bar_timer -= delta
	else:
		if health_component.get_health() <= 0:
			# враг умер — полностью скрываем
			health_bar_opacity = lerp(health_bar_opacity, 0.0, delta * health_bar_fade_speed)
			if health_bar_opacity < 0.01:
				health_bar_opacity = 0.0
		else:
			# бар активен только после первого удара
			if health_bar_opacity > 0.0:
				health_bar_opacity = lerp(health_bar_opacity, 0.5, delta * health_bar_fade_speed)

	_update_health_bar_visuals(health, delayed_health, health_bar_opacity)


func calculate_walk_run_blend(speed: float) -> float:
	# Map speed to 0..1 between start and end thresholds
	var blend = inverse_lerp(walk_run_blend_start_speed, walk_run_blend_end_speed, speed)
	return clamp(blend, 0.0, 1.0)


func enemy_animation_update(delta: float) -> void:
	# Avoid overriding attack/knockback/death animations
	if is_attacking or current_state == State.KNOCKBACK or current_state == State.DEAD:
		return
	# If looking around in idle, let idle animation play
	if current_state == State.IDLE and is_looking_around:
		return
	# During tactical retreat pause, let explicit animation play
	if should_tactical_retreat and tactical_retreat_pause_timer > 0:
		return

	# Determine horizontal speed
	var speed_2d := Vector2(velocity.x, velocity.z).length()
	var has_movement := speed_2d > 0.1

	# Calculate target blend based on current horizontal speed
	target_movement_blend = calculate_walk_run_blend(speed_2d)
	current_movement_blend = lerp(current_movement_blend, target_movement_blend, walk_run_blend_smoothing * delta)

	# Choose animation based on blend
	if has_movement and current_movement_blend < 0.5:
		# Play walk with speed scale relative to walk_speed
		var walk_speed_scale = 1.0
		if walk_speed > 0:
			walk_speed_scale = clamp(speed_2d / walk_speed, 0.5, 1.5)
		play_with_random_offset("Monstr_walk", 0.2, walk_speed_scale)
	elif has_movement and current_movement_blend >= 0.5:
		# Play run with speed scale relative to run_speed
		var run_speed_scale = 1.0
		if run_speed > 0:
			run_speed_scale = clamp(speed_2d / run_speed, 0.5, 1.5)
		# Use same helper to avoid restarting if already playing
		play_with_random_offset("Monstr_run", 0.2, run_speed_scale)
	else:
		# No meaningful movement -> keep idle (don't restart idle if already playing)
		if anim_player.current_animation != "Monstr_idle":
			play_with_random_offset("Monstr_idle", 0.2, 1.0)



func _update_health_bar_visuals(current_hp: float, delayed_hp: float, opacity_val: float) -> void:
	if not health_bar_mesh or not health_component:
		return

	health_bar_mesh.set_instance_shader_parameter("health", current_hp)       # зелёная
	health_bar_mesh.set_instance_shader_parameter("delayed_health", delayed_hp) # красная
	health_bar_mesh.set_instance_shader_parameter("opacity", opacity_val)

# ============================================================================
# DETECTION
# ============================================================================
func _can_see_player() -> bool:
	if not is_instance_valid(player):
		return false
	
	var dist = global_position.distance_to(player.global_position)
	
	# 1. Absolute Range Check
	if dist > sight_range:
		return false
	
	# 2. Field of View (FOV) & Proximity Check
	# If player is within proximity range, they are detected 360 degrees (blind spot mitigation)
	# Otherwise, we check the view angle.
	var in_proximity = dist <= proximity_detection_range
	
	if not in_proximity:
		var direction_to_player = (player.global_position - global_position).normalized()
		# Assuming standard forward is -Z in local space, transformed to global
		# Or simplified: use the enemy's current forward vector.
		# Godot default forward is -Z.
		var forward_vector = global_transform.basis.z
		
		# Calculate angle
		var angle_to_player = rad_to_deg(forward_vector.angle_to(direction_to_player))
		
		# If angle is outside half of the FOV, we can't see them
		if angle_to_player > sight_angle / 2.0:
			return false

	# 3. Physical Line of Sight (Raycast)
	# Even if close or in angle, walls should block vision.
	var space_state = get_world_3d().direct_space_state
	
	var origin_pos = global_position + Vector3(0, eye_height_offset, 0)
	var target_pos = player.global_position + Vector3(0, player_height_offset, 0)
	
	var query = PhysicsRayQueryParameters3D.create(origin_pos, target_pos)
	query.exclude = [self] # Don't hit self
	# query.collision_mask = 1 # Optional: Define vision layers if needed
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider == player:
			if debug_vision:
				print("Player Seen! Dist: %.1f" % dist)
			return true
		else:
			if debug_vision:
				# Use a timer or frame counter to avoid spam if needed, or just print occasionally
				print("Vision blocked by: ", result.collider.name)
			return false
	
	return false

# ============================================================================
# STUCK DETECTION
# ============================================================================
func _update_stuck_detection(delta: float) -> void:
	# Don't check when idle or attacking
	if current_state in [State.IDLE, State.ATTACK, State.KNOCKBACK]:
		time_stuck = 0.0
		return
	
	# Check if actually moving
	if velocity.length_squared() < 0.1:
		time_stuck += delta
	else:
		time_stuck = 0.0

# ============================================================================
# PATROL
# ============================================================================
func _set_random_patrol_target() -> void:
	if not patrol_zone:
		return
	
	var shape: CollisionShape3D = patrol_zone.get_node("CollisionShape3D")
	if not shape or not shape.shape is BoxShape3D:
		return
	
	var extents = shape.shape.extents
	var box_center = shape.global_transform.origin # центр бокса в мире

	for i in range(10):
		var random_offset = Vector3(
			randf_range(-extents.x, extents.x),
			0,
			randf_range(-extents.z, extents.z)
		)

		var candidate = box_center + random_offset
		var nav_map = nav_agent.get_navigation_map()
		var valid_point = NavigationServer3D.map_get_closest_point(nav_map, candidate)

		# ---- ГЛОБАЛЬНАЯ проверка границ ----
		var min_x = box_center.x - extents.x
		var max_x = box_center.x + extents.x
		var min_z = box_center.z - extents.z
		var max_z = box_center.z + extents.z

		if valid_point.x < min_x or valid_point.x > max_x:
			continue
		if valid_point.z < min_z or valid_point.z > max_z:
			continue

		# точка валидная
		nav_agent.target_position = valid_point
		return

# ============================================================================
# ANIMATION HELPER
# ============================================================================
func play_with_random_offset(anim_name: String, blend: float = -1.0, speed: float = 1.0) -> void:
	if anim_player.current_animation == anim_name:
		anim_player.play(anim_name, blend, speed)
		return

	anim_player.play(anim_name, blend, speed)
	var anim_len = anim_player.current_animation_length
	if anim_len > 0:
		anim_player.seek(randf() * anim_len)

# ============================================================================
# DEBUG VISUALIZATION
# ============================================================================
func _setup_debug_meshes() -> void:
	# 1. Sight Range Sphere (Yellow)
	debug_sight_mesh = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.1) # Transparent Yellow
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # See from inside
	sphere_mesh.material = mat
	debug_sight_mesh.mesh = sphere_mesh
	add_child(debug_sight_mesh)
	
	# 2. Proximity Range Sphere (Red)
	debug_proximity_mesh = MeshInstance3D.new()
	var prox_mesh = SphereMesh.new()
	var prox_mat = StandardMaterial3D.new()
	prox_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.5) # Transparent Red
	prox_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	prox_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	prox_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	prox_mesh.material = prox_mat
	debug_proximity_mesh.mesh = prox_mesh
	add_child(debug_proximity_mesh)

func _update_debug_meshes() -> void:
	if debug_sight_mesh:
		debug_sight_mesh.scale = Vector3(sight_range * 2, sight_range * 2, sight_range * 2)

	if debug_proximity_mesh:
		debug_proximity_mesh.scale = Vector3(proximity_detection_range * 2, proximity_detection_range * 2, proximity_detection_range * 2)

# ============================================================================
# DEATH & CLEANUP
# ============================================================================
func die() -> void:
	# Отключаем и прячем хп-бар сразу
	emit_signal("died")
	health_bar_enabled = false
	if health_bar_mesh:
		health_bar_mesh.visible = false
		# на случай, если шейдер читает opacity
		health_bar_opacity = 0.0
		health_bar_mesh.set_instance_shader_parameter("opacity", 0.0)

	if current_state == State.DEAD:
		return

	current_state = State.DEAD

	# Остановка движения/AI
	nav_agent.max_speed = 0.0
	nav_agent.avoidance_enabled = false
	velocity = Vector3.ZERO

	# Отключаем только физику (AI/движение), но не _process
	set_physics_process(false)
	set_process(true)

	# Отключаем коллизии с игроком
	collision_layer = 0

	if punch_hand_r:
		punch_hand_r.set_deferred("monitoring", false)
	if punch_hand_l:
		punch_hand_l.set_deferred("monitoring", false)

	# Анимация смерти
	anim_player.play("Monstr_death", 0.2, 0.7)
	await anim_player.animation_finished

	# Немного подержать труп
	await get_tree().create_timer(2.0).timeout

	# Исчезновение модели врага
	
	fade_out_and_remove()


func fade_out_and_remove() -> void:
	# Find all MeshInstance3D nodes to dissolve them
	var meshes_to_fade: Array[MeshInstance3D] = []
	var materials_to_fade: Array[ShaderMaterial] = []
	
	var stack = [self]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is MeshInstance3D:
			# Filter out debug meshes
			if node != debug_sight_mesh and node != debug_proximity_mesh:
				meshes_to_fade.append(node)
		stack.append_array(node.get_children())
	
	# Prepare materials
	for mesh_instance in meshes_to_fade:
		var mat = mesh_instance.get_active_material(0)
		if mat is ShaderMaterial:
			# Duplicate to avoid shared resource issues during fade
			var new_mat = mat.duplicate()
			mesh_instance.set_surface_override_material(0, new_mat)
			materials_to_fade.append(new_mat)
	
	if materials_to_fade.size() > 0:
		var t = 0.0
		var fade_speed = 0.5
		while t < 1.0:
			t += get_process_delta_time() * fade_speed
			for mat in materials_to_fade:
				mat.set_shader_parameter("dissolve_amount", t)
			await get_tree().process_frame
			
	
	queue_free()


func _debug_ai_log() -> void:
	# Основной слип в одну строку — легко копировать в чат
	var s := "[AI DEBUG] state=%s pos=%.2f,%.2f,%.2f hp=%.2f/%s time_stuck=%.2f last_dist=%.2f frustr_total=%.2f frustr_cd=%.2f state_timer=%.2f target_pos=%.2f,%.2f,%.2f player_seen=%.2f" % [
		str(current_state),
		global_position.x, global_position.y, global_position.z,
		health, (health_component.get_max_health() if is_instance_valid(health_component) else "N/A"),
		time_stuck, last_dist_to_target, frustration_total_time, frustrated_cooldown, state_timer,
		(nav_agent.target_position.x if nav_agent else 0.0),
		(nav_agent.target_position.y if nav_agent else 0.0),
		(nav_agent.target_position.z if nav_agent else 0.0),
		time_since_player_seen
	]
	print(s)

	# Дополнительные полезные данные (каждая на новой строке)
	print("    velocity_len=%.2f nav_finished=%s player_valid=%s player_visible=%s is_attacking=%s is_in_tactical_retreat=%s" % [
		velocity.length(),
		str(nav_agent.is_navigation_finished()),
		str(is_instance_valid(player)),
		str(_can_see_player()),
		str(is_attacking),
		str(is_in_tactical_retreat)
	])

	# Если хочешь видеть путь агента — распечатать следующий путь/позицию
	var next = Vector3.ZERO
	if nav_agent and not nav_agent.is_navigation_finished():
		next = nav_agent.get_next_path_position()
	print("    next_path_pos=%.2f, %.2f, %.2f" % [next.x, next.y, next.z])
