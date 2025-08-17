extends CharacterBody3D
#jump
@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.3
@export var air_control: float = 0.3

@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

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

func _physics_process(delta: float) -> void:
	move_logic(delta)
	jump_logic(delta)
	rot_char(delta)
	animation_player()
	move_and_slide()
	
func _input(event):
	if event.is_action_pressed("run"):
		if run_toggle_mode:
			is_running = !is_running    # переключатель
		else:
			is_running = true           # удерживаем
	if event.is_action_released("run") and not run_toggle_mode:
		is_running = false
		
func move_logic(delta):
	movement_input = Input.get_vector('left',"right", "up", "down")
	var velocity_2d = Vector2(velocity.x, velocity.z)
	var is_airborne = not is_on_floor()
	var control = 1.0 if is_on_floor() else air_control
	
	if movement_input == Vector2.ZERO:
		is_running = false
		
	var current_speed = air_speed if is_airborne else (run_speed if is_running else base_speed)
	
	if movement_input != Vector2.ZERO:
		velocity_2d = velocity_2d.lerp(movement_input * current_speed, acceleration * control)
	else:
		velocity_2d = velocity_2d.move_toward(Vector2.ZERO, stop_speed * delta)

	velocity.x = velocity_2d.x
	velocity.z = velocity_2d.y	
	
func jump_logic(delta):
	if Input.is_action_just_pressed('jump') and is_on_floor():
		velocity.y = -jump_velocity
		air_speed = Vector2(velocity.x, velocity.z).length()
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y -= gravity * delta
	
func rot_char(delta):
	var vel_2d = Vector2(velocity.x, -velocity.z)
	if vel_2d.length_squared() > 0.001:
		var target_angle = vel_2d.angle() + PI / 2 # угол в 2D
		rotation.y = lerp_angle(rotation.y, target_angle, rot_speed * delta)

func animation_player():
	var current_velocity := velocity.length()
	if current_velocity > base_speed + 1.5:
		anim_player.play('Boy_run', 1.0, lerp(0.5, 1.25, current_velocity/6))
	elif current_velocity > 0.7:
		anim_player.play('Boy_walk', 0.5, lerp(0.5, 1.25, current_velocity/4))
	else:
		anim_player.play('Boy_idle')
