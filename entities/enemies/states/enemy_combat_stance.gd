extends State

## Тактическая стойка: враг занимает слот на кольце вокруг игрока (окружение),
## ждёт токен атаки, затем сближается и бьёт. Всё движение — по навмешу,
## поэтому стены и препятствия обходятся, а не таранятся.

@export var strafe_speed: float = 2.2 ## Скорость перемещения по кольцу
@export var change_dir_time_min: float = 2.5 ## Мин. время до смены слота (обход)
@export var change_dir_time_max: float = 5.0
@export var initial_attack_delay: float = 0.2
@export var slot_reach_distance: float = 0.7
@export var disengage_distance: float = 9.0 ## Дальше — снова погоня
@export var engage_timeout: float = 2.5 ## Не дотянулся до игрока — отдаёт токен
@export_range(0.0, 1.0) var feint_chance: float = 0.3
@export var feint_step: float = 1.5
@export var path_update_interval: float = 0.2

var enemy: Enemy
var slot_index: int = -1
var change_dir_timer: float = 0.0
var attack_delay_timer: float = 0.0
var path_timer: float = 0.0
var engaging: bool = false
var engage_timer: float = 0.0
var feint_timer: float = 0.0

func enter() -> void:
	enemy = entity as Enemy
	engaging = false
	feint_timer = 0.0
	path_timer = 0.0
	change_dir_timer = randf_range(change_dir_time_min, change_dir_time_max)
	attack_delay_timer = initial_attack_delay
	slot_index = AIDirector.request_position_slot(enemy)

	enemy.set_combat_music(true)
	enemy.set_move_mode("strafe")

func physics_update(delta: float) -> void:
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	var player_pos: Vector3 = enemy.player.global_position
	var dist = enemy.global_position.distance_to(player_pos)

	if dist > disengage_distance:
		transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	if attack_delay_timer > 0:
		attack_delay_timer -= delta

	# 1. Получить право на атаку
	if not engaging and attack_delay_timer <= 0 and enemy.attack_component.is_attack_ready():
		if AIDirector.request_attack_token(enemy):
			engaging = true
			engage_timer = engage_timeout

	# 2. Атака: сближение по навмешу и удар
	if engaging:
		if dist <= enemy.attack_component.attack_range:
			engaging = false # токен уходит в атаку вместе с врагом
			transitioned.emit(self, GameConstants.STATE_ATTACK)
			return
		engage_timer -= delta
		if engage_timer <= 0:
			engaging = false
			AIDirector.return_attack_token(enemy)
		else:
			enemy.set_move_mode("chase")
			_move_to(player_pos, enemy.run_speed, delta)
			enemy.handle_rotation(delta, player_pos, enemy.combat_rotation_speed)
			enemy.update_movement_animation(delta)
			return

	# 3. Ожидание: держим свой слот на кольце, иногда меняем его (обход с фланга)
	change_dir_timer -= delta
	if change_dir_timer <= 0:
		change_dir_timer = randf_range(change_dir_time_min, change_dir_time_max)
		slot_index = AIDirector.shift_position_slot(enemy)
		if randf() < feint_chance:
			feint_timer = 0.6
	else:
		slot_index = AIDirector.request_position_slot(enemy)

	var target := enemy.global_position
	if slot_index >= 0:
		target = AIDirector.get_slot_world_pos(slot_index, enemy.player)
	else:
		# Слотов нет — держим дистанцию кольца по прямой от игрока
		var away = enemy.global_position - player_pos
		away.y = 0
		target = player_pos + away.normalized() * AIDirector.SLOT_DISTANCE

	# Финт: короткий шаг к игроку — «проверяет» его реакцию
	if feint_timer > 0:
		feint_timer -= delta
		target = enemy.global_position + (player_pos - enemy.global_position).normalized() * feint_step

	var to_target = target - enemy.global_position
	to_target.y = 0
	var gap = to_target.length()
	if gap > slot_reach_distance:
		var close = gap < 3.0
		enemy.set_move_mode("strafe" if close else "chase")
		_move_to(target, strafe_speed if close else enemy.run_speed, delta)
	else:
		enemy.set_move_mode("strafe")
		enemy.nav_agent.set_velocity(Vector3.ZERO)

	enemy.handle_rotation(delta, player_pos, enemy.combat_rotation_speed)
	enemy.update_movement_animation(delta)

func _move_to(target: Vector3, speed: float, delta: float) -> void:
	path_timer -= delta
	if path_timer <= 0:
		path_timer = path_update_interval + randf_range(-0.05, 0.05)
		enemy.nav_agent.target_position = target
	enemy.nav_agent.max_speed = speed
	enemy.move_toward_path()

func on_damage_taken(_is_heavy: bool = false) -> void:
	# Получив удар, враг перестаёт ждать и сам ищет момент для ответа
	attack_delay_timer = 0.0

func exit() -> void:
	if engaging:
		engaging = false
		AIDirector.return_attack_token(enemy)
	enemy.set_move_mode("normal")
