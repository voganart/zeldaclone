extends State

var player: Player

@export var movement_speed: float = 1.5
@export_range(0.1, 1.0) var animation_speed: float = 0.55

func enter() -> void:
	player = entity as Player
	player.is_rolling = false
	player.is_invincible = false
	player.shrink_collider()
	player.anim_controller.set_crouch_state(true)
	player.anim_controller.set_playback_speed(animation_speed)
	if player.shape_cast:
		player.shape_cast.enabled = true

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)

	if player.can_restore_collider():
		player.restore_collider()
		var next_state := GameConstants.STATE_MOVE \
			if player.is_on_floor() else GameConstants.STATE_AIR
		transitioned.emit(self, next_state)
		return

	var input_vec := player.get_movement_vector()
	player.apply_movement_velocity(delta, input_vec, movement_speed)
	player.rot_char(delta)
	player.tilt_character(delta)

func exit() -> void:
	player.anim_controller.set_playback_speed(1.0)
	if player.can_restore_collider():
		player.restore_collider()
		player.anim_controller.set_crouch_state(false)
	if player.shape_cast:
		player.shape_cast.enabled = false
