class_name PlayerInput
extends Node

@export var buffer_window: float = 0.2

var move_vector: Vector2 = Vector2.ZERO
var is_run_pressed: bool = false
var is_run_just_released: bool = false

# Таймеры буфера
var _jump_buffer_timer: float = 0.0
var _attack_buffer_timer: float = 0.0
var _roll_buffer_timer: float = 0.0

var input_enabled: bool = true

func _physics_process(delta: float) -> void:
	if not input_enabled:
		_clear_input()
		return
		
	move_vector = Input.get_vector(
		GameConstants.INPUT_MOVE_LEFT, 
		GameConstants.INPUT_MOVE_RIGHT, 
		GameConstants.INPUT_MOVE_UP, 
		GameConstants.INPUT_MOVE_DOWN
	)
	
	is_run_pressed = Input.is_action_pressed(GameConstants.INPUT_RUN)
	is_run_just_released = Input.is_action_just_released(GameConstants.INPUT_RUN)
	
	_update_timers(delta)
	
	if Input.is_action_just_pressed(GameConstants.INPUT_JUMP):
		_jump_buffer_timer = buffer_window
		
	if Input.is_action_just_pressed(GameConstants.INPUT_ATTACK_PRIMARY):
		_attack_buffer_timer = buffer_window
		
	if Input.is_action_just_pressed(GameConstants.INPUT_RUN):
		_roll_buffer_timer = buffer_window

func _update_timers(delta: float) -> void:
	if _jump_buffer_timer > 0: _jump_buffer_timer -= delta
	if _attack_buffer_timer > 0: _attack_buffer_timer -= delta
	if _roll_buffer_timer > 0: _roll_buffer_timer -= delta

func _clear_input() -> void:
	move_vector = Vector2.ZERO
	is_run_pressed = false
	is_run_just_released = false
	_jump_buffer_timer = 0.0
	_attack_buffer_timer = 0.0
	_roll_buffer_timer = 0.0

# --- ПУБЛИЧНЫЕ МЕТОДЫ ---

func check_jump() -> bool:
	if _jump_buffer_timer > 0:
		_jump_buffer_timer = 0.0
		return true
	return false

func check_attack() -> bool:
	if _attack_buffer_timer > 0:
		_attack_buffer_timer = 0.0
		return true
	return false

func check_roll() -> bool:
	if _roll_buffer_timer > 0:
		_roll_buffer_timer = 0.0
		return true
	return false

# Геттеры для "подсматривания" в буфер без очистки
var is_attack_pressed: bool:
	get: return _attack_buffer_timer > 0

# !!! ДОБАВИЛИ ЭТО !!!
var is_roll_buffered: bool:
	get: return _roll_buffer_timer > 0
