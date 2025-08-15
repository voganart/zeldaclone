extends CharacterBody3D

@export var camera_follow_delay : float = 0.1

#jump
@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.3

@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

@export var base_speed: float = 5.0
@export var run_speed: float = 8.0
@export var stop_speed: float = 15.0
@export var acceleration: float = 0.1
var air_speed: float
var movement_input: Vector2 = Vector2.ZERO


func _physics_process(delta: float) -> void:
	move_logic(delta)
	jump_logic(delta)
	move_and_slide()
	#камера следует за игроком
	$CameraController.position = lerp($CameraController.position, position, camera_follow_delay)


func move_logic(delta):
	movement_input = Input.get_vector('left',"right", "up", "down")
	var velocity_2d = Vector2(velocity.x, velocity.z)
	var is_airborne = not is_on_floor()
	var current_speed = air_speed if is_airborne else (run_speed if Input.is_action_pressed("run") else base_speed)
	
	if movement_input != Vector2.ZERO:
		velocity_2d = velocity_2d.lerp(movement_input * current_speed, acceleration)
		#velocity_2d += movement_input * speed * delta
		#velocity_2d = velocity_2d.limit_length(speed)
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
