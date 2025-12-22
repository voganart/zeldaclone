extends State

@export var frustration_duration: float = 4.0
var timer: float = 0.0
var target_pos: Vector3 # Точка, на которую будем смотреть
var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	timer = frustration_duration
	
	if is_instance_valid(enemy.player):
		target_pos = enemy.player.global_position
	
	# 1. Запускаем анимацию (через стейт в дереве)
	enemy.play_animation(GameConstants.ANIM_ENEMY_ANGRY)
	
	# 2. РАНДОМИЗАЦИЯ: Сдвигаем время начала через TimeSeek в дереве
	var anim_name = GameConstants.ANIM_ENEMY_ANGRY
	
	if enemy.anim_player.has_animation(anim_name):
		var anim_length = enemy.anim_player.get_animation(anim_name).length
		# Генерируем случайную точку старта
		var random_offset = randf() * anim_length
		# Отправляем запрос в дерево
		enemy.set_anim_param("angry_seek/seek_request", random_offset)
	
	AIDirector.release_slot(enemy)
	AIDirector.return_attack_token(enemy)


func physics_update(delta: float) -> void:
	timer -= delta
	
	# 2. ПОВОРОТ: Враг смотрит на запомненную точку, а не на живого игрока
	# Используем небольшую скорость поворота (напр. 3.0), чтобы это было плавно
	enemy.handle_rotation(delta, target_pos, 3.0)

	# Проверка возврата в погоню (с задержкой 1.5 сек, чтобы не мельтешил)
	if timer < (frustration_duration - 1.5):
		if is_instance_valid(enemy.player):
			enemy.nav_agent.target_position = enemy.player.global_position
			if enemy.nav_agent.is_target_reachable():
				# Игрок снова доступен!
				transitioned.emit(self, GameConstants.STATE_CHASE)
				return

	if timer <= 0:
		_give_up()

func _give_up():
	if enemy.health_component:
		enemy.health_component.heal(enemy.health_component.max_health)
	
	enemy.frustrated_cooldown = 10.0
	MusicBrain.set_combat_state(false)
	transitioned.emit(self, GameConstants.STATE_PATROL)
	return
func exit() -> void:
	# ВСЕГДА возвращаем скорость анимации в 1.0 при выходе, чтобы не сломать другие стейты
	enemy.anim_player.speed_scale = 1.0
	AIDirector.return_attack_token(enemy)
