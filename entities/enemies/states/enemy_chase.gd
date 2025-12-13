extends State

@export var chase_memory_duration: float = 5.0
@export var stuck_threshold: float = 0.5 # Время без движения, чтобы считать застрявшим

var time_since_player_seen: float = 0.0
var time_stuck: float = 0.0
var unreachable_timer: float = 0.0 # Таймер недосягаемости
var last_dist_to_target: float = INF
var stuck_detector = StuckDetector.new()
# Ссылки на типизированного родителя для удобства
var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.max_speed = enemy.run_speed
	
	time_since_player_seen = 0.0
	time_stuck = 0.0
	unreachable_timer = 0.0
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

	# Обновляем таймеры видимости
	if enemy.vision_component.can_see_target(enemy.player):
		time_since_player_seen = 0.0
		enemy.last_known_player_pos = enemy.player.global_position
	else:
		time_since_player_seen += delta
		
	var dist_to_player = enemy.global_position.distance_to(enemy.player.global_position)
	
	# --- ЛОГИКА БЛИЖНЕГО БОЯ ---
	if dist_to_player <= enemy.attack_component.attack_range:
		enemy.nav_agent.set_velocity(Vector3.ZERO)
		enemy.handle_rotation(delta, enemy.player.global_position, enemy.combat_rotation_speed)
		
		if enemy.attack_component.is_attack_ready():
			if AIDirector.request_attack_token(enemy):
				transitioned.emit(self, GameConstants.STATE_ATTACK)
			else:
				enemy.play_animation(GameConstants.ANIM_ENEMY_ATTACK_IDLE, 0.2, 1.0)
				# Небольшой трюк: Отталкиваемся от игрока вектором скорости
				var dir_away = (enemy.global_position - enemy.player.global_position).normalized()
				enemy.velocity.x = dir_away.x * 0.5 # Медленно пятимся
				enemy.velocity.z = dir_away.z * 0.5
				enemy.move_and_slide()
			return
		else:
			enemy.play_animation(GameConstants.ANIM_ENEMY_ATTACK_IDLE, 0.2, 1.0)
	# --- ЛОГИКА ПОГОНИ (Игрок далеко) ---
	else:
		if time_since_player_seen > chase_memory_duration or dist_to_player > enemy.vision_component.lost_sight_range:
			transitioned.emit(self, GameConstants.STATE_PATROL)
			return

		# Движение
		enemy.nav_agent.target_position = enemy.player.global_position
		enemy.move_toward_path()
		
		# ПРОВЕРКА 1: Застряли ли мы физически?
		if stuck_detector.check(delta, enemy.velocity):
			transitioned.emit(self, GameConstants.STATE_FRUSTRATED)
			return

		# ПРОВЕРКА 2: Достижима ли цель? (Например, игрок на возвышенности)
		# ИСПРАВЛЕНИЕ: Добавили таймер, чтобы не триггерилось при обычном прыжке игрока
		if not enemy.nav_agent.is_target_reachable():
			unreachable_timer += delta
			if unreachable_timer > 1.5: # Накопить 1.5 секунды недосягаемости
				transitioned.emit(self, GameConstants.STATE_FRUSTRATED)
				return
		else:
			unreachable_timer = 0.0
		
		# !!! НОВАЯ УМНАЯ ЛОГИКА ПОВОРОТА !!!
		var move_direction = enemy.velocity.normalized()
		var player_direction = (enemy.player.global_position - enemy.global_position).normalized()
		
		# Вычисляем угол между направлением движения и направлением на игрока
		var angle = rad_to_deg(move_direction.angle_to(player_direction))
		
		# Если угол большой (значит, мы оббегаем препятствие), смотрим вперед
		if angle > enemy.strafe_view_angle:
			enemy.handle_rotation(delta) # Смотрим по направлению velocity
		# Иначе, если путь более-менее прямой, смотрим на игрока
		else:
			enemy.handle_rotation(delta, enemy.player.global_position)
		
		enemy.update_movement_animation(delta)
