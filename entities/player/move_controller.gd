extends Node

@export var _mesh: Node3D
@export var player: CharacterBody3D
@export var anim_controller: Node
@export var player_stats: Node


func _input(event):
	if event.is_action_pressed("run") and player.is_on_floor() and player_stats.can_sprint:
		if player_stats.run_toggle_mode:
			player_stats.is_running = !player_stats.is_running
		else:
			player_stats.is_running = true
		player_stats.can_sprint = false
		player_stats.sprint_timer.start()
	if event.is_action_released("run") and not player_stats.run_toggle_mode:
		player_stats.is_running = false
		
func move_logic(delta):
	player_stats.movement_input = Input.get_vector('left',"right", "up", "down")
	var velocity_2d = Vector2(player.velocity.x, player.velocity.z)
	var is_airborne = not player.is_on_floor()
	var control = 1.0 if not is_airborne else clamp(player_stats.air_control, 0.0, 1.0)

	if player_stats.movement_input == Vector2.ZERO:
		player_stats.is_running = false

	var current_speed = player_stats.run_speed if player_stats.is_running else player_stats.base_speed
	if is_airborne:
		current_speed = player_stats.air_speed  # сохраняем текущую скорость на воздухе

	if player_stats.movement_input != Vector2.ZERO:
		var input_factor = 1.0 if not anim_controller.is_attacking else player_stats.attack_movement_influense
		velocity_2d = velocity_2d.lerp(player_stats.movement_input * current_speed * input_factor, player_stats.acceleration * control)
	else:
		velocity_2d = velocity_2d.move_toward(Vector2.ZERO, player_stats.stop_speed * delta)

	player.velocity.x = velocity_2d.x
	player.velocity.z = velocity_2d.y

func jump_logic(delta):
	if Input.is_action_just_pressed('jump') and player.is_on_floor():
		player.velocity.y = -player_stats.jump_velocity
		player_stats.air_speed = Vector2(player.velocity.x, player.velocity.z).length()
	var gravity = player_stats.jump_gravity if player.velocity.y > 0.0 else player_stats.fall_gravity
	player.velocity.y -= gravity * delta

func rot_char(delta):
	if anim_controller.is_attacking: return
	var current_rot_speed = 0.0 if player_stats.is_stopping else player_stats.rot_speed
	var vel_2d = Vector2(player.velocity.x, -player.velocity.z)
	if vel_2d.length_squared() > 0.001:
		var target_angle = vel_2d.angle() + PI / 2
		player.rotation.y = lerp_angle(player.rotation.y, target_angle, current_rot_speed * delta)

func tilt_character(delta):
	if anim_controller.is_attacking: return
	var tilt_angle = 10 if player_stats.is_running and player.velocity.length() > player_stats.base_speed + 1 else 3
	var move_vec = Vector3(player.velocity.x, 0, player.velocity.z)
	var local_move = player.global_transform.basis.inverse() * move_vec
	var target_tilt = clamp(-local_move.x, -1, 1) * deg_to_rad(tilt_angle)
	_mesh.rotation.z = lerp_angle(_mesh.rotation.z, target_tilt, 15 * delta)

func _on_sprint_timer_timeout():
	player_stats.can_sprint = true
