extends State

@export var frustration_duration: float = 3.0
@export var chase_cooldown_duration: float = 2.0 # Время игнора после выхода (если вышли по таймеру)

var timer: float = 0.0
var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	
	timer = frustration_duration
	enemy.play_animation(GameConstants.ANIM_ENEMY_ANGRY, 0.2, 1.0)

# Используем physics_update для работы с навигацией
func physics_update(delta: float) -> void:
	timer -= delta
	
	# Зацикливание анимации "злости"
	if not enemy.anim_player.is_playing() or enemy.anim_player.current_animation != GameConstants.ANIM_ENEMY_ANGRY:
		enemy.play_animation(GameConstants.ANIM_ENEMY_ANGRY, 0.1, 1.0)
		
	# Поворачиваемся к игроку
	if is_instance_valid(enemy.player):
		enemy.handle_rotation(delta, enemy.player.global_position)
		
		# === ПРОВЕРКА ДОСТУПНОСТИ ИГРОКА ===
		# 1. Обновляем цель навигации на текущую позицию игрока
		enemy.nav_agent.target_position = enemy.player.global_position
		
		# 2. Проверяем, может ли навигация построить путь
		# is_target_reachable() вернет true, если точка на навмеше и путь существует
		if enemy.nav_agent.is_target_reachable():
			# Дополнительная проверка: если путь есть, но он ооочень длинный (обходной),
			# а игрок близко (но за забором), возможно стоит остаться в Frustrated.
			# Но для динамики лучше сразу бежать.
			
			# Сбрасываем кулдаун, так как мы нашли путь "честно"
			enemy.frustrated_cooldown = 0.0
			transitioned.emit(self, GameConstants.STATE_CHASE)
			return
			
		# Фолбэк: если игрок подошел в упор (например, спрыгнул прямо на голову или рядом),
		# а навмеш еще тупит — атакуем/преследуем принудительно.
		var dist = enemy.global_position.distance_to(enemy.player.global_position)
		if dist < 2.5: 
			enemy.frustrated_cooldown = 0.0
			transitioned.emit(self, GameConstants.STATE_CHASE)
			return

	# Если время вышло — уходим в патруль
	if timer <= 0:
		enemy.frustrated_cooldown = chase_cooldown_duration
		transitioned.emit(self, GameConstants.STATE_PATROL)
