extends State

var player: Player
var roll_duration: float = 0.0
var elapsed_time: float = 0.0

var is_stuck_under_roof: bool = false

@export var passage_speed: float = 5.0

@export_group("Collision Timing")
@export_range(0.0, 1.0) var restore_start_ratio: float = 0.85 

var default_roll_control: float = 0.0
var fixed_roll_direction: Vector3 = Vector3.ZERO

var is_collider_shrunk: bool = false

func enter() -> void:
	player = entity as Player
	player.is_rolling = true
	player.is_invincible = true
	elapsed_time = 0.0
	is_stuck_under_roof = false
	is_collider_shrunk = false
	
	# Гарантируем, что визуально мы не приседаем на старте
	player.anim_controller.set_crouch_state(false)
	
	default_roll_control = player.roll_control
	player.roll_ability.consume_charge()
	player.clear_roll_passage_motion()
	player.shrink_collider()
	is_collider_shrunk = true
	
	if player.shape_cast:
		player.shape_cast.enabled = true
		player.shape_cast.force_shapecast_update()

	# 1. ОПРЕДЕЛЯЕМ НАПРАВЛЕНИЕ РЫВКА
	var input_vec = player.get_movement_vector()
	if input_vec.length_squared() > 0.01:
		fixed_roll_direction = Vector3(input_vec.x, 0, input_vec.y).normalized()
	else:
		# Если ввода нет - катимся туда, куда смотрит модель
		fixed_roll_direction = -player.global_transform.basis.z.normalized()
		fixed_roll_direction.y = 0

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
	
	var has_roof := is_collider_shrunk and not player.can_restore_collider()

	if has_roof:
		is_stuck_under_roof = true
		player.roll_control = 0.0
		player.anim_controller.set_crouch_state(true)
		player.set_roll_passage_motion(fixed_roll_direction, passage_speed)
		return

	player.clear_roll_passage_motion()

	if is_stuck_under_roof and not has_roof:
		if is_collider_shrunk:
			player.restore_collider()
			is_collider_shrunk = false
		
		player.anim_controller.set_crouch_state(false)
		
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return

	if is_collider_shrunk and progress >= restore_start_ratio:
		if player.can_restore_collider():
			player.restore_collider()
			is_collider_shrunk = false
	
	if elapsed_time < roll_duration:
		if player.input_handler.check_jump():
			if progress >= player.roll_jump_cancel_threshold:
				player.perform_jump()
				transitioned.emit(self, GameConstants.STATE_AIR)
				return
		
		if player.input_handler.is_attack_pressed:
			var can_cancel_attack = progress >= (1.0 - player.attack_roll_cancel_threshold)
			if can_cancel_attack and player.can_attack:
				player.input_handler.check_attack()
				transitioned.emit(self, GameConstants.STATE_ATTACK)
				return
	else:
		transitioned.emit(self, GameConstants.STATE_MOVE)

func exit() -> void:
	player.is_rolling = false
	player.is_invincible = false
	player.root_motion_speed_factor = 1.0
	player.clear_roll_passage_motion()
	
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
