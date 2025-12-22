extends State

@export var flee_duration: float = 5.0
@export var flee_speed: float = 4.0 # Убегать надо быстро!
var timer: float = 0.0
var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.max_speed = flee_speed
	timer = flee_duration
	
	# --- ANIMATION TREE ---
	enemy.set_tree_state("alive")
	enemy.set_move_mode("normal")
	# ----------------------
	
	_set_flee_target()
	# Анимация обновится в update_movement_animation на основе скорости

func physics_update(delta: float) -> void:
	timer -= delta
	
	if timer <= 0:
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return
		
	if enemy.nav_agent.is_navigation_finished():
		_set_flee_target()

	enemy.move_toward_path()
	# При бегстве смотрим по направлению движения
	enemy.handle_rotation(delta) 
	
	# Обновляем блендинг (Walk/Run) в зависимости от текущей скорости
	enemy.update_movement_animation(delta)

func _set_flee_target() -> void:
	if not is_instance_valid(enemy.player):
		return
		
	var flee_direction = (enemy.global_position - enemy.player.global_position).normalized()
	var target_point = enemy.global_position + flee_direction * 15.0
	
	var nav_map = enemy.nav_agent.get_navigation_map()
	var valid_point = NavigationServer3D.map_get_closest_point(nav_map, target_point)
	enemy.nav_agent.target_position = valid_point
