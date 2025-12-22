extends State

@export var flee_duration: float = 5.0 # Сколько секунд враг будет убегать
@export var flee_speed: float = 0.5
var timer: float = 0.0
var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.max_speed = flee_speed
	timer = flee_duration
	
	_set_flee_target()
	enemy.play_animation(GameConstants.ANIM_ENEMY_WALK)
	print("AI: Fleeing!")

func physics_update(delta: float) -> void:
	timer -= delta
	
	# Если время бегства истекло, переходим в патруль
	if timer <= 0:
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return
		
	# Если достигли точки, а время еще есть, выбираем новую
	if enemy.nav_agent.is_navigation_finished():
		_set_flee_target()

	# Движение
	enemy.move_toward_path()
	# Во время панического бегства смотрим вперед, а не на игрока
	enemy.handle_rotation(delta)
	enemy.update_movement_animation(delta)

func _set_flee_target() -> void:
	if not is_instance_valid(enemy.player):
		return # Не от кого убегать
		
	# Находим направление ОТ игрока
	var flee_direction = (enemy.global_position - enemy.player.global_position).normalized()
	# Выбираем точку далеко в этом направлении
	var target_point = enemy.global_position + flee_direction * 20.0 # 20 метров - условная дистанция
	
	# Находим ближайшую валидную точку на навмеше
	var nav_map = enemy.nav_agent.get_navigation_map()
	var valid_point = NavigationServer3D.map_get_closest_point(nav_map, target_point)
	enemy.nav_agent.target_position = valid_point
