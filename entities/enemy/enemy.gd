extends CharacterBody3D

@export var hp := 10
@export var knockback_time := 0.0
@export var gravity := 100
@export var knockback_strength = 2.0
@export var knockback_height = 5.0
@export var walk_speed = 1.5
@export var run_speed = 3.5
@export var patrol_zone: Area3D
@onready var agent: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
var chasing := false
var current_vertical_velocity := 0.0

func _ready() -> void:
	agent.max_speed = walk_speed
	# Убедитесь, что карта навигации готова до того, как начнёте использовать агент.
	NavigationServer3D.map_changed.connect(_on_navmesh_ready)
	
	# Включаем систему избегания и подключаем сигнал
	agent.avoidance_enabled = true
	agent.velocity_computed.connect(Callable(self, "_on_velocity_computed"))

func _on_navmesh_ready(_map_rid):
	if is_inside_tree():
		_set_random_patrol_target()

# Этот колбэк вызывается агентом каждый физический кадр
# и предоставляет скорректированную скорость
func _on_velocity_computed(safe_velocity: Vector3):
	# Если мы в состоянии отталкивания, не используем безопасную скорость
	if knockback_time > 0:
		move_and_slide()
		return

	# Используем безопасную скорость для горизонтального движения
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	
	# Сохраняем вертикальную скорость, чтобы гравитация работала
	velocity.y = current_vertical_velocity
	
	# Поворачиваем персонажа в сторону движения
	if velocity.length() > 0.001:
		var look_dir = velocity
		look_dir.y = 0
		var target_angle = atan2(look_dir.x, look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, get_physics_process_delta_time() * 6.0)

	# Двигаем персонажа
	move_and_slide()
	current_vertical_velocity = velocity.y
	
func take_damage(amount, knockback_dir: Vector3):
	hp -= amount
	var final_knockback = knockback_dir.normalized() * knockback_strength
	final_knockback.y = knockback_height

	velocity = final_knockback
	knockback_time = 0.3
	
	if hp <= 0:
		queue_free()

func _physics_process(delta):
	# Всегда применяем гравитацию, если не на земле
	if not is_on_floor():
		velocity.y -= gravity * delta
	current_vertical_velocity = velocity.y
		
	# Если в нокбэке, уменьшаем время и не передаём скорость агенту
	if knockback_time > 0:
		knockback_time -= delta
		return
		
	# Вычисляем желаемую скорость, которую хотим передать агенту
	var desired_velocity = Vector3.ZERO
	
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0: 
		return
	
	# Логика смены цели
	if chasing and is_instance_valid(player):
		agent.target_position = player.global_position
	elif agent.is_navigation_finished():
		_set_random_patrol_target()
		
	# Вычисляем желаемую скорость на основе следующей точки пути
	var next_pos: Vector3 = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	dir.y = 0
	desired_velocity = dir * agent.max_speed
	
	# Передаём желаемую скорость агенту для расчёта избегания
	agent.set_velocity(desired_velocity)

func _on_detection_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		chasing = true
		agent.max_speed = run_speed

func _on_detection_zone_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		chasing = false
		agent.max_speed = walk_speed
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
