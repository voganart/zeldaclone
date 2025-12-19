extends State

var enemy: Enemy
var unreachable_timer: float = 0.0

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.max_speed = enemy.run_speed
	unreachable_timer = 0.0
	MusicBrain.set_combat_state(true)

func physics_update(delta: float) -> void:
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	enemy.nav_agent.target_position = enemy.player.global_position
	
	# ПРОВЕРКА: Доступен ли игрок?
	if not enemy.nav_agent.is_target_reachable():
		unreachable_timer += delta
		if unreachable_timer > 1.5:
			transitioned.emit(self, GameConstants.STATE_FRUSTRATED)
			return
	else:
		unreachable_timer = 0.0

	# Логика перехода к атаке
	var dist = enemy.global_position.distance_to(enemy.player.global_position)
	if dist <= enemy.attack_component.attack_range:
		transitioned.emit(self, GameConstants.STATE_COMBAT_STANCE)
		return

	# Обычное движение
	enemy.move_toward_path()
	enemy.handle_rotation(delta, enemy.player.global_position)
	enemy.update_movement_animation(delta)

func exit() -> void:
	MusicBrain.set_combat_state(false)
	pass
