extends State

@export var frustration_duration: float = 3.0
@export var chase_cooldown_duration: float = 2.0 # Время игнора игрока после фрустрации

var timer: float = 0.0
var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	
	timer = frustration_duration
	enemy.play_animation(GameConstants.ANIM_ENEMY_ANGRY, 0.2, 1.0)
	
	# print("[FSM] Enter Frustrated")

func update(delta: float) -> void:
	timer -= delta
	
	# Если анимация закончилась, а время еще есть — повторить
	if not enemy.anim_player.is_playing() or enemy.anim_player.current_animation != GameConstants.ANIM_ENEMY_ANGRY:
		enemy.play_animation(GameConstants.ANIM_ENEMY_ANGRY, 0.1, 1.0)
		
	# ПРОВЕРКА: Если игрок вдруг стал доступен (спрыгнул к нам) — прерываем
	# Для простоты проверяем: виден ли игрок и есть ли путь (можно добавить проверку nav_agent.is_target_reachable(), если Godot 4.2+)
	# Здесь упрощенно: если очень близко
	if is_instance_valid(enemy.player):
		var dist = enemy.global_position.distance_to(enemy.player.global_position)
		if dist < 2.0: # Условная дистанция "доступности"
			transitioned.emit(self, GameConstants.STATE_CHASE)
			return

	if timer <= 0:
		# Выходим в патруль с кулдауном на агр
		enemy.frustrated_cooldown = chase_cooldown_duration
		transitioned.emit(self, GameConstants.STATE_PATROL)
