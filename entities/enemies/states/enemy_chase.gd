extends State

var enemy: Enemy
var unreachable_timer: float = 0.0

# --- ОПТИМИЗАЦИЯ: Таймер для обновления пути ---
# Как часто враг будет пересчитывать путь до игрока (в секундах)
@export var path_update_interval: float = 0.15 
var update_path_timer: float = 0.0
# -----------------------------------------------

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.max_speed = enemy.run_speed
	unreachable_timer = 0.0
	MusicBrain.set_combat_state(true)
	enemy.set_move_mode("chase")

	# --- ОПТИМИЗАЦИЯ: Немедленное обновление пути при входе в состояние ---
	# И ставим таймер на случайное значение, чтобы враги не обновляли путь одновременно
	if is_instance_valid(enemy.player):
		enemy.nav_agent.target_position = enemy.player.global_position
	update_path_timer = randf() * path_update_interval # Десинхронизация
	# --------------------------------------------------------------------

	# --- ЛОГИКА ИНДИКАТОРА АГРО ---
	var prev_name = ""
	# Проверяем, существует ли прошлое состояние (его может не быть при старте игры)
	if state_machine.previous_state:
		prev_name = state_machine.previous_state.name.to_lower()
	
	# Показываем "!" только если мы пришли из спокойных состояний
	# Если мы пришли из "attack" или "hit", значит мы уже в бою, и "!" показывать не надо
	if prev_name in ["patrol", "idle", "frustrated", "flee"]:
		if enemy.has_node("AlertIndicator"):
			enemy.alert_indicator.play_aggro()
	# ------------------------------
			
func physics_update(delta: float) -> void:
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	# --- ОПТИМИЗАЦИЯ: Обновление пути по таймеру ---
	update_path_timer -= delta
	if update_path_timer <= 0.0:
		update_path_timer = path_update_interval + randf_range(-0.05, 0.05) # Добавляем "дрожание"
		enemy.nav_agent.target_position = enemy.player.global_position
	# -----------------------------------------------

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
