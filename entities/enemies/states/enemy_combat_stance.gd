extends State

@export var strafe_speed: float = 1.5
@export var change_dir_time_min: float = 2.0
@export var change_dir_time_max: float = 5.0

# !!! НОВОЕ: Задержка перед атакой после входа в стойку
@export var initial_attack_delay: float = 0.4 

var enemy: Enemy
var strafe_dir: int = 1
var change_dir_timer: float = 0.0
var attack_delay_timer: float = 0.0 # Таймер задержки

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.max_speed = strafe_speed
	
	strafe_dir = 1 if randf() > 0.5 else -1
	change_dir_timer = randf_range(change_dir_time_min, change_dir_time_max)
	
	# При входе ставим таймер. Враг не сможет атаковать эти 0.4 секунды.
	# Это даст время анимации плавно перейти из Бега в Стойку.
	attack_delay_timer = initial_attack_delay
	
	MusicBrain.set_combat_state(true)
	enemy.set_move_mode("strafe")

func physics_update(delta: float) -> void:
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	var dist = enemy.global_position.distance_to(enemy.player.global_position)
	
	# Если далеко — погоня
	if dist > enemy.attack_component.attack_range * 1.5:
		transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	# Уменьшаем таймер задержки
	if attack_delay_timer > 0:
		attack_delay_timer -= delta
	else:
		# Атакуем только если таймер истек
		if enemy.attack_component.is_attack_ready():
			if AIDirector.request_attack_token(enemy):
				transitioned.emit(self, GameConstants.STATE_ATTACK)
				return

	_handle_strafing(delta)
	enemy.handle_rotation(delta, enemy.player.global_position, enemy.combat_rotation_speed)

func _handle_strafing(delta: float) -> void:
	change_dir_timer -= delta
	if change_dir_timer <= 0:
		strafe_dir *= -1
		change_dir_timer = randf_range(change_dir_time_min, change_dir_time_max)
	
	var dir_to_player = (enemy.player.global_position - enemy.global_position).normalized()
	var right_vector = dir_to_player.cross(Vector3.UP).normalized()
	var move_dir = right_vector * strafe_dir
	
	var optimal_dist = enemy.attack_component.attack_range * 0.8
	var current_dist = enemy.global_position.distance_to(enemy.player.global_position)
	
	if current_dist < optimal_dist - 0.5:
		move_dir -= dir_to_player * 0.5
	elif current_dist > optimal_dist + 0.5:
		move_dir += dir_to_player * 0.5
		
	enemy.nav_agent.set_velocity(move_dir * strafe_speed)
	
	# Обновляем анимацию
	enemy.update_movement_animation(delta)

func exit() -> void:
	MusicBrain.set_combat_state(false)
	enemy.set_move_mode("normal")
