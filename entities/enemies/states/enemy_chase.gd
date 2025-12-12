extends State

@export var chase_memory_duration: float = 5.0
@export var stuck_threshold: float = 0.5 # Время без движения, чтобы считать застрявшим

var time_since_player_seen: float = 0.0
var time_stuck: float = 0.0
var last_dist_to_target: float = INF
var stuck_detector = StuckDetector.new()
# Ссылки на типизированного родителя для удобства
var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.max_speed = enemy.run_speed
	
	time_since_player_seen = 0.0
	time_stuck = 0.0
	last_dist_to_target = INF
	
	# Сброс кулдауна фрустрации при начале погони
	enemy.frustrated_cooldown = 0.0
	
	enemy.play_animation(GameConstants.ANIM_ENEMY_RUN, 0.2, 1.0)
	stuck_detector.init(stuck_threshold)
	# print("[FSM] Enter Chase")

func physics_update(delta: float) -> void:
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	# 1. Обновляем таймеры видимости
	if enemy.vision_component.can_see_target(enemy.player):
		time_since_player_seen = 0.0
		enemy.last_known_player_pos = enemy.player.global_position
	else:
		time_since_player_seen += delta
		
	# 2. Проверка дистанции
	var dist_to_player = enemy.global_position.distance_to(enemy.player.global_position)
	
	# Если мы в радиусе атаки и кулдаун готов -> Атака
	if dist_to_player <= enemy.attack_component.attack_range:
		if enemy.attack_component.is_attack_ready():
			transitioned.emit(self, GameConstants.STATE_ATTACK)
			return
		# Если кулдаун не готов, можно кружить (орбита), но для простоты пока стоим/двигаемся медленно
		# (Логику орбиты можно добавить сюда же)

	# 3. Условия выхода из погони
	# Потеряли из виду надолго
	if time_since_player_seen > chase_memory_duration:
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return
		
	# Игрок слишком далеко (абсолютный лимит)
	if dist_to_player > enemy.vision_component.lost_sight_range:
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	# 4. Логика застревания (Stuck Detection)
	if stuck_detector.check(delta, enemy.velocity):
		transitioned.emit(self, GameConstants.STATE_FRUSTRATED)
		return

	# 5. Движение
	enemy.nav_agent.target_position = enemy.player.global_position
	enemy.move_toward_path()
	enemy.handle_rotation(delta)
	
	# Анимация (блендинг бега/ходьбы)
	enemy.update_movement_animation(delta)
