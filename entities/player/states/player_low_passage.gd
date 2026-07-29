extends State

var player: Player

@export var movement_speed: float = 1.5
@export_range(0.1, 1.0) var animation_speed: float = 0.55
@export var clearance_hold_time: float = 0.1
@export_range(0.01, 0.49) var exit_phase_window: float = 0.12

var loop_elapsed: float = 0.0
var loop_duration: float = 1.0
var clearance_elapsed: float = 0.0
var exit_requested: bool = false

func enter() -> void:
	player = entity as Player
	player.is_rolling = false
	player.is_invincible = false
	loop_elapsed = 0.0
	clearance_elapsed = 0.0
	exit_requested = false

	if player.anim_player.has_animation(GameConstants.ANIM_PLAYER_ROLL_CROUCH):
		var loop_animation := player.anim_player.get_animation(
			GameConstants.ANIM_PLAYER_ROLL_CROUCH
		)
		loop_duration = maxf(loop_animation.length, 0.001)
	else:
		loop_duration = 1.0

	player.shrink_collider()
	player.anim_controller.set_crouch_state(true)
	player.anim_controller.set_playback_speed(animation_speed)
	if player.shape_cast:
		player.shape_cast.enabled = true

func physics_update(delta: float) -> void:
	loop_elapsed += delta * animation_speed
	player.apply_gravity(delta)

	if player.can_restore_collider():
		clearance_elapsed += delta
		exit_requested = clearance_elapsed >= clearance_hold_time
	else:
		clearance_elapsed = 0.0
		exit_requested = false

	if exit_requested and _is_safe_exit_phase():
		if not player.can_restore_collider():
			clearance_elapsed = 0.0
			exit_requested = false
		else:
			player.restore_collider()
			var next_state := GameConstants.STATE_MOVE \
				if player.is_on_floor() else GameConstants.STATE_AIR
			transitioned.emit(self, next_state)
			return

	var input_vec := player.get_movement_vector()
	player.apply_movement_velocity(delta, input_vec, movement_speed)
	player.rot_char(delta)
	player.tilt_character(delta)

func _is_safe_exit_phase() -> bool:
	var normalized_phase := fposmod(loop_elapsed, loop_duration) / loop_duration
	return normalized_phase <= exit_phase_window \
		or normalized_phase >= 1.0 - exit_phase_window

func exit() -> void:
	player.anim_controller.set_playback_speed(1.0)
	if player.can_restore_collider():
		player.restore_collider()
		player.anim_controller.set_crouch_state(false)
	if player.shape_cast:
		player.shape_cast.enabled = false
