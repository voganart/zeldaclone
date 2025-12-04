extends CharacterBody3D

## ============================================================================
## ENEMY AI - Refactored for Robustness & Maintainability
## ============================================================================

# ============================================================================
# ENUMS & CONSTANTS
# ============================================================================
enum State {IDLE, PATROL, CHASE, FRUSTRATED, ATTACK, FLEE, KNOCKBACK}

# ============================================================================
# EXPORTS - Grouped for Designer UX
# ============================================================================
@export_group("Health & Damage")
@export var max_hp: float = 10.0
@export var flee_hp_threshold: float = 0.3 # Flee when HP < 30%
@export var flee_chance: float = 0.5 # 50% chance to flee

@export_group("Movement")
@export var walk_speed: float = 1.5
@export var run_speed: float = 3.5
@export var rotation_speed: float = 6.0

@export_group("Combat")
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var tactical_retreat_chance: float = 0.3 # 30% chance to retreat after attack
@export var tactical_retreat_distance: float = 4.0
@export var tactical_retreat_pause_min: float = 0.5
@export var tactical_retreat_pause_max: float = 1.5

@export_group("Detection")
@export var sight_range: float = 10.0
@export var lost_sight_range: float = 15.0
@export var chase_memory_duration: float = 7.0 # Remember player position

@export_group("Behavior Timers")
@export var idle_duration_min: float = 3.0
@export var idle_duration_max: float = 7.0
@export var idle_chance: float = 0.8 # 80% chance to idle after patrol
@export var frustration_duration: float = 3.0 # Time before getting frustrated
@export var give_up_duration: float = 5.0 # Total time before giving up

@export_group("Physics")
@export var gravity: float = 100.0
@export var knockback_strength: float = 2.0
@export var knockback_height: float = 5.0
@export var knockback_duration: float = 0.5
@export var stuck_threshold: float = 0.5 # Time before considered stuck

# ============================================================================
# STATE VARIABLES
# ============================================================================
var current_state: State = State.IDLE
var state_timer: float = 0.0 # Robust timer for state durations

# ============================================================================
# RUNTIME VARIABLES
# ============================================================================
var hp: float
var will_flee: bool = false
var last_known_player_pos: Vector3 = Vector3.ZERO
var time_since_player_seen: float = 0.0
var last_attack_time: float = -999.0
var time_stuck: float = 0.0

# Attack state
var is_attacking: bool = false
var should_tactical_retreat: bool = false
var tactical_retreat_pause_timer: float = 0.0

# Idle state
var idle_look_timer: float = 0.0
var idle_target_angle: float = 0.0
var is_looking_around: bool = false

# Physics
var vertical_velocity: float = 0.0
var external_push: Vector3 = Vector3.ZERO

# Navigation
var nav_ready: bool = false

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var patrol_zone: Area3D = get_parent() as Area3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var anim_player: AnimationPlayer = $Monstr/AnimationPlayer
@onready var los_cast: ShapeCast3D = $LineOfSightCast

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	hp = max_hp
	will_flee = randf() < flee_chance
	
	# Setup navigation
	nav_agent.max_speed = walk_speed
	nav_agent.avoidance_enabled = true
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	
	# Wait for navmesh
	NavigationServer3D.map_changed.connect(_on_navmesh_ready)

func _on_navmesh_ready(_map_rid) -> void:
	if is_inside_tree():
		nav_ready = true
		enter_state(State.PATROL)

# ============================================================================
# MAIN LOOP
# ============================================================================
func _physics_process(delta: float) -> void:
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
	
	# Detect stuck
	_update_stuck_detection(delta)
	
	# Update current state
	state_timer -= delta
	_update_state(delta, player_visible)
	
	# Handle rotation
	_update_rotation(delta)

# ============================================================================
# STATE MACHINE - Enter/Update/Exit Pattern
# ============================================================================
func enter_state(new_state: State) -> void:
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
			anim_player.play("Monstr_idle")
			state_timer = randf_range(idle_duration_min, idle_duration_max)
			idle_look_timer = randf_range(1.5, 4.0)
			
		State.PATROL:
			nav_agent.max_speed = walk_speed
			anim_player.play("Monstr_walk")
			_set_random_patrol_target()
			
		State.CHASE:
			nav_agent.max_speed = run_speed
			anim_player.play("Monstr_walk")
			state_timer = 0.0 # Track chase duration
			
		State.FRUSTRATED:
			nav_agent.max_speed = 0.0
			anim_player.play("Monstr_angry")
			
		State.ATTACK:
			nav_agent.max_speed = 0.0
			# Don't auto-execute, let update handle it
			
		State.FLEE:
			nav_agent.max_speed = run_speed * 1.2
			anim_player.play("Monstr_walk")
			
		State.KNOCKBACK:
			anim_player.play("Monstr_knockdown")
			state_timer = knockback_duration

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
	# Spot player
	if player_visible:
		enter_state(State.CHASE)
		return
	
	# Reached destination
	if nav_agent.is_navigation_finished():
		if randf() < idle_chance:
			enter_state(State.IDLE)
		else:
			_set_random_patrol_target()
		return
	
	# Stuck recovery
	if time_stuck > stuck_threshold:
		time_stuck = 0.0
		_set_random_patrol_target()
		return
	
	# Move toward target
	_move_toward_target()

func _update_chase(delta: float, player_visible: bool) -> void:
	state_timer += delta
	
	# Проверка на валидность игрока
	if not is_instance_valid(player):
		enter_state(State.PATROL)
		return

	# Update last known position
	if player_visible:
		last_known_player_pos = player.global_position
	
	var dist_to_player = global_position.distance_to(player.global_position)
	var time_now = Time.get_ticks_msec() / 1000.0

	# 1. Проверка на Атаку / Кружение (Attack or Orbit)
	if dist_to_player <= attack_range:
		if time_now - last_attack_time >= attack_cooldown:
			# Атака готова, переходим в ATTACK
			enter_state(State.ATTACK)
			return
		else:
			# ⚠️ ЛОГИКА КРУЖЕНИЯ: На кулдауне, кружим вокруг игрока.
			# Направление от врага к игроку
			var player_dir = (player.global_position - global_position).normalized()
			
			# Вычисляем направление, перпендикулярное направлению на игрока (орбитальное движение)
			# Используем Vector3(player_dir.z, 0, -player_dir.x) для движения вправо,
			# или Vector3(-player_dir.z, 0, player_dir.x) для движения влево.
			# Чередование направления или случайный выбор может добавить разнообразия.
			var orbit_dir = Vector3(player_dir.z, 0, -player_dir.x)
			
			# Устанавливаем цель на небольшом расстоянии в направлении орбиты
			nav_agent.max_speed = walk_speed * 0.7 # Немного замедляем для маневра
			var orbit_target = global_position + orbit_dir * attack_range * 0.5
			
			# Устанавливаем целевую позицию агенту, чтобы он искал путь в сторону
			nav_agent.target_position = orbit_target
			
			_move_toward_target()
			anim_player.play("Monstr_walk")
			return # Выход, так как движение уже обработано

	# 2. Проверка на Потерю Игрока / Отступление (Lost Player)
	if dist_to_player > lost_sight_range or time_since_player_seen > chase_memory_duration:
		# Если игрок вне зоны погони или потерян слишком долго,
		# пытаемся исследовать последнее известное местоположение.
		if last_known_player_pos != Vector3.ZERO and global_position.distance_to(last_known_player_pos) > 2.0:
			nav_agent.target_position = last_known_player_pos
		else:
			# Расследование завершено или нет информации
			enter_state(State.PATROL)
			return

	# 3. Проверка на Застревание (Stuck Recovery)
	if time_stuck > stuck_threshold:
		time_stuck = 0.0
		# Вместо немедленного патрулирования можно попытаться сбросить цель и вернуться в погоню
		# Для простоты вернемся в PATROL, как было.
		enter_state(State.PATROL)
		return
		
	# 4. Проверка на Фрустрацию (Frustration check)
	# Этот таймер будет сбрасываться каждый раз, когда враг атакует или теряет игрока.
	if state_timer > frustration_duration:
		enter_state(State.FRUSTRATED)
		return

	# 5. Движение Погони (Standard Chase Movement)
	# Если не кружим и не потеряли игрока, продолжаем двигаться к его текущему положению.
	if is_instance_valid(player):
		nav_agent.target_position = player.global_position
		nav_agent.max_speed = run_speed # Возвращаем скорость бега
		_move_toward_target()

func _update_frustrated(delta: float) -> void:
	state_timer += delta
	nav_agent.set_velocity(Vector3.ZERO)
	
	# Player came close - attack!
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= attack_range:
		enter_state(State.ATTACK)
		return
	
	# Give up
	if state_timer > give_up_duration:
		enter_state(State.PATROL)

func _update_attack(delta: float) -> void:
	# Wait for attack animation
	if is_attacking:
		nav_agent.set_velocity(Vector3.ZERO)
		return
	
	# Tactical retreat phase
	if should_tactical_retreat:
		nav_agent.max_speed = run_speed * 1.5 # ⚠️ КОНТРОЛЬ СКОРОСТИ: Используем большую скорость!
		
		# Расчет цели отступления: точка, удаленная от игрока
		if is_instance_valid(player):
			var retreat_dir = (global_position - player.global_position).normalized()
			var retreat_pos = player.global_position + retreat_dir * tactical_retreat_distance
			
			# Устанавливаем цель навигации
			nav_agent.target_position = retreat_pos
			
		# Двигаемся к цели отступления
		_move_toward_target()
		
		# ⚠️ АНИМАЦИЯ: Включаем анимацию ходьбы/бега
		anim_player.play("Monstr_walk")

		# Проверка, достигнута ли цель отступления
		if nav_agent.is_navigation_finished() and tactical_retreat_pause_timer <= 0:
			# Пауза в точке отступления
			nav_agent.set_velocity(Vector3.ZERO)
			anim_player.play("Monstr_idle")
			tactical_retreat_pause_timer = randf_range(tactical_retreat_pause_min, tactical_retreat_pause_max)

		# Пауза в точке отступления
		if tactical_retreat_pause_timer > 0:
			tactical_retreat_pause_timer -= delta
			nav_agent.set_velocity(Vector3.ZERO)
			anim_player.play("Monstr_idle")
			
			if tactical_retreat_pause_timer <= 0:
				should_tactical_retreat = false
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
		nav_agent.set_velocity(Vector3.ZERO)

func _update_flee(_delta: float) -> void:
	# Calculate flee position
	if is_instance_valid(player):
		var flee_dir = (global_position - player.global_position).normalized()
		var flee_pos = global_position + flee_dir * 10.0
		nav_agent.target_position = flee_pos
	
	# Safe - return to patrol
	if time_since_player_seen > 5.0:
		enter_state(State.PATROL)
		return
	
	_move_toward_target()

func _update_knockback(_delta: float) -> void:
	move_and_slide()
	
	# Knockback finished
	if state_timer <= 0:
		# Decide next state based on HP
		if hp < max_hp * flee_hp_threshold and will_flee:
			enter_state(State.FLEE)
		elif is_instance_valid(player) and global_position.distance_to(player.global_position) < 10.0:
			enter_state(State.CHASE)
		else:
			enter_state(State.PATROL)

# ============================================================================
# MOVEMENT HELPERS
# ============================================================================
func _move_toward_target() -> void:
	if nav_agent.is_navigation_finished():
		nav_agent.set_velocity(Vector3.ZERO)
		return
	
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	direction.y = 0
	nav_agent.set_velocity(direction * nav_agent.max_speed)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if current_state == State.KNOCKBACK:
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
	
	# Face movement direction when moving
	if velocity.length_squared() > 0.1:
		look_dir = velocity
	# Face player when stationary in combat states
	elif is_instance_valid(player) and current_state in [State.CHASE, State.ATTACK, State.FRUSTRATED]:
		look_dir = player.global_position - global_position
	else:
		return
	
	look_dir.y = 0
	if look_dir.length() > 0.001:
		var target_angle = atan2(look_dir.x, look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)

# ============================================================================
# COMBAT
# ============================================================================
func _execute_attack() -> void:
	if is_attacking:
		return
	
	is_attacking = true
	anim_player.play("Monstr_attack_1", 0.2)
	await anim_player.animation_finished
	is_attacking = false
	
	# Record attack time
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	# Chance to do tactical retreat
	if randf() < tactical_retreat_chance:
		should_tactical_retreat = true
		tactical_retreat_pause_timer = 0.0 # Will be set when reaching position

func take_damage(amount: float, knockback_dir: Vector3) -> void:
	hp -= amount
	
	# Apply knockback
	var final_knockback = knockback_dir.normalized() * knockback_strength
	final_knockback.y = knockback_height
	velocity = final_knockback
	
	enter_state(State.KNOCKBACK)
	
	# Death
	if hp <= 0:
		queue_free()

func receive_push(push: Vector3) -> void:
	external_push += push

# ============================================================================
# DETECTION
# ============================================================================
func _can_see_player() -> bool:
	if not is_instance_valid(player):
		return false
	
	var dist = global_position.distance_to(player.global_position)
	if dist > sight_range:
		return false
	
	los_cast.target_position = to_local(player.global_position)
	los_cast.force_shapecast_update()
	
	if los_cast.is_colliding():
		var collider = los_cast.get_collider(0)
		return collider == player
	
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
	var origin = patrol_zone.global_transform.origin
	
	# Try 10 times to find valid point
	for i in range(10):
		var random_offset = Vector3(
			randf_range(-extents.x, extents.x),
			0,
			randf_range(-extents.z, extents.z)
		)
		var candidate = origin + random_offset
		var nav_map = nav_agent.get_navigation_map()
		var valid_point = NavigationServer3D.map_get_closest_point(nav_map, candidate)
		
		if valid_point != Vector3.ZERO:
			nav_agent.target_position = valid_point
			return
