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


@onready var patrol_zone: Area3D = get_parent() as Area3D
@onready var agent: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var anim_player: AnimationPlayer = $AnimationPlayer # Предполагаем, что у вас есть AnimationPlayer
@onready var attack_timer: Timer = $AttackTimer # Добавьте этот узел в сцену
var external_push: Vector3 = Vector3.ZERO

var current_state: State = State.PATROL
var last_attack_time: float = -100.0
var retreating: bool = false
var current_vertical_velocity: float = 0.0
# Флаг для отслеживания готовности карты
var nav_map_ready: bool = false

func _ready() -> void:
	agent.max_speed = walk_speed
	# ⚠️ Правильно: подключаемся к сигналу.
	NavigationServer3D.map_changed.connect(_on_navmesh_ready)
	# Включаем систему избегания и подключаем сигнал
	agent.avoidance_enabled = true
	agent.velocity_computed.connect(Callable(self, "_on_velocity_computed"))
	attack_timer.timeout.connect(_on_attack_cooldown_finished)

func _on_navmesh_ready(_map_rid):
	if is_inside_tree():
		# ⚠️ Устанавливаем флаг готовности и ставим первую цель
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
	
	if hp <= 0:
		queue_free()

func _physics_process(delta):
	# Всегда применяем гравитацию, если не на земле
	if not is_on_floor():
		velocity.y -= gravity * delta
	current_vertical_velocity = velocity.y

	# ⚠️ Новая проверка: если карта ещё не готова, выходим из функции
	if not nav_map_ready:
		return
		
	# Логика в зависимости от состояния
	match current_state:
		State.KNOCKBACK:
			knockback_time -= delta
			if knockback_time <= 0:
				# Если игрок рядом, возвращаемся к преследованию
				if is_instance_valid(player) and global_position.distance_to(player.global_position) < 10.0:
					set_state(State.CHASE)
				else:
					set_state(State.PATROL)
			return # ⚠️ Выход из функции, чтобы не выполнять другую логику

		State.IDLE:
			agent.set_velocity(Vector3.ZERO)
			# Логика перехода из IDLE в CHASE
			if is_instance_valid(player) and global_position.distance_to(player.global_position) < 10.0:
				set_state(State.CHASE)
			return

		State.PATROL:
			# Если игрок в зоне видимости, переходим в CHASE
			if is_instance_valid(player) and global_position.distance_to(player.global_position) <= _chase_distance:
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
			# Если игрок слишком далеко, возвращаемся в PATROL
			if is_instance_valid(player) and global_position.distance_to(player.global_position) > _lost_chase_distance:
				set_state(State.PATROL)
				return
			else:
				agent.target_position = player.global_position
				var next_pos: Vector3 = agent.get_next_path_position()
				var dir = (next_pos - global_position).normalized()
				dir.y = 0
				agent.set_velocity(dir * agent.max_speed)

		State.ATTACK:
			if retreating:
				# Отбегаем на тактическую дистанцию
				if is_instance_valid(player):
					var retreat_pos = player.global_position + (global_position - player.global_position).normalized() * tactical_retreat_distance
					agent.target_position = retreat_pos
				
				# Если мы уже на месте, возвращаемся в CHASE
				if agent.is_navigation_finished():
					retreating = false
					set_state(State.CHASE)
			else:
				# Ждём завершения анимации атаки
				agent.set_velocity(Vector3.ZERO)
	
	# ⚠️ НОВАЯ ЛОГИКА ПОВОРОТА, ВЫЗЫВАЕТСЯ ТОЛЬКО ЗДЕСЬ
	var look_dir = Vector3.ZERO
	if current_state == State.CHASE and is_instance_valid(player):
		look_dir = player.global_position - global_position
	else:
		look_dir = velocity
	
	look_dir.y = 0
	if look_dir.length() > 0.001:
		var target_angle = atan2(look_dir.x, look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * 6.0)

# --- Добавленные функции ---
func _start_attack():
	print("attack")
	#if anim_player:
		#anim_player.play("attack_animation_name", 0, attack_animation_speed) # ⚠️ Замените на имя своей анимации атаки
		#await anim_player.animation_finished
	# После завершения анимации
	# Проверяем, что игрок всё ещё в зоне видимости
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= attack_range + 0.5:
		# Наносим урон игроку (вам нужно реализовать этот метод на игроке)
		# player.take_damage(10)
		last_attack_time = Time.get_ticks_msec() / 1000.0
	
	# Тактика "удар-отступление"
	retreating = true
	
func _on_attack_cooldown_finished():
	set_state(State.CHASE)

func _start_idle() -> void:
	# Запускаем логику idle
	var idle_cooldown = randf_range(1.5, 5.0)
	await get_tree().create_timer(idle_cooldown).timeout
	if current_state == State.IDLE:
		set_state(State.PATROL)

func set_state(new_state: State):
	current_state = new_state
	match current_state:
		State.PATROL:
			agent.max_speed = walk_speed
			# ⚠️ Убрали вызов _set_random_patrol_target() отсюда
		State.CHASE:
			agent.max_speed = run_speed
		State.ATTACK:
			pass
		State.IDLE:
			pass
		State.KNOCKBACK:
			pass
			
# --- Остальные функции остались прежними ---
func _on_detection_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		set_state(State.CHASE)

func _on_detection_zone_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		set_state(State.PATROL)
		_set_random_patrol_target()

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
