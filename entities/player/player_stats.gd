extends Node

@export var attack_cooldown: float = 0.15
@export var primary_attack_speed: float = 0.8
#jump
@export var jump_height : float = 1.25
@export var jump_time_to_peak : float = 0.45
@export var jump_time_to_descent : float = 0.28
@export var air_control: float = 0.05
@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

@export var base_speed: float = 3.0
@export var run_speed: float = 4.5
@export var stop_speed: float = 8.0
@export var acceleration: float = 0.3
@export var rot_speed: float = 5.0
@export var attack_movement_influense: float = 0.15

var jump_phase := ""  # '' / 'start' / 'mid'
@export var run_toggle_mode: bool = true
@onready var sprint_timer: Timer = $SprintTimer
@onready var first_attack_timer: Timer = $FirstAttackTimer
var air_speed: float
var movement_input: Vector2 = Vector2.ZERO
var is_running: bool = false
var is_stopping := false
var can_sprint := true
