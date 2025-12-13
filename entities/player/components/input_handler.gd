class_name PlayerInput
extends Node

# Вектор движения
var move_vector: Vector2 = Vector2.ZERO
# Флаги действий
var is_jump_pressed: bool = false
var is_run_pressed: bool = false
var is_run_just_released: bool = false
var is_attack_pressed: bool = false

# Можно добавить флаг для блокировки ввода (катсцены, инвентарь)
var input_enabled: bool = true

func _physics_process(_delta: float) -> void:
	if not input_enabled:
		_clear_input()
		return
		
	move_vector = Input.get_vector(
		GameConstants.INPUT_MOVE_LEFT, 
		GameConstants.INPUT_MOVE_RIGHT, 
		GameConstants.INPUT_MOVE_UP, 
		GameConstants.INPUT_MOVE_DOWN
	)
	
	is_jump_pressed = Input.is_action_just_pressed(GameConstants.INPUT_JUMP)
	is_run_pressed = Input.is_action_pressed(GameConstants.INPUT_RUN)
	is_run_just_released = Input.is_action_just_released(GameConstants.INPUT_RUN)
	is_attack_pressed = Input.is_action_just_pressed(GameConstants.INPUT_ATTACK_PRIMARY)

func _clear_input() -> void:
	move_vector = Vector2.ZERO
	is_jump_pressed = false
	is_run_pressed = false
	is_run_just_released = false
	is_attack_pressed = false
