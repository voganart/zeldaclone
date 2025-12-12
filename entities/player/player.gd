class_name Player
extends CharacterBody3D

@onready var _mesh: Node3D = $character
@onready var vfx_pull: Node3D = $"../../VfxPull"

# ============================================================================
# EXPORTS
# ============================================================================
@export_group("Jump")
@export var jump_height: float = 1.25
@export var jump_time_to_peak: float = 0.45
@export var jump_time_to_descent: float = 0.28
@export var air_control: float = 0.05
@export var max_jump_count: int = 3 # Triple Jump after air dash
@export var second_jump_multiplier: float = 1.2

@export_group("Movement")
@export var base_speed: float = 3.0
@export var run_speed: float = 4.5
@export var stop_speed: float = 8.0
@export var acceleration: float = 0.3
@export var rot_speed: float = 5.0
@export var push_force: float = 0.5
@export var roll_push_multiplier: float = 2.5
@export var roll_speed: float = 6.0
@export var roll_control: float = 0.5
@export_range(0.0, 1.0) var roll_jump_cancel_threshold: float = 0.75
@export var buffered_jump_min_time: float = 0.0
@export var buffered_jump_max_time: float = 0.5
@export var auto_run_latch_time: float = 2.0
@export var roll_max_charges: int = 3
@export var roll_cooldown: float = 0.5
@export var roll_recharge_time: float = 3.0
@export var roll_chain_delay: float = 0.0
@export_range(0.0, 1.0) var roll_invincibility_duration: float = 0.6
@export_range(0.0, 1.0) var attack_roll_cancel_threshold: float = 1.0

@export_group("Animation Blending")
@export var walk_run_blend_smoothing: float = 8.0
@export var walk_run_blend_start_speed: float = 3.6
@export var walk_run_blend_end_speed: float = 4.2

@export_group("Combat")
@export var primary_attack_speed: float = 0.8
@export var attack_movement_influense: float = 0.15
@export var attack_cooldown: float = 0.15
@export var combo_window_time: float = 2.0
@export var combo_cooldown_after_combo: float = 0.5
@export var attack_knockback_strength: float = 5.0
@export var attack_knockback_height: float = 2.0
@export var knockback_duration: float = 0.2
@export var running_attack_impulse: float = 3.0
@export var walking_attack_impulse: float = 1.5
@export var idle_attack_impulse: float = 0.5
@export var attack_rotation_influence: float = 0.5

@export_group("Components")
@export var punch_hand_r: Area3D 
@export var punch_hand_l: Area3D 
@onready var health_component: Node = $HealthComponent
@onready var health_label: Label = $"../../Health" # Проверь путь!

# НОВЫЕ КОМПОНЕНТЫ
@onready var air_dash_ability: AirDashAbility = $AirDashAbility
@onready var ground_slam_ability: GroundSlamAbility = $GroundSlamAbility
@onready var anim_player: AnimationPlayer = $character/AnimationPlayer
@onready var attack_timer: Timer = $FirstAttackTimer
@onready var sprint_timer: Timer = $SprintTimer

# ============================================================================
# RUNTIME VARIABLES
# ============================================================================
@onready var jump_velocity: float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity: float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity: float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

var jump_phase := ""
var current_jump_count: int = 0

var air_speed: float
var movement_input: Vector2 = Vector2.ZERO
var is_running: bool = false
var is_trying_to_run: bool = false
var is_stopping: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var can_sprint: bool = true

# Animation Blending
var current_movement_blend: float = 0.0
var target_movement_blend: float = 0.0

# Combo System
var combo_count: int = 0
var current_attack_damage: float = 1.0
var current_attack_knockback_enabled: bool = false
var combo_reset_timer: Timer
var combo_cooldown_active: bool = false
var combo_cooldown_timer: Timer

var is_knockbacked: bool = false
var is_knockback_stun: bool = false
var is_rolling: bool = false
var stun_release_time: float = 0.0
var current_knockback_timer: float = 0.0
# Input buffering
var buffered_jump: bool = false
var buffered_jump_time: float = -1.0

# Shift Logic
var roll_threshold: float = 0.18
var shift_pressed_time: float = 0.0
var is_shift_down: bool = false
var is_auto_running: bool = false
var current_roll_charges: int = 3
var roll_penalty_timer: float = 0.0
var roll_regen_timer: float = 0.0
var is_roll_recharging: bool = false
var roll_interval_timer: float = 0.0
var is_invincible: bool = false

var is_passing_through: bool = false # Used for falling through enemies
var was_on_floor: bool = true

func _ready() -> void:
	# Setup Combo Timer
	combo_reset_timer = Timer.new()
	combo_reset_timer.one_shot = true
	combo_reset_timer.wait_time = combo_window_time
	combo_reset_timer.timeout.connect(_on_combo_timer_timeout)
	add_child(combo_reset_timer)

	if attack_timer:
		attack_timer.one_shot = true
		attack_timer.autostart = false

	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
		# Инициализация лейбла
		_on_health_changed(health_component.get_health())

	current_roll_charges = roll_max_charges

	# Combo cooldown timer
	combo_cooldown_timer = Timer.new()
	combo_cooldown_timer.one_shot = true
	combo_cooldown_timer.wait_time = combo_cooldown_after_combo
	combo_cooldown_timer.timeout.connect(func():
		combo_cooldown_active = false
		can_attack = true
		print("Combo cooldown ended, attacks enabled")
	)
	add_child(combo_cooldown_timer)

func _on_health_changed(new_health: float) -> void:
	if health_label:
		health_label.text = "HP: " + str(ceil(new_health))

func _on_died() -> void:
	print("Player Died!")
	anim_player.play("Boy_death", 0.1)
	set_physics_process(false) # Disable controls

func take_damage(amount: float, knockback_force: Vector3) -> void:
	# Если мы в неуязвимости или в слэме — игнорируем урон
	if ground_slam_ability.is_slamming or is_invincible:
		return
		
	vfx_pull.spawn_effect(0, self.global_position + Vector3(0, 1.5, 0))
	print("PLAYER TOOK DAMAGE:", amount)

	# Наносим урон
	if health_component:
		health_component.take_damage(amount)

	$HitFlash.flash()

	# Применяем отбрасывание
	velocity += knockback_force
	velocity.y = max(velocity.y, 2.0)

	is_knockback_stun = true
	is_knockbacked = true

	current_knockback_timer = knockback_duration

func _input(event):
	if event.is_action_pressed("run") and is_on_floor():
		is_shift_down = true
		shift_pressed_time = 0.0

	if event.is_action_released("run"):
		is_shift_down = false
		if shift_pressed_time <= roll_threshold:
			perform_roll()
		else:
			if not is_auto_running:
				is_trying_to_run = false

		# --- AIR DASH LOGIC DELEGATED TO COMPONENT ---
		if not is_on_floor() and shift_pressed_time <= roll_threshold:
			if air_dash_ability.can_dash():
				air_dash_ability.perform_dash()
				
		shift_pressed_time = 0.0
		
	if Input.is_action_just_pressed("first_attack"):
		# --- GROUND SLAM LOGIC DELEGATED TO COMPONENT ---
		if ground_slam_ability.can_slam():
			ground_slam_ability.start_slam()
		else:
			first_attack(primary_attack_speed)

func first_attack(attack_speed):
	if is_knockback_stun: return
	if ground_slam_ability.is_recovering: return
	# Roll Cancellation Logic
	if is_rolling:
		if _try_cancel_roll_for_attack():
			is_rolling = false
		else:
			return # Block attack

	if not can_attack or not is_on_floor():
		return
		
	is_attacking = true
	can_attack = false
	combo_reset_timer.stop()

	var anim_to_play = ""
	var was_finisher = false

	if combo_count % 3 == 0:
		anim_to_play = "Boy_attack_naked_1"
		current_attack_damage = 1.0
		current_attack_knockback_enabled = true
	elif combo_count % 3 == 1:
		anim_to_play = "Boy_attack_naked_2"
		current_attack_damage = 1.0
		current_attack_knockback_enabled = true
	else:
		anim_to_play = "Boy_attack_naked_3"
		current_attack_damage = 2.0
		current_attack_knockback_enabled = true
		was_finisher = true

	combo_count = (combo_count + 1) % 3

	# Apply momentum
	_apply_attack_momentum()

	var rand_anim_length = anim_player.get_animation(anim_to_play).length if anim_player.has_animation(anim_to_play) else 0.0
	anim_player.play(anim_to_play, 0.0, attack_speed)
	attack_timer.start(rand_anim_length + attack_cooldown)

	# Wait for animation or cancel
	while is_attacking and anim_player.current_animation == anim_to_play:
		await get_tree().process_frame

	is_attacking = false

	if was_finisher:
		combo_cooldown_active = true
		can_attack = false
		if combo_cooldown_timer:
			combo_cooldown_timer.start()
		print("Finisher completed — combo cooldown started")

	combo_reset_timer.start()

func _apply_attack_momentum() -> void:
	var forward = global_transform.basis.z.normalized()
	var impulse = 0.0
	var current_speed_2d = Vector2(velocity.x, velocity.z).length()
	var walk_speed_threshold = base_speed * 0.5
	var has_movement_input = movement_input.length() > 0.1

	if is_running:
		impulse = running_attack_impulse
	elif has_movement_input and current_speed_2d > walk_speed_threshold:
		impulse = walking_attack_impulse
	else:
		impulse = idle_attack_impulse

	if impulse > 0:
		velocity.x += forward.x * impulse
		velocity.z += forward.z * impulse

func _try_cancel_roll_for_attack() -> bool:
	var can_cancel = false
	if roll_jump_cancel_threshold >= 1.0:
		can_cancel = true
	elif roll_jump_cancel_threshold > 0.0:
		if anim_player.current_animation == "Boy_roll":
			var ratio = anim_player.current_animation_position / anim_player.current_animation_length
			if ratio >= (1.0 - roll_jump_cancel_threshold):
				can_cancel = true
	return can_cancel

func _on_combo_timer_timeout() -> void:
	combo_count = 0

func _process(delta):
	_update_roll_timers(delta)
	
	# Shift Update Logic
	if is_shift_down:
		shift_pressed_time += delta
		if shift_pressed_time > roll_threshold and not is_running and not is_rolling:
			perform_run()
		if is_running and shift_pressed_time > auto_run_latch_time:
			is_auto_running = true

	RenderingServer.global_shader_parameter_set("player_position", global_transform.origin)

func _update_roll_timers(delta: float) -> void:
	if is_roll_recharging:
		roll_penalty_timer -= delta
		if roll_penalty_timer <= 0:
			is_roll_recharging = false
			current_roll_charges = roll_max_charges
			print("Rolls Recharged!")
	elif current_roll_charges < roll_max_charges:
		roll_regen_timer -= delta
		if roll_regen_timer <= 0:
			current_roll_charges += 1
			roll_regen_timer = roll_cooldown
			print("Regenerated 1 Roll")

	if roll_interval_timer > 0:
		roll_interval_timer -= delta

func _physics_process(delta: float) -> void:
	# --- 0. STUN TIMER UPDATE (НОВОЕ) ---
	if current_knockback_timer > 0:
		current_knockback_timer -= delta
		if current_knockback_timer <= 0:
			# Таймер вышел — возвращаем управление
			is_knockback_stun = false
			is_knockbacked = false
			current_knockback_timer = 0
	
	# Если Slam активен, он полностью управляет физикой
	if ground_slam_ability.update_physics(delta):
		move_and_slide()
		return

	# Если Dash активен, он управляет скоростью (без гравитации)
	if air_dash_ability.is_dashing:
		# Логика столкновений внутри компонента, здесь просто применяем движение
		move_and_slide()
		return
	
	# --- 2. STANDARD PHYSICS ---
	
	move_logic(delta)
	jump_logic(delta)
	move_and_slide()
	rot_char(delta)
	tilt_character(delta)
	animation_player()
	check_jump_pass_through()
	push_obj()

	# Сброс состояния воздуха
	if is_on_floor():
		air_dash_ability.reset_air_state()

func check_jump_pass_through() -> void:
	# ДОБАВЛЕНО: and not ground_slam_ability.is_recovering
	# Это предотвращает включение режима прохода сквозь врагов во время анимации приземления
	if is_on_floor() and not is_passing_through and not ground_slam_ability.is_slamming and not ground_slam_ability.is_recovering:
		var standing_on_enemy = false
		for i in get_slide_collision_count():
			var c = get_slide_collision(i)
			if c.get_collider().is_in_group("enemies") and c.get_normal().y > 0.5:
				standing_on_enemy = true
				break
		if standing_on_enemy:
			is_passing_through = true
			is_invincible = true
			set_collision_mask_value(3, false)
			velocity.y = -5.0
			global_position.y -= 0.1
			print("Passing through enemy!")
			
	if is_on_floor() and is_passing_through:
		is_passing_through = false
		is_invincible = false # ЯВНО выключаем неуязвимость при выходе
		set_collision_mask_value(3, true)
		print("Re-enabled enemy collisions.")

func perform_roll() -> void:
	if is_knockback_stun: return
	if ground_slam_ability.is_recovering: return 
	if not is_on_floor() or is_rolling or is_knockbacked: return
	if roll_interval_timer > 0: return
	if is_roll_recharging: return
	if current_roll_charges <= 0: return

	current_roll_charges -= 1
	if current_roll_charges <= 0:
		is_roll_recharging = true
		roll_penalty_timer = roll_recharge_time
		roll_regen_timer = 0.0
	else:
		if roll_regen_timer <= 0: roll_regen_timer = roll_cooldown

	# Interrupt Attack
	if is_attacking:
		if _try_cancel_attack_for_roll():
			is_attacking = false
			if not combo_cooldown_active: can_attack = true
		else:
			return

	var was_running = is_trying_to_run or is_auto_running
	is_rolling = true
	is_running = false
	is_stopping = false

	if roll_invincibility_duration > 0:
		is_invincible = true
		get_tree().create_timer(anim_player.get_animation("Boy_roll").length * roll_invincibility_duration).timeout.connect(func(): is_invincible = false)

	var forward = global_transform.basis.z.normalized()
	var current_roll_speed = roll_speed + (run_speed * 0.8 if was_running else 0.0)

	velocity.x = forward.x * current_roll_speed
	velocity.z = forward.z * current_roll_speed

	anim_player.play("Boy_roll", 0, 1.0)
	var rollout_time = anim_player.get_animation("Boy_roll").length * 0.75
	await get_tree().create_timer(rollout_time).timeout

	is_rolling = false

	if buffered_jump:
		_process_buffered_jump()

	if roll_chain_delay > 0:
		roll_interval_timer = roll_chain_delay

	if was_running:
		is_running = true

func _try_cancel_attack_for_roll() -> bool:
	var can_cancel = false
	if attack_roll_cancel_threshold >= 1.0:
		can_cancel = true
	elif attack_roll_cancel_threshold > 0.0:
		var current_anim = anim_player.current_animation
		if current_anim.begins_with("Boy_attack"):
			var ratio = anim_player.current_animation_position / anim_player.current_animation_length
			if ratio >= (1.0 - attack_roll_cancel_threshold):
				can_cancel = true
	return can_cancel

func _process_buffered_jump() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if buffered_jump_time >= 0.0:
		var dt = now - buffered_jump_time
		if dt >= buffered_jump_min_time and dt <= buffered_jump_max_time:
			_execute_buffered_jump()
	buffered_jump = false
	buffered_jump_time = -1.0

func perform_run() -> void:
	if is_rolling or is_attacking: return
	is_trying_to_run = true

func push_obj():
	var current_push_force = push_force * (roll_push_multiplier if is_rolling else 1.0)
	for i in range(get_slide_collision_count()):
		var c = get_slide_collision(i)
		var collider = c.get_collider()
		if collider is RigidBody3D:
			collider.apply_central_impulse(-c.get_normal() * current_push_force)
		if collider is CharacterBody3D and collider.has_method("receive_push"):
			collider.receive_push(-c.get_normal() * current_push_force)

func move_logic(delta):
	# Movement blocked during abilities
	if ground_slam_ability.is_slamming or is_knockback_stun: return

	movement_input = Input.get_vector('left', "right", "up", "down")
	var velocity_2d = Vector2(velocity.x, velocity.z)
	var is_airborne = not is_on_floor()
	var control = 1.0 if not is_airborne else clamp(air_control, 0.0, 1.0)

	# Air Dash handled by component update_physics, but here we safeguard
	if air_dash_ability.is_dashing: return

	if movement_input == Vector2.ZERO:
		is_running = false
		is_trying_to_run = false
		is_auto_running = false

	var speed_2d = Vector2(velocity.x, velocity.z).length()
	var run_speed_threshold = lerp(base_speed, run_speed, 0.7)

	if is_trying_to_run or is_auto_running:
		is_running = (speed_2d >= run_speed_threshold)
	else:
		is_running = false

	var current_speed = run_speed if (is_trying_to_run or is_auto_running) else base_speed
	if is_airborne: current_speed = air_speed
	elif is_rolling: current_speed = roll_speed

	if movement_input != Vector2.ZERO:
		var input_factor = 1.0 if not is_attacking else attack_movement_influense
		var final_control = control

		if is_rolling:
			var current_mag = velocity_2d.length()
			var forward = global_transform.basis.z.normalized()
			velocity_2d = Vector2(forward.x, forward.z) * current_mag
		else:
			velocity_2d = velocity_2d.lerp(movement_input * current_speed * input_factor, acceleration * final_control)
	else:
		if not is_rolling:
			velocity_2d = velocity_2d.move_toward(Vector2.ZERO, stop_speed * delta)

	velocity.x = velocity_2d.x
	velocity.z = velocity_2d.y

func jump_logic(delta):
	var currently_on_floor = is_on_floor()
	if currently_on_floor and not was_on_floor:
		current_jump_count = 0
		jump_phase = ""
	was_on_floor = currently_on_floor

	if Input.is_action_just_pressed('jump'):
		if is_knockback_stun: return
		if ground_slam_ability.is_recovering: return
		if is_rolling:
			if _try_cancel_roll_for_attack(): # Reusing logic, technically same threshold
				is_rolling = false
			else:
				buffered_jump = true
				buffered_jump_time = Time.get_ticks_msec() / 1000.0
				return

		var can_jump = false
		if is_on_floor() and current_jump_count == 0: can_jump = true
		elif current_jump_count > 0 and current_jump_count < 2: can_jump = true
		
		# --- TRIPLE JUMP CHECK VIA COMPONENT ---
		elif current_jump_count == 2 and air_dash_ability.bonus_jump_granted:
			can_jump = true

		if can_jump:
			_execute_jump()

	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
	
	# Gravity disabled during abilities
	if air_dash_ability.is_dashing or ground_slam_ability.is_slamming:
		return

	velocity.y -= gravity * delta

func _execute_jump() -> void:
	if current_jump_count > 0: jump_phase = ""
	var jump_multiplier = second_jump_multiplier if current_jump_count == 1 else 1.0
	velocity.y = - jump_velocity * jump_multiplier
	current_jump_count += 1
	air_speed = Vector2(velocity.x, velocity.z).length()

func _execute_buffered_jump() -> void:
	# Same logic as input jump but bypasses buffering check
	var can_jump = false
	if is_on_floor() and current_jump_count == 0: can_jump = true
	elif current_jump_count > 0 and current_jump_count < 2: can_jump = true
	elif current_jump_count == 2 and air_dash_ability.bonus_jump_granted: can_jump = true

	if can_jump: _execute_jump()

func rot_char(delta):
	if is_knockbacked or is_knockback_stun or ground_slam_ability.is_slamming: return

	var current_rot_speed = 0.0 if is_stopping else rot_speed
	if is_rolling: current_rot_speed = rot_speed * roll_control
	if is_attacking: current_rot_speed = rot_speed * attack_rotation_influence

	var vel_2d = Vector2(velocity.x, -velocity.z)
	if is_rolling and movement_input != Vector2.ZERO:
		vel_2d = Vector2(movement_input.x, -movement_input.y)

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
	if is_attacking or is_rolling or air_dash_ability.is_dashing or ground_slam_ability.is_slamming:
		return
	# Also check if slam is playing end anim
	if ground_slam_ability._playing_end_anim: return

	var speed_2d := Vector2(velocity.x, velocity.z).length()
	var has_input := Input.get_vector("left", "right", "up", "down").length() > 0
	var min_walk_speed := 0.5

	if not is_on_floor():
		is_stopping = false
		if jump_phase == "" and velocity.y > 0.5:
			jump_phase = "start"
			anim_player.play("Boy_jump_start", 0.1, 1.0)
		elif jump_phase == "start" and velocity.y <= 0.1:
			jump_phase = "mid"
			var mid_speed = clamp(-velocity.y / 15.0, 0.5, 2.5)
			anim_player.play("Boy_jump_mid", 0.1, mid_speed)
		return
	else:
		if jump_phase in ["start", "mid"]:
			anim_player.play("Boy_jump_end", 0.1, 1.0)
			jump_phase = ""

	if has_input and speed_2d > min_walk_speed:
		is_stopping = false
		var blend_factor = calculate_walk_run_blend(speed_2d)
		apply_movement_animation_blend(blend_factor, speed_2d)
	else:
		if speed_2d > 3.5:
			if not is_stopping:
				is_stopping = true
				anim_player.play("Boy_stopping", 0.5, 0.1)
		else:
			is_stopping = false
			play_with_random_offset("Boy_idle", 0.2)

func _on_first_attack_timer_timeout() -> void:
	if not combo_cooldown_active:
		can_attack = true

func _on_sprint_timer_timeout():
	can_sprint = true

func _check_attack_hit() -> void:
	var hits_found = false
	if punch_hand_r and _check_single_hand_hit(punch_hand_r): hits_found = true
	if not hits_found and punch_hand_l: _check_single_hand_hit(punch_hand_l)

func _check_single_hand_hit(hand: Area3D) -> bool:
	for body in hand.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			punch_collision(body, hand)
			return true
	return false

func punch_collision(body: Node3D, hand: Area3D) -> void:
	if not is_attacking: return
	if not body.is_in_group("enemies"): return

	var direction = (body.global_transform.origin - hand.global_transform.origin).normalized()
	if body.has_method("take_damage"):
		if current_attack_knockback_enabled:
			var knockback_vec = direction * attack_knockback_strength
			knockback_vec.y = attack_knockback_height
			body.take_damage(current_attack_damage, knockback_vec)
		else:
			body.take_damage(current_attack_damage, Vector3.ZERO)

func play_with_random_offset(anim_name: String, blend: float = -1.0, speed: float = 1.0) -> void:
	if anim_player.current_animation == anim_name:
		anim_player.play(anim_name, blend, speed)
		return
	anim_player.play(anim_name, blend, speed)
	var anim_len = anim_player.current_animation_length
	if anim_len > 0: anim_player.seek(randf() * anim_len)

func calculate_walk_run_blend(speed: float) -> float:
	var blend = inverse_lerp(walk_run_blend_start_speed, walk_run_blend_end_speed, speed)
	return clamp(blend, 0.0, 1.0)

func apply_movement_animation_blend(blend: float, speed: float) -> void:
	target_movement_blend = blend
	current_movement_blend = lerp(current_movement_blend, target_movement_blend, walk_run_blend_smoothing * get_physics_process_delta_time())
	if current_movement_blend < 0.5:
		var walk_speed_scale = lerp(0.0, 1.25, speed / base_speed)
		play_with_random_offset("Boy_walk", 0.2, walk_speed_scale)
	else:
		var run_speed_scale = lerp(0.5, 1.25, speed / run_speed)
		play_with_random_offset("Boy_run", 0.2, run_speed_scale)
