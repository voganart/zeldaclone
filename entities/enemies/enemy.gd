extends CharacterBody3D

@export var hp: float = 10
@export var knockback_time: float = 0.0
@export var gravity: int = 100
@export var knockback_strength: float = 2.0
@export var knockback_height: float = 5.0
@export var walk_speed: float = 1.5
@export var run_speed: float = 3.5
@export var patrol_zone: Area3D
@onready var agent: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@export var idle_chance: float = 0.3
var external_push: Vector3 = Vector3.ZERO
var idling: bool = false
var chasing: bool = false
var current_vertical_velocity: float = 0.0

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
		
func receive_push(push: Vector3):
	external_push += push
# Этот колбэк вызывается агентом каждый физический кадр
# и предоставляет скорректированную скорость
func _on_velocity_computed(safe_velocity: Vector3):
	if knockback_time > 0:
		move_and_slide()
		return

	velocity.x = safe_velocity.x + external_push.x
	velocity.z = safe_velocity.z + external_push.z
	velocity.y = current_vertical_velocity

	var look_dir = Vector3.ZERO
	if chasing and is_instance_valid(player):
		look_dir = player.global_position - global_position
	else:
		look_dir = velocity

	look_dir.y = 0
	if look_dir.length() > 0.001:
		var target_angle = atan2(look_dir.x, look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, get_physics_process_delta_time() * 6.0)

	move_and_slide()
	current_vertical_velocity = velocity.y
	external_push = external_push.lerp(Vector3.ZERO, 0.1)


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
		
	# Если в нокбэке
	if knockback_time > 0:
		knockback_time -= delta
		return
	
	# ⬇️ вот тут проверка на idle
	if idling:
		agent.set_velocity(Vector3.ZERO)
		return
	
	# Если карта ещё не готова
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0: 
		return
	
	# Логика смены цели
	if chasing and is_instance_valid(player):
		agent.target_position = player.global_position
	elif agent.is_navigation_finished():
		if randf() < idle_chance:
			_start_idle()
		else:
			_set_random_patrol_target()
		
	# Движение
	var next_pos: Vector3 = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	dir.y = 0
	var desired_velocity = dir * agent.max_speed
	
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

func _start_idle() -> void:
	idling = true
	velocity = Vector3.ZERO
	agent.set_velocity(Vector3.ZERO)

	# первая пауза
	await get_tree().create_timer(randf_range(1.5, 5.0)).timeout
	if chasing:
		idling = false
		return

	# 1–2 коротких "тычка" влево/вправо
	var n = randi_range(1, 5)
	for i in range(n):
		var start_angle = rotation.y
		
		var angle_deg = randf_range(20.0, 40.0)
		var _sign := 1.0
		if randf() < 0.5:
			_sign = -1.0
		
		var target_angle = start_angle + deg_to_rad(angle_deg) * _sign
		var t := 0.0
		while t < 1.0:
			if chasing:
				idling = false
				return
			t += get_physics_process_delta_time() * 1.5 # скорость поворота
			rotation.y = lerp_angle(start_angle, target_angle, t)
			await get_tree().process_frame

		# маленькая пауза между "тычками"
		await get_tree().create_timer(randf_range(1.5, 3.0)).timeout
		if chasing:
			idling = false
			return

	# финальная пауза
	await get_tree().create_timer(1.5).timeout
	idling = false
	_set_random_patrol_target()
