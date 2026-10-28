extends State

@export var frustration_duration: float = 4.0
@export var min_frustrated_time: float = 1.0
@export var reach_check_interval: float = 0.5
var timer: float = 0.0
var _recheck_timer: float = 0.0
var target_pos: Vector3
var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	timer = frustration_duration
	
	if is_instance_valid(enemy.player):
		target_pos = enemy.player.global_position
		enemy.nav_agent.target_position = target_pos
	_recheck_timer = reach_check_interval
	
	# 1. Переключаем состояние дерева
	enemy.set_tree_state("angry")
	enemy.set_move_mode("chase") 
	enemy.set_locomotion_blend(0.0)
	# 2. РАНДОМИЗАЦИЯ СТАРТА через TimeSeek
	var anim_name = GameConstants.ANIM_ENEMY_ANGRY
	if enemy.anim_player.has_animation(anim_name):
		var anim_length = enemy.anim_player.get_animation(anim_name).length
		var random_offset = randf() * anim_length
		enemy.trigger_angry_seek(random_offset)
	
	AIDirector.release_slot(enemy)
	AIDirector.return_attack_token(enemy)

func physics_update(delta: float) -> void:
	timer -= delta
	enemy.handle_rotation(delta, target_pos, 3.0)

	_recheck_timer -= delta
	if _recheck_timer <= 0 and is_instance_valid(enemy.player):
		_recheck_timer = reach_check_interval
		# Путь к цели, заданной на прошлой проверке, уже посчитан навигацией
		if frustration_duration - timer >= min_frustrated_time and enemy.nav_agent.is_target_reachable():
			transitioned.emit(self, GameConstants.STATE_CHASE)
			return
		enemy.nav_agent.target_position = enemy.player.global_position

	if timer <= 0:
		_give_up()

func _give_up():
	# !!! ИЗМЕНЕНИЕ: Убрали мгновенное лечение !!!
	# Теперь враг просто сбрасывает агрессию, а лечиться будет в Patrol
	
	enemy.frustrated_cooldown = 10.0
	enemy.set_combat_music(false)
	transitioned.emit(self, GameConstants.STATE_PATROL)

func exit() -> void:
	# Возвращаем состояние в alive при выходе
	enemy.set_tree_state("alive")
	AIDirector.return_attack_token(enemy)
