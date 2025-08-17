extends Resource
class_name PlayerStats
@onready var _mesh: Node3D = $character

#jump
@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.3
@export var air_control: float = 0.3


@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0
var jump_phase := ""  # '' / 'start' / 'mid'

@onready var anim_player: AnimationPlayer = $character/AnimationPlayer
@export var base_speed: float = 5.0
@export var run_speed: float = 8.0
@export var stop_speed: float = 15.0
@export var acceleration: float = 0.1
@export var rot_speed: float = 10.0
var air_speed: float
var movement_input: Vector2 = Vector2.ZERO
var is_running: bool = false
@export var run_toggle_mode: bool = true
