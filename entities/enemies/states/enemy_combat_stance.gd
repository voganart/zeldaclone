extends State

# Настройки
@export var strafe_speed: float = 1.5
@export var change_dir_time_min: float = 2.0
@export var change_dir_time_max: float = 5.0

var enemy: Enemy
var strafe_dir: int = 1 # 1 = вправо, -1 = влево
var change_dir_timer: float = 0.0

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.max_speed = strafe_speed
	
	# Выбираем случайное направление при входе
	strafe_dir = 1 if randf() > 0.5 else -1
	change_dir_timer = randf_range(change_dir_time_min, change_dir_time_max)
	
	# Играем анимацию боевой стойки
	#enemy.play_animation(GameConstants.ANIM_ENEMY_ATTACK_IDLE, 0.2, 1.0)

func physics_update(delta: float) -> void:
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	var dist = enemy.global_position.distance_to(enemy.player.global_position)
	
	# 1. Если игрок убежал далеко -> возвращаемся в погоню
	if dist > enemy.attack_component.attack_range * 1.5:
		transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	# 2. Постоянно просим токен атаки
	if enemy.attack_component.is_attack_ready():
		if AIDirector.request_attack_token(enemy):
			transitioned.emit(self, GameConstants.STATE_ATTACK)
			return

	# 3. Логика стрейфа (кружения)
	_handle_strafing(delta)
	
	# Всегда смотрим на игрока
	enemy.handle_rotation(delta, enemy.player.global_position, enemy.combat_rotation_speed)

func _handle_strafing(delta: float) -> void:
	# Таймер смены направления
	change_dir_timer -= delta
	if change_dir_timer <= 0:
		strafe_dir *= -1 # Меняем направление
		change_dir_timer = randf_range(change_dir_time_min, change_dir_time_max)
	
	# Вычисляем вектор стрейфа
	# Вектор К игроку
	var dir_to_player = (enemy.player.global_position - enemy.global_position).normalized()
	# Перпендикулярный вектор (Cross product с UP вектором)
	var right_vector = dir_to_player.cross(Vector3.UP).normalized()
	
	# Итоговое направление движения
	var move_dir = right_vector * strafe_dir
	
	# Также немного корректируем дистанцию (если слишком близко - пятимся, если далеко - подходим)
	var optimal_dist = enemy.attack_component.attack_range * 0.8
	var current_dist = enemy.global_position.distance_to(enemy.player.global_position)
	
	if current_dist < optimal_dist - 0.5:
		move_dir -= dir_to_player * 0.5 # Отойти назад
	elif current_dist > optimal_dist + 0.5:
		move_dir += dir_to_player * 0.5 # Подойти ближе
		
	enemy.nav_agent.set_velocity(move_dir * strafe_speed)
	enemy.update_movement_animation(delta)

func exit() -> void:
	# Сброс скорости на дефолтную при выходе
	pass
