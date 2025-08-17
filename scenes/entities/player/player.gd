extends CharacterBody3D
#jump
@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.3
@export var air_control: float = 0.3
@export var in_air_speed: float = 0.1

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
			is_running = !is_running
		else:
			is_running = true
	if event.is_action_released("run") and not run_toggle_mode:
		is_running = false
		
func move_logic(delta):
	movement_input = Input.get_vector('left',"right", "up", "down")
	var control := (5.0 if is_on_floor() else air_control)
	
	if movement_input == Vector2.ZERO:
		is_running = false
		
	var max_speed = in_air_speed if not is_on_floor() else (run_speed if is_running else base_speed)
	
	var velocity_2d = Vector2(velocity.x, velocity.z)
	
	if movement_input != Vector2.ZERO:
		var input_strength = movement_input.length()
		var input_dir = movement_input.normalized()
		var desired = input_dir * (max_speed * input_strength)
		velocity_2d = velocity_2d.move_toward(desired, acceleration * max_speed * control)

	else:
		velocity_2d = velocity_2d.move_toward(Vector2.ZERO, stop_speed * delta)

	velocity.x = velocity_2d.x
	velocity.z = velocity_2d.y	
	
func jump_logic(delta):
	if Input.is_action_just_pressed('jump') and is_on_floor():
		velocity.y = -jump_velocity
		in_air_speed = Vector2(velocity.x, velocity.z).length()
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y -= gravity * delta
	
func rot_char(delta):
	var vel_2d = Vector2(velocity.x, -velocity.z)
	if vel_2d.length_squared() > 0.001 and is_on_floor():
		var target_angle = vel_2d.angle() + PI / 2 # угол в 2D
		rotation.y = lerp_angle(rotation.y, target_angle, rot_speed * delta)
	elif vel_2d.length_squared() > 0.001:
		var target_angle = vel_2d.angle() + PI / 2 # угол в 2D
		rotation.y = lerp_angle(rotation.y, target_angle, air_control * delta)
func animation_player():
	if not is_on_floor():
		if velocity.y > 0 and jump_phase != "start":
			anim_player.play("Boy_jump_start", 0)
			jump_phase = "start"
		elif velocity.y <= 0 and jump_phase != "mid":
			anim_player.play("Boy_jump_mid", 0.2, lerp(0.5, 1.25, 0.1))
			jump_phase = "mid"
		return
	else:
		if jump_phase in ["start", "mid"]:
			if jump_phase == "start" or anim_player.current_animation == "Boy_jump_mid":
				anim_player.play("Boy_jump_end", 0, lerp(0.1, 1.25, 0.1))
			jump_phase = ""
			if velocity.x < 0.1 or velocity.z < 0.1:
				anim_player.play("Boy_jump_end", 0.3, lerp(0.5, 1.25, 1.0))
		
	var current_velocity := velocity.length()
	if current_velocity > base_speed + 1.5:
		anim_player.play('Boy_run', 0.2, lerp(0.5, 1.25, current_velocity/6))
	elif current_velocity > 0.7 and is_on_floor():
		anim_player.play('Boy_walk', 0.5, lerp(0.5, 1.25, current_velocity/4))
	else:
		anim_player.play('Boy_idle', 0.1, lerp(0.5, 1.25, 1.0))
		
	
	
	
	
	
	
	
	
	
