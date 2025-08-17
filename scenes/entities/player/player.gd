extends CharacterBody3D
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

func _physics_process(delta: float) -> void:
	move_logic(delta)
	jump_logic(delta)
	rot_char(delta)
	tilt_character(delta)
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
	var velocity_2d = Vector2(velocity.x, velocity.z)
	var is_airborne = not is_on_floor()
	var control = 1.0 if not is_airborne else clamp(air_control, 0.0, 1.0)  # 0 = нет управления, 1 = полное

	if movement_input == Vector2.ZERO:
		is_running = false
		
	var current_speed = run_speed if is_running else base_speed
	if is_airborne:
		current_speed = air_speed  # сохраняем текущую скорость на воздухе

	if movement_input != Vector2.ZERO:
		# Лerp с учетом контроля в воздухе
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
		var target_angle = vel_2d.angle() + PI / 2
		rotation.y = lerp_angle(rotation.y, target_angle, rot_speed * delta)

func tilt_character(delta):
	var tilt_angle = 15 if is_running else 5
	var move_vec = Vector3(velocity.x, 0, velocity.z)
	var local_move = global_transform.basis.inverse() * move_vec
	var target_tilt = clamp(-local_move.x, -1, 1) * deg_to_rad(tilt_angle)
	_mesh.rotation.z = lerp_angle(rotation.z, target_tilt, 15 * delta)

var is_stopping := false

func animation_player():
	var speed_2d := Vector2(velocity.x, velocity.z).length()
	var has_input := Input.get_vector("left","right","up","down").length() > 0

	# Прыжки
	if not is_on_floor():
		is_stopping = false
		if velocity.y > 0.5 and jump_phase != "start":
			anim_player.play("Boy_jump_start", 0.1)
			jump_phase = "start"
		elif velocity.y <= 0.1 and jump_phase != "mid":
			anim_player.play("Boy_jump_mid", 0.2, lerp(0.5, 1.25, 0.1))
			jump_phase = "mid"
		return
	else:
		if jump_phase in ["start", "mid"]:
			anim_player.play("Boy_jump_end", 0, lerp(0.5, 1.25, 0.1))
			jump_phase = ""

	# Движение по земле
	if has_input:
		is_stopping = false
		if speed_2d > lerp(base_speed, run_speed, 0.5):
			anim_player.play("Boy_run", 0.1, lerp(0.5, 1.25, speed_2d/run_speed))
		elif speed_2d > 0.2:
			anim_player.play("Boy_walk", 0.3, lerp(0.5, 1.25, speed_2d/base_speed))
	else:
		# торможение
		if speed_2d > 3.6:
			if not is_stopping:
				anim_player.play("Boy_stopping", 0.2, 0.1)
				is_stopping = true
		else:
			is_stopping = false
			anim_player.play("Boy_idle", 0.5)
