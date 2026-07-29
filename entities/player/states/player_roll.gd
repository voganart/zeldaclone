extends State

var player: Player
var roll_duration: float = 0.0
var elapsed_time: float = 0.0

var default_roll_control: float = 0.0
var is_collider_shrunk: bool = false

func enter() -> void:
	player = entity as Player
	player.is_rolling = true
	player.is_invincible = true
	elapsed_time = 0.0
	is_collider_shrunk = false
	
	# Гарантируем, что визуально мы не приседаем на старте
	player.anim_controller.set_crouch_state(false)
	
	default_roll_control = player.roll_control
	player.roll_ability.consume_charge()
	player.shrink_collider()
	is_collider_shrunk = true
	
	if player.shape_cast:
		player.shape_cast.enabled = true
		player.shape_cast.force_shapecast_update()

	player.trigger_roll()
	
	if player.anim_player.has_animation(GameConstants.ANIM_PLAYER_ROLL):
		roll_duration = player.anim_player.get_animation(GameConstants.ANIM_PLAYER_ROLL).length
	else:
		roll_duration = 0.6
	
	player.sfx_roll.play_random()
	
	var current_speed_2d = Vector2(player.velocity.x, player.velocity.z).length()
	var speed_factor = clamp(current_speed_2d / player.run_speed, 0.0, 1.0)
	player.root_motion_speed_factor = lerp(player.roll_min_speed, player.roll_max_speed, speed_factor)

func physics_update(delta: float) -> void:
	elapsed_time += delta
	var progress = clamp(elapsed_time / roll_duration, 0.0, 1.0)
	
	if elapsed_time < roll_duration:
		var can_leave_roll := player.can_restore_collider()

		if can_leave_roll and player.input_handler.check_jump():
			if progress >= player.roll_jump_cancel_threshold:
				player.perform_jump()
				transitioned.emit(self, GameConstants.STATE_AIR)
				return
		
		if can_leave_roll and player.input_handler.is_attack_pressed:
			var can_cancel_attack = progress >= (1.0 - player.attack_roll_cancel_threshold)
			if can_cancel_attack and player.can_attack:
				player.input_handler.check_attack()
				transitioned.emit(self, GameConstants.STATE_ATTACK)
				return
	else:
		if player.can_restore_collider():
			player.restore_collider()
			is_collider_shrunk = false
			transitioned.emit(self, GameConstants.STATE_MOVE)
		else:
			transitioned.emit(self, GameConstants.STATE_LOW_PASSAGE)

func exit() -> void:
	player.is_rolling = false
	player.is_invincible = false
	player.root_motion_speed_factor = 1.0
	
	if is_collider_shrunk and player.can_restore_collider():
		player.restore_collider()
		is_collider_shrunk = false
	
	player.anim_controller.set_crouch_state(false)
	
	if player.shape_cast:
		player.shape_cast.enabled = false
		
	player.roll_control = default_roll_control
	
	var input_vec = player.input_handler.move_vector
	if input_vec.length() > 0.01:
		if player.is_trying_to_run:
			player.current_movement_blend = player.blend_value_run
		else:
			player.current_movement_blend = player.blend_value_walk
		player.set_locomotion_blend(player.current_movement_blend) 
