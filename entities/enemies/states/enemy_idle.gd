extends State

@export var idle_duration_min: float = 3.0
@export var idle_duration_max: float = 7.0

var timer: float = 0.0
var idle_look_timer: float = 0.0
var is_looking_around: bool = false
var target_angle: float = 0.0

var enemy: Enemy

func enter() -> void:
	enemy = entity as Enemy
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	
	# --- ANIMATION TREE ---
	# Переключаем дерево в состояние Alive -> Normal Movement
	enemy.set_tree_state("alive")
	enemy.set_move_mode("normal")
	# Устанавливаем BlendSpace в 0 (Idle)
	enemy.set_locomotion_blend(0.0)
	# ----------------------
	
	timer = randf_range(idle_duration_min, idle_duration_max)
	idle_look_timer = randf_range(1.5, 4.0)
	is_looking_around = false

func physics_update(delta: float) -> void:
	timer -= delta
	
	if enemy.vision_component.can_see_target(enemy.player):
		transitioned.emit(self, GameConstants.STATE_CHASE)
		return
	
	_handle_looking_around(delta)
	
	if timer <= 0:
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

func _handle_looking_around(delta: float) -> void:
	idle_look_timer -= delta
	if idle_look_timer <= 0:
		is_looking_around = !is_looking_around
		idle_look_timer = randf_range(1.5, 4.0)
		if is_looking_around:
			# Выбираем случайный угол для поворота головы/тела
			target_angle = enemy.rotation.y + randf_range(-PI / 3, PI / 3)
	
	if is_looking_around:
		enemy.rotation.y = lerp_angle(enemy.rotation.y, target_angle, delta * 2.0)
