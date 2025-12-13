extends State

@export var stuck_threshold: float = 2.0
@export var idle_chance: float = 0.8 # Шанс уйти в Idle после достижения точки

var time_stuck: float = 0.0
var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.max_speed = enemy.walk_speed
	
	time_stuck = 0.0
	_set_random_patrol_target()
	enemy.play_animation(GameConstants.ANIM_ENEMY_WALK, 0.2, 1.0)
	
	# print("[FSM] Enter Patrol")

func physics_update(delta: float) -> void:
	# Проверка на обнаружение игрока (с учетом кулдауна фрустрации)
	if enemy.frustrated_cooldown <= 0:
		if enemy.vision_component.can_see_target(enemy.player):
			transitioned.emit(self, GameConstants.STATE_CHASE)
			return
	
	# Пассивная регенерация здоровья (награда за выход из боя)
	if enemy.health_component and enemy.health_component.current_health < enemy.health_component.max_health:
		enemy.health_component.heal(10.0 * delta)

	# Проверка застревания
	if enemy.velocity.length() < 0.1:
		time_stuck += delta
	else:
		time_stuck = 0.0
	
	if time_stuck > stuck_threshold:
		# Если застряли — просто выбираем новую точку
		time_stuck = 0.0
		_set_random_patrol_target()
		return

	# Достигли цели?
	if enemy.nav_agent.is_navigation_finished():
		if randf() < idle_chance:
			transitioned.emit(self, "idle")
		else:
			_set_random_patrol_target()
		return

	# Движение
	enemy.move_toward_path()
	enemy.handle_rotation(delta)
	enemy.update_movement_animation(delta) # Для блендинга, хотя тут скорость постоянная

func _set_random_patrol_target() -> void:
	if not enemy.patrol_zone:
		return
	
	var shape_node = enemy.patrol_zone.get_node_or_null("CollisionShape3D")
	if not shape_node or not shape_node.shape is BoxShape3D:
		push_warning("Patrol zone missing BoxShape3D")
		return
	
	var extents = shape_node.shape.extents
	var box_center = shape_node.global_transform.origin

	# Пытаемся найти валидную точку на навмеше
	for i in range(10):
		var random_offset = Vector3(
			randf_range(-extents.x, extents.x),
			0,
			randf_range(-extents.z, extents.z)
		)
		var candidate = box_center + random_offset
		var nav_map = enemy.nav_agent.get_navigation_map()
		var valid_point = NavigationServer3D.map_get_closest_point(nav_map, candidate)
		
		enemy.nav_agent.target_position = valid_point
		return
