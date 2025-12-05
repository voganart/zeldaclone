extends CharacterBody3D
@onready var _mesh: Node3D = $character

# jump
@export var jump_height: float = 1.25
@export var jump_time_to_peak: float = 0.45
@export var jump_time_to_descent: float = 0.28
@export var air_control: float = 0.05

@onready var jump_velocity: float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity: float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity: float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0
var jump_phase := "" # '' / 'start' / 'mid'

@onready var anim_player: AnimationPlayer = $character/AnimationPlayer
@export var base_speed: float = 3.0
@export var run_speed: float = 4.5
@export var stop_speed: float = 8.0
@export var acceleration: float = 0.3
@export var rot_speed: float = 5.0
var air_speed: float
var movement_input: Vector2 = Vector2.ZERO
var is_running: bool = false
var is_stopping: bool = false
var is_attacking: bool = false
@export var run_toggle_mode: bool = true
@onready var attack_timer: Timer = $FirstAttackTimer
@onready var sprint_timer: Timer = $SprintTimer
@export var primary_attack_speed: float = 0.8
@export var attack_movement_influense: float = 0.15
@export var attack_cooldown: float = 0.15
var can_attack: bool = true
var can_sprint: bool = true
@onready var punch_hand_r: Area3D = $character/root/Skeleton3D/hand_r/punch_hand_r
@onready var punch_hand_l: Area3D = $character/root/Skeleton3D/hand_l/punch_hand_l
@onready var first_attack_area: Area3D = $FirstAttackArea
var primary_naked_attacks: Array = ["Boy_attack_naked_1", "Boy_attack_naked_2", "Boy_attack_naked_3", "Boy_attack_naked_1", "Boy_attack_naked_3", "Boy_attack_naked_1", "Boy_attack_naked_3"]
@export var push_force: float = 0.5
@export var combo_window_time: float = 2.0

# Combo System
var combo_count: int = 0
var current_attack_damage: float = 1.0
var current_attack_knockback_enabled: bool = false
var combo_reset_timer: Timer

# Components
@onready var health_component: Node = $HealthComponent
@onready var health_label: Label = $"../../Health" # Assuming the user named the label "Health"

func _ready() -> void:
	# Setup Combo Timer
	combo_reset_timer = Timer.new()
	combo_reset_timer.one_shot = true
	combo_reset_timer.wait_time = combo_window_time
	combo_reset_timer.timeout.connect(_on_combo_timer_timeout)
	add_child(combo_reset_timer)

	# Ensure timer behaves as one-shot
	if attack_timer:
		attack_timer.one_shot = true
		attack_timer.autostart = false
		# убедись, что сигнал подключен в редакторе или программно
		# attack_timer.timeout.connect(_on_first_attack_timer_timeout)
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
		_on_health_changed(health_component.get_health())

func _on_health_changed(new_health: float) -> void:
	if health_label:
		health_label.text = "HP: " + str(ceil(new_health))

func _on_died() -> void:
	print("Player Died!")
	# Handle death logic here

func take_damage(amount: float, knockback_force: Vector3) -> void:
	if health_component:
		health_component.take_damage(amount)
	velocity += knockback_force
	velocity.y = max(velocity.y, 2.0)

func _input(event):
	if event.is_action_pressed("run") and is_on_floor() and can_sprint:
		if run_toggle_mode:
			is_running = !is_running
		else:
			is_running = true
		can_sprint = false
		sprint_timer.start()
	if event.is_action_released("run") and not run_toggle_mode:
		is_running = false
	if Input.is_action_just_pressed("first_attack"):
		first_attack(primary_attack_speed)

func first_attack(attack_speed):
	if not can_attack or not is_on_floor():
		return
	is_attacking = true
	can_attack = false
	combo_reset_timer.stop() # Stop reset timer while attacking

	var anim_to_play = ""
	
	# Determine Attack based on Combo Count
	if combo_count == 0 or combo_count == 1:
		# Attack 1 or 2: Random light attack
		anim_to_play = ["Boy_attack_naked_1", "Boy_attack_naked_2"].pick_random()
		current_attack_damage = 1.0
		current_attack_knockback_enabled = false
	elif combo_count == 2:
		# Attack 3: Heavy finisher
		anim_to_play = "Boy_attack_naked_3"
		current_attack_damage = 2.0
		current_attack_knockback_enabled = true
	
	# Increment Combo
	combo_count += 1
	if combo_count > 2:
		combo_count = 0 # Reset after 3rd hit

	var rand_anim_length = anim_player.get_animation(anim_to_play).length if anim_player.has_animation(anim_to_play) else 0.0

	# Start animation and timer that covers animation + cooldown
	anim_player.play(anim_to_play, 0, attack_speed)
	attack_timer.start(rand_anim_length + attack_cooldown)

	# Wait for animation to finish to allow movement/rotations again
	await anim_player.animation_finished
	is_attacking = false
	
	# Start combo reset timer
	combo_reset_timer.start()
	# NOTE: can_attack will be set true only when attack_timer times out (см. _on_first_attack_timer_timeout)

func _on_combo_timer_timeout() -> void:
	combo_count = 0

func _process(_delta):
	RenderingServer.global_shader_parameter_set("player_position", global_transform.origin)

func _physics_process(delta: float) -> void:
	move_logic(delta)
	jump_logic(delta)
	rot_char(delta)
	tilt_character(delta)
	animation_player()
	move_and_slide()
	push_obj()

func push_obj():
	for i in range(get_slide_collision_count()):
		var c = get_slide_collision(i)
		var collider = c.get_collider()
		if collider is RigidBody3D:
			collider.apply_central_impulse(-c.get_normal() * push_force)
		if collider is CharacterBody3D and collider.has_method("receive_push"):
			collider.receive_push(-c.get_normal() * push_force)

func move_logic(delta):
	movement_input = Input.get_vector('left', "right", "up", "down")
	var velocity_2d = Vector2(velocity.x, velocity.z)
	var is_airborne = not is_on_floor()
	var control = 1.0 if not is_airborne else clamp(air_control, 0.0, 1.0)

	if movement_input == Vector2.ZERO:
		if not run_toggle_mode:
			is_running = false

	var current_speed = run_speed if is_running else base_speed
	if is_airborne:
		current_speed = air_speed

	if movement_input != Vector2.ZERO:
		var input_factor = 1.0 if not is_attacking else attack_movement_influense
		velocity_2d = velocity_2d.lerp(movement_input * current_speed * input_factor, acceleration * control)
	else:
		velocity_2d = velocity_2d.move_toward(Vector2.ZERO, stop_speed * delta)

	velocity.x = velocity_2d.x
	velocity.z = velocity_2d.y

func jump_logic(delta):
	if Input.is_action_just_pressed('jump') and is_on_floor():
		velocity.y = - jump_velocity
		air_speed = Vector2(velocity.x, velocity.z).length()
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y -= gravity * delta

func rot_char(delta):
	if is_attacking: return
	var current_rot_speed = 0.0 if is_stopping else rot_speed
	var vel_2d = Vector2(velocity.x, -velocity.z)
	if vel_2d.length_squared() > 0.001:
		var target_angle = vel_2d.angle() + PI / 2
		rotation.y = lerp_angle(rotation.y, target_angle, current_rot_speed * delta)

func tilt_character(delta):
	if is_attacking: return
	var tilt_angle = 10 if is_running and velocity.length() > base_speed + 1 else 3
	var move_vec = Vector3(velocity.x, 0, velocity.z)
	var local_move = global_transform.basis.inverse() * move_vec
	var target_tilt = clamp(-local_move.x, -1, 1) * deg_to_rad(tilt_angle)
	_mesh.rotation.z = lerp_angle(_mesh.rotation.z, target_tilt, 15 * delta)

func animation_player():
	if is_attacking: return
	var speed_2d := Vector2(velocity.x, velocity.z).length()
	var has_input := Input.get_vector("left", "right", "up", "down").length() > 0

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
			anim_player.play("Boy_run", 0.3, lerp(0.5, 1.25, speed_2d / run_speed))
		elif speed_2d > 0.2:
			anim_player.play("Boy_walk", 0.3, lerp(0.5, 1.25, speed_2d / base_speed))
	else:
		# торможение
		if speed_2d > 3.2:
			if not is_stopping:
				is_stopping = true
				anim_player.play("Boy_stopping", 0.2, 0.1)
		else:
			is_stopping = false
			anim_player.play("Boy_idle", 0.5)

func _on_first_attack_timer_timeout() -> void:
	# Timer закончился — разрешаем новую атаку (кулдаун завершён)
	can_attack = true
	# убедимся, что флаг is_attacking уже сброшен отдельным await'ом после окончания анимации

func _on_sprint_timer_timeout():
	can_sprint = true

func _on_punch_hand_r_body_entered(body: Node3D) -> void:
	punch_collision(body, punch_hand_r)

func _on_punch_hand_l_body_entered(body: Node3D) -> void:
	punch_collision(body, punch_hand_l)

func punch_collision(body: Node3D, hand: Area3D) -> void:
	if not is_attacking:
		return
	if not body.is_in_group("enemies"):
		return
	if first_attack_area and body in first_attack_area.get_overlapping_bodies():
		var direction = (body.global_transform.origin - hand.global_transform.origin).normalized()
		
		# Apply damage with current specs
		if body.has_method("take_damage"):
			# If 3rd hit, send extra knockback if supported
			if current_attack_knockback_enabled:
				# Assumes enemy has take_damage(amount, knockback_vec)
				# Push slightly up + away
				var knockback_vec = direction * 5.0 # Stronger push
				knockback_vec.y = 2.0
				body.take_damage(current_attack_damage, knockback_vec)
			else:
				# Standard hit (no knockback)
				body.take_damage(current_attack_damage, Vector3.ZERO)
