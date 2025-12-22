extends State

var enemy: Enemy
var unreachable_timer: float = 0.0

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.max_speed = enemy.run_speed
	unreachable_timer = 0.0
	MusicBrain.set_combat_state(true)
	
	# !!! ИЗМЕНЕНИЕ: Включаем боевой режим бега (Combat Idle -> Run) !!!
	enemy.set_move_mode("chase")

func physics_update(delta: float) -> void:
	# ... (весь код physics_update остается как в предыдущем ответе с "умным поворотом") ...
	# Копируйте логику из предыдущего моего ответа про "обход препятствий"
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	enemy.nav_agent.target_position = enemy.player.global_position
	
	if not enemy.nav_agent.is_target_reachable():
		unreachable_timer += delta
		if unreachable_timer > 1.5:
			transitioned.emit(self, GameConstants.STATE_FRUSTRATED)
			return
	else:
		unreachable_timer = 0.0

	var dist = enemy.global_position.distance_to(enemy.player.global_position)
	if dist <= enemy.attack_component.attack_range + 0.5:
		transitioned.emit(self, GameConstants.STATE_COMBAT_STANCE)
		return

	enemy.move_toward_path()
	
	# Умный поворот
	var next_path_pos = enemy.nav_agent.get_next_path_position()
	var dir_to_path = (next_path_pos - enemy.global_position).normalized()
	var dir_to_player = (enemy.player.global_position - enemy.global_position).normalized()
	var alignment = dir_to_path.dot(dir_to_player)
	
	if alignment > 0.7:
		enemy.handle_rotation(delta, enemy.player.global_position)
	else:
		enemy.handle_rotation(delta)

	enemy.update_movement_animation(delta)

func exit() -> void:
	MusicBrain.set_combat_state(false)
	# При выходе можно не сбрасывать, следующий стейт (Patrol или CombatStance) сам поставит нужный режим.
