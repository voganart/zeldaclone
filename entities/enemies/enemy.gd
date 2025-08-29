extends CharacterBody3D

# Новые переменные для системы состояний и атаки
enum State { PATROL, CHASE, ATTACK, IDLE, KNOCKBACK }

@export var hp: float = 10
@export var knockback_time: float = 0.0
@export var gravity: int = 100
@export var knockback_strength: float = 2.0
@export var knockback_height: float = 5.0
@export var walk_speed: float = 1.5
@export var run_speed: float = 3.5
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var tactical_retreat_distance: float = 3.0
@export var attack_animation_speed: float = 1.0
@export var idle_chance: float = 0.3
@export var _chase_distance: float = 10.0
@export var _lost_chase_distance: float = 15.0
@export var chase_timeout: float = 7.0 # ⚠️ НОВАЯ ПЕРЕМЕННАЯ: время, в течение которого враг будет преследовать после потери видимости
@export var stuck_threshold: float = 0.5 # ⚠️ НОВАЯ ПЕРЕМЕННАЯ: время, через которое враг считается застрявшим
@export var idle_cooldown = randf_range(1.5, 5.0)

@onready var patrol_zone: Area3D = get_parent() as Area3D
@onready var agent: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_timer: Timer = $AttackTimer
var external_push: Vector3 = Vector3.ZERO

@onready var line_of_sight_cast: ShapeCast3D = $LineOfSightCast
@export var sight_range: float = 15.0

var current_state: State = State.PATROL
var last_attack_time: float = -100.0
var retreating: bool = false
var current_vertical_velocity: float = 0.0
var time_since_last_seen_player: float = 0.0
var nav_map_ready: bool = false
var time_stuck: float = 0.0 # ⚠️ НОВАЯ ПЕРЕМЕННАЯ: счетчик времени застревания


func _ready() -> void:
	agent.max_speed = walk_speed
	NavigationServer3D.map_changed.connect(_on_navmesh_ready)
	agent.avoidance_enabled = true
	agent.velocity_computed.connect(Callable(self, "_on_velocity_computed"))
	attack_timer.timeout.connect(_on_attack_cooldown_finished)

func _on_navmesh_ready(_map_rid):
	if is_inside_tree():
		nav_map_ready = true
		_set_random_patrol_target()
		
func receive_push(push: Vector3):
	external_push += push
	
func _on_velocity_computed(safe_velocity: Vector3):
	if current_state == State.KNOCKBACK:
		move_and_slide()
		return

	velocity.x = safe_velocity.x + external_push.x
	velocity.z = safe_velocity.z + external_push.z
	velocity.y = current_vertical_velocity
	
	move_and_slide()
	current_vertical_velocity = velocity.y
	external_push = external_push.lerp(Vector3.ZERO, 0.1)

func take_damage(amount, knockback_dir: Vector3):
	hp -= amount
	var final_knockback = knockback_dir.normalized() * knockback_strength
	final_knockback.y = knockback_height

	velocity = final_knockback
	knockback_time = 0.3
	set_state(State.KNOCKBACK)
	
	if current_state != State.CHASE and current_state != State.ATTACK:
		set_state(State.CHASE)
	
	if hp <= 0:
		queue_free()

func _can_see_player() -> bool:
	if not is_instance_valid(player):
		return false
	
	if global_position.distance_to(player.global_position) > _chase_distance:
		return false
	
	line_of_sight_cast.target_position = to_local(player.global_position)
	line_of_sight_cast.force_shapecast_update()

	if line_of_sight_cast.is_colliding():
		var collider = line_of_sight_cast.get_collider(0)
		if collider == player:
			return true
		else:
			return false
			
	return false

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	current_vertical_velocity = velocity.y

	if not nav_map_ready:
		return
	
	var player_is_visible = _can_see_player()
	if player_is_visible:
		time_since_last_seen_player = 0
	else:
		time_since_last_seen_player += delta
		
	# ⚠️ НОВАЯ ЛОГИКА: Проверка на застревание
	if agent.velocity.length_squared() < 0.01:
		time_stuck += delta
	else:
		time_stuck = 0.0
		
	match current_state:
		State.KNOCKBACK:
			knockback_time -= delta
			if knockback_time <= 0:
				if is_instance_valid(player) and global_position.distance_to(player.global_position) < 10.0:
					set_state(State.CHASE)
				else:
					set_state(State.PATROL)
			return

		State.IDLE:
			agent.set_velocity(Vector3.ZERO)
			if player_is_visible:
				set_state(State.CHASE)
			return

		State.PATROL:
			if player_is_visible:
				set_state(State.CHASE)
				return

			if agent.is_navigation_finished():
				if randf() < idle_chance:
					set_state(State.IDLE)
					_start_idle()
				else:
					_set_random_patrol_target()
			var next_pos: Vector3 = agent.get_next_path_position()
			var dir = (next_pos - global_position).normalized()
			dir.y = 0
			agent.set_velocity(dir * agent.max_speed)

		State.CHASE:
			# ⚠️ НОВАЯ ЛОГИКА: если игрок в зоне атаки и таймер атаки готов, переходим в ATTACK
			if is_instance_valid(player) and global_position.distance_to(player.global_position) <= attack_range:
				# Проверяем, прошло ли достаточно времени с последней атаки
				if (Time.get_ticks_msec() / 1000.0) - last_attack_time >= attack_cooldown:
					_start_attack()
					set_state(State.ATTACK)
			
			# Возвращаемся в патрулирование, если игрок слишком далеко или потерян
			if global_position.distance_to(player.global_position) > _lost_chase_distance or time_since_last_seen_player > chase_timeout:
				set_state(State.PATROL)
				return
				
			if time_stuck > stuck_threshold:
				time_stuck = 0.0
				pass
			else:
				agent.target_position = player.global_position

			var next_pos: Vector3 = agent.get_next_path_position()
			var dir = (next_pos - global_position).normalized()
			dir.y = 0
			agent.set_velocity(dir * agent.max_speed)

		State.ATTACK:
			if retreating:
				if is_instance_valid(player):
					var retreat_pos = player.global_position + (global_position - player.global_position).normalized() * tactical_retreat_distance
					agent.target_position = retreat_pos
				if agent.is_navigation_finished():
					retreating = false
					set_state(State.CHASE)
			else:
				agent.set_velocity(Vector3.ZERO)
	
	# ⚠️ НОВАЯ ЛОГИКА: Поворот должен всегда следовать за игроком в состоянии CHASE и ATTACK.
	var look_dir = Vector3.ZERO
	if is_instance_valid(player) and (current_state == State.CHASE or current_state == State.ATTACK):
		look_dir = player.global_position - global_position
	else:
		look_dir = velocity

	look_dir.y = 0
	if look_dir.length() > 0.001:
		var target_angle = atan2(look_dir.x, look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * 6.0)

func _start_attack():
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= attack_range + 0.5:
		last_attack_time = Time.get_ticks_msec() / 1000.0
	retreating = true
func _on_attack_cooldown_finished():
	set_state(State.CHASE)

func _start_idle() -> void:
	
	await get_tree().create_timer(idle_cooldown).timeout
	if current_state == State.IDLE:
		set_state(State.PATROL)

func set_state(new_state: State):
	current_state = new_state
	match current_state:
		State.PATROL:
			agent.max_speed = walk_speed
		State.CHASE:
			agent.max_speed = run_speed
		State.ATTACK:
			pass
		State.IDLE:
			pass
		State.KNOCKBACK:
			pass
			
func _set_random_patrol_target():
	if not patrol_zone:
		return
	var shape: CollisionShape3D = patrol_zone.get_node("CollisionShape3D")
	if shape and shape.shape is BoxShape3D:
		var extents = shape.shape.extents
		var origin = patrol_zone.global_transform.origin

		for i in range(10):
			var random_offset = Vector3(randf_range(-extents.x, extents.x), 0, randf_range(-extents.z, extents.z))
			var candidate = origin + random_offset
			var nav_map = agent.get_navigation_map()
			var valid_point = NavigationServer3D.map_get_closest_point(nav_map, candidate)
			
			if valid_point != Vector3.ZERO:
				agent.target_position = valid_point
				return
