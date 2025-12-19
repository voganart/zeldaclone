extends State

@export var idle_duration_min: float = 3.0
@export var idle_duration_max: float = 7.0

var timer: float = 0.0
var idle_look_timer: float = 0.0
var is_looking_around: bool = false
var target_angle: float = 0.0

var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	
	enemy.play_animation(GameConstants.ANIM_ENEMY_IDLE, 0.2, 1.0)
	
	timer = randf_range(idle_duration_min, idle_duration_max)
	idle_look_timer = randf_range(1.5, 4.0)
	is_looking_around = false
	
	# print("[FSM] Enter Idle")

func update(delta: float) -> void:
	timer -= delta
	
	# Если увидели игрока -> Погоня
	if enemy.vision_component.can_see_target(enemy.player):
		transitioned.emit(self, GameConstants.STATE_CHASE)
		return
	
	# Логика оглядывания
	_handle_looking_around(delta)
	
	# Таймер истек -> Патруль
	if timer <= 0:
		transitioned.emit(self, GameConstants.STATE_PATROL)
	idle_look_timer -= delta
	if idle_look_timer <= 0:
		# Раз в 2-4 секунды чуть-чуть меняем угол поворота (на 30-45 градусов)
		var random_angle = randf_range(-0.7, 0.7) 
		var target_rot = enemy.rotation.y + random_angle
		# Плавный поворот к новому случайному углу
		enemy.rotation.y = lerp_angle(enemy.rotation.y, target_rot, delta * 1.0)
		idle_look_timer = randf_range(2.0, 4.0)
func _handle_looking_around(delta: float) -> void:
	idle_look_timer -= delta
	if idle_look_timer <= 0:
		is_looking_around = !is_looking_around
		idle_look_timer = randf_range(1.5, 4.0)
		if is_looking_around:
			target_angle = enemy.rotation.y + randf_range(-PI / 3, PI / 3)
	
	if is_looking_around:
		enemy.rotation.y = lerp_angle(enemy.rotation.y, target_angle, delta * 2.0)
