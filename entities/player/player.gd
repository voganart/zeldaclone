extends CharacterBody3D
@onready var _mesh: Node3D = $character

# jump
@export_group("Jump")
@export var jump_height: float = 1.25
@export var jump_time_to_peak: float = 0.45
@export var jump_time_to_descent: float = 0.28
@export var air_control: float = 0.05
@export var max_jump_count: int = 3 # Triple Jump after air dash
@export var second_jump_multiplier: float = 1.2
@export_group("Ground Slam")
@export var slam_damage: float = 1.0
@export var slam_radius: float = 2.0
@export var slam_descent_speed: float = 20.0
@export var slam_knockback: float = 0.3
@export var slam_cooldown: float = 2.0 # Cooldown between slams
@export var slam_windup_delay: float = 0.5 # Delay before descent starts
@export var slam_acceleration: float = 50.0 # Acceleration during descent (exponential speed increase)
@export var slam_min_height: float = 3.0 # Minimum height from ground to execute slam

@export_group("Movement")
@export var base_speed: float = 3.0
@export var run_speed: float = 4.5
@export var stop_speed: float = 8.0
@export var acceleration: float = 0.3
@export var rot_speed: float = 5.0
@export var push_force: float = 0.5
@export var roll_push_multiplier: float = 2.5 # Multiplier for push force during roll
@export var roll_speed: float = 6.0
@export var roll_control: float = 0.5
@export_range(0.0, 1.0) var roll_jump_cancel_threshold: float = 0.75 # 0 = finish roll first, 1 = interrupt anytime (affects jump and attack)
@export var auto_run_latch_time: float = 2.0
@export var roll_max_charges: int = 3
@export var roll_cooldown: float = 0.5 # Time to regenerate 1 charge
@export var roll_recharge_time: float = 3.0 # Penalty time if depleted
@export var roll_chain_delay: float = 0.0 # Delay after roll completes before next roll allowed
@export_range(0.0, 1.0) var roll_invincibility_duration: float = 0.6 # Portion of roll with i-frames (0 = disabled, 1 = full duration)
@export_range(0.0, 1.0) var attack_roll_cancel_threshold: float = 1.0 # 0 = finish attack first, 1 = interrupt anytime

@export_group("Animation Blending")
@export var walk_run_blend_smoothing: float = 8.0 # How fast blend transitions occur
@export var walk_run_blend_start_speed: float = 3.6 # Speed where blending begins (default: base_speed * 1.2)
@export var walk_run_blend_end_speed: float = 4.2 # Speed where run animation takes over (default: run_speed * 0.93)

@export_group("Air Dash")
@export var air_dash_speed: float = 15.0 # Speed of air dash (horizontal burst)
@export var air_dash_distance: float = 3.0 # Distance to travel horizontally before gravity re-enables
@export var air_dash_cooldown: float = 1.0 # Cooldown between air dashes

@export_group("Combat")
@export var primary_attack_speed: float = 0.8
@export var attack_movement_influense: float = 0.15
@export var attack_cooldown: float = 0.15
@export var combo_window_time: float = 2.0
@export var attack_knockback_strength: float = 5.0 # New export
@export var attack_knockback_height: float = 2.0 # New export
@export var running_attack_impulse: float = 3.0 # Forward momentum when attacking while running
@export var walking_attack_impulse: float = 1.5 # Forward momentum when attacking while walking
@export var idle_attack_impulse: float = 0.5 # Forward momentum when attacking while idle
@export var attack_rotation_influence: float = 0.5 # How much player can rotate during attacks (0-1)

@export_group("Components")
@export var punch_hand_r: Area3D # Assign in editor!
@export var punch_hand_l: Area3D # Assign in editor!
@onready var first_attack_area: Area3D = $FirstAttackArea
@onready var health_component: Node = $HealthComponent
@onready var health_label: Label = $"../../Health"

# ============================================================================
# RUNTIME VARIABLES
# ============================================================================
@onready var jump_velocity: float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity: float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity: float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0
var jump_phase := ""
var current_jump_count: int = 0
var is_slamming: bool = false
var slam_cooldown_timer: float = 0.0
var slam_windup_timer: float = 0.0 # Timer for windup delay
var slam_animation_phase: String = "" # Tracks: start, mid, end
var slam_fall_time: float = 0.0 # Time spent falling during slam
var is_playing_slam_end: bool = false

var air_speed: float
var movement_input: Vector2 = Vector2.ZERO
var is_running: bool = false
var is_trying_to_run: bool = false # Intent to run (button held)
var is_stopping: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var can_sprint: bool = true

# Animation Blending
var current_movement_blend: float = 0.0 # Current blend factor (0 = walk, 1 = run)
var target_movement_blend: float = 0.0 # Target blend factor

# Components Internal
@onready var anim_player: AnimationPlayer = $character/AnimationPlayer
@onready var attack_timer: Timer = $FirstAttackTimer
@onready var sprint_timer: Timer = $SprintTimer

# Combo System
var combo_count: int = 0
var current_attack_damage: float = 1.0
var current_attack_knockback_enabled: bool = false
var combo_reset_timer: Timer
var is_knockbacked: bool = false
var is_rolling: bool = false

# Shift Logic
var roll_threshold: float = 0.18
var shift_pressed_time: float = 0.0
var is_shift_down: bool = false
var is_auto_running: bool = false
var current_roll_charges: int = 3
var roll_penalty_timer: float = 0.0 # Long lockout when depleted
var roll_regen_timer: float = 0.0 # Short timer to restore 1 charge
var is_roll_recharging: bool = false # True if in penalty mode
var roll_interval_timer: float = 0.0 # Handles roll_chain_delay
var is_invincible: bool = false # True during roll i-frames

# Air Dash
var is_air_dashing: bool = false
var air_dash_start_position: Vector3 = Vector3.ZERO # Starting position of dash
var air_dash_cooldown_timer: float = 0.0
var air_dash_direction: Vector3 = Vector3.ZERO
var air_dash_bonus_jump_granted: bool = false # True if air dash was performed, allows 3rd jump
var is_passing_through: bool = false

var primary_naked_attacks: Array = ["Boy_attack_naked_1", "Boy_attack_naked_2", "Boy_attack_naked_3", "Boy_attack_naked_1", "Boy_attack_naked_3", "Boy_attack_naked_1", "Boy_attack_naked_3"]

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

	current_roll_charges = roll_max_charges

func _on_health_changed(new_health: float) -> void:
	if health_label:
		health_label.text = "HP: " + str(ceil(new_health))

func _on_died() -> void:
	print("Player Died!")
	# Handle death logic here

func take_damage(amount: float, knockback_force: Vector3) -> void:
	# Invulnerable during Ground Slam or Roll i-frames
	if is_slamming or is_invincible:
		return

	print("PLAYER TOOK DAMAGE:", amount)

	is_knockbacked = true

	if health_component:
		health_component.take_damage(amount)

	$HitFlash.flash()

	velocity += knockback_force
	velocity.y = max(velocity.y, 2.0)

	# Выключаем нокбэк через 0.2–0.4 сек (как нравится)
	await get_tree().create_timer(0.2).timeout
	is_knockbacked = false

func _input(event):
	if event.is_action_pressed("run") and is_on_floor():
		is_shift_down = true
		shift_pressed_time = 0.0

	if event.is_action_released("run"):
		is_shift_down = false
		if shift_pressed_time <= roll_threshold:
			perform_roll()
		else:
			# Stop running when button released if NOT auto-running
			if not is_auto_running:
				is_trying_to_run = false

			# If we WERE auto-running and just tapped shift, we rolled (above).
			# If we held shift again while auto-running, releasing it shouldn't stop us unless we stop moving (handled in move_logic).

		# Air Dash: Tap Shift in air
		if not is_on_floor() and shift_pressed_time <= roll_threshold:
			perform_air_dash()
		shift_pressed_time = 0.0
	if Input.is_action_just_pressed("first_attack"):
		# Ground Slam only after second jump, if cooldown ready, and if high enough
		if not is_on_floor() and not is_slamming and current_jump_count >= 2 and slam_cooldown_timer <= 0:
			# Check height from ground using raycast
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -100, 0))
			query.exclude = [self]
			var result = space_state.intersect_ray(query)

			if result:
				var distance_to_ground = global_position.distance_to(result.position)
				if distance_to_ground >= slam_min_height:
					start_ground_slam()
					print("Ground Slam initiated at height: ", distance_to_ground)
				else:
					print("Too close to ground for slam! Height: ", distance_to_ground)
					first_attack(primary_attack_speed)
			else:
				# No ground detected, allow slam anyway
				start_ground_slam()
		else:
			first_attack(primary_attack_speed)

func first_attack(attack_speed):
	# Roll Cancellation Logic (same as jump)
	if is_rolling:
		var can_cancel = false
		if roll_jump_cancel_threshold >= 1.0:
			can_cancel = true
		elif roll_jump_cancel_threshold > 0.0:
			if anim_player.current_animation == "Boy_roll":
				var ratio = anim_player.current_animation_position / anim_player.current_animation_length
				# threshold 1 = start (ratio 0), threshold 0 = end (ratio 1)
				# Formula: Cancel if ratio >= (1.0 - threshold)
				if ratio >= (1.0 - roll_jump_cancel_threshold):
					can_cancel = true

		if not can_cancel:
			return # Block attack

		# If cancelling, clear rolling state immediately
		is_rolling = false

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

	# Apply momentum based on movement state
	var forward = global_transform.basis.z.normalized()
	var impulse = 0.0

	# Check actual speed AND active input (to avoid stacking with momentum)
	var current_speed_2d = Vector2(velocity.x, velocity.z).length()
	var walk_speed_threshold = base_speed * 0.5 # 50% of walk speed
	var has_movement_input = movement_input.length() > 0.1

	if is_running:
		impulse = running_attack_impulse
	elif has_movement_input and current_speed_2d > walk_speed_threshold: # Actively walking
		impulse = walking_attack_impulse
	else: # Idle or coasting
		impulse = idle_attack_impulse

	if impulse > 0:
		velocity.x += forward.x * impulse
		velocity.z += forward.z * impulse

	var rand_anim_length = anim_player.get_animation(anim_to_play).length if anim_player.has_animation(anim_to_play) else 0.0

	# Start animation and timer that covers animation + cooldown
	# Play attack with a short blend so it can crossfade smoothly if cancelled
	anim_player.play(anim_to_play, 0.2, attack_speed)
	attack_timer.start(rand_anim_length + attack_cooldown)

	# Wait for the attack to finish OR until attack is cancelled (e.g. by roll)
	# Use a cancellable loop instead of awaiting `animation_finished` which would
	# block until whatever animation is currently active finishes (including a
	# subsequently-played roll). This allows perform_roll() to cancel the attack
	# and play the roll animation smoothly.
	while is_attacking and anim_player.current_animation == anim_to_play:
		await get_tree().process_frame

	is_attacking = false

	# Start combo reset timer
	combo_reset_timer.start()
	# NOTE: can_attack will be set true only when attack_timer times out (см. _on_first_attack_timer_timeout)

func _on_combo_timer_timeout() -> void:
	combo_count = 0

func _process(delta):
	# Roll Timer Logic (Cooldowns & Recharge)
	# Roll Timer Logic
	# 1. Penalty Timer (if fully depleted/locked)
	if is_roll_recharging:
		roll_penalty_timer -= delta
		if roll_penalty_timer <= 0:
			is_roll_recharging = false
			current_roll_charges = roll_max_charges
			print("Rolls Recharged! Charges: ", current_roll_charges)

	# 2. Continuous Regeneration (if not locked and missing charges)
	elif current_roll_charges < roll_max_charges:
		roll_regen_timer -= delta
		if roll_regen_timer <= 0:
			current_roll_charges += 1
			roll_regen_timer = roll_cooldown # Reset for next charge
			print("Regenerated 1 Roll. Charges: ", current_roll_charges)

	# 3. Chain Delay Timer
	if roll_interval_timer > 0:
		roll_interval_timer -= delta

	# 4. Slam Cooldown Timer
	if slam_cooldown_timer > 0:
		slam_cooldown_timer -= delta

	# 5. Air Dash Cooldown Timer
	if air_dash_cooldown_timer > 0:
		air_dash_cooldown_timer -= delta

	# 6. Air Dash Distance Check
	if is_air_dashing:
		var distance_traveled = global_position.distance_to(air_dash_start_position)
		if distance_traveled >= air_dash_distance:
			is_air_dashing = false
			print("Air Dash Complete! Distance: ", distance_traveled)

	# Shift Update Logic
	if is_shift_down:
		shift_pressed_time += delta
		if shift_pressed_time > roll_threshold and not is_running and not is_rolling:
			perform_run()

		# Auto-Run Latch
		if is_running and shift_pressed_time > auto_run_latch_time:
			is_auto_running = true

	RenderingServer.global_shader_parameter_set("player_position", global_transform.origin)

func _physics_process(delta: float) -> void:
	move_logic(delta)
	jump_logic(delta)
	move_and_slide()
	rot_char(delta)
	tilt_character(delta)
	animation_player()
	check_jump_pass_through()
	push_obj()

	# Ground Slam Impact Detection
	if is_slamming and is_on_floor():
		perform_slam_impact()

func check_jump_pass_through() -> void:
	if is_on_floor() and not is_passing_through and not is_slamming:
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
			# Light push to nearby enemies (no damage)
			var enemies = get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				if not is_instance_valid(enemy):
					continue
				var distance = global_position.distance_to(enemy.global_position)
				if distance <= slam_radius:
					var push_dir = (enemy.global_position - global_position).normalized()
					push_dir.y = 0
					var push_force_vec = push_dir * 1.5 # Weaker than slam's 3.0
					if enemy.has_method("receive_push"):
						enemy.receive_push(push_force_vec)
			velocity.y = -5.0 # Downward kick to fall through
			global_position.y -= 0.1 # Nudge down
			print("Passing through enemy!")
	if is_on_floor() and is_passing_through:
		is_passing_through = false
		set_collision_mask_value(3, true)
		print("Re-enabled enemy collisions.")

func perform_roll() -> void:
	# Constraints: Floor, States, Cooldowns, Charges
	# Allows interrupting attack
	if not is_on_floor() or is_rolling or is_knockbacked:
		return

	# Block if in chain delay
	if roll_interval_timer > 0:
		return

	# Block if in penalty recharge
	if is_roll_recharging:
		# print("Roll depleted, recharging...")
		return

	if current_roll_charges <= 0:
		return

	# Consume Charge
	current_roll_charges -= 1

	# Logic:
	# If we just hit 0, start penalty timer.
	# If we still have charges, ensure the regeneration timer is running for the used charge.

	if current_roll_charges <= 0:
		# Depleted -> Penalty
		is_roll_recharging = true
		roll_penalty_timer = roll_recharge_time
		roll_regen_timer = 0.0 # Stop normal regen
		print("Rolls Depleted! Recharging for ", roll_recharge_time, "s")
	else:
		# If regen wasn't already running (i.e. we were at max), start it now.
		# If it WAS running, we just let it continue (it effectively queues regeneration).
		# However, if user wants "starts recovering immediately", maybe we should reset it?
		# Usually, queuing is better (if I have 0.1s left to regen one, and I use another, I get +1 in 0.1s, then start next).
		# But "starts recovering immediately for 0.5s" implies per-instance or reset.
		# Let's assume standard "bucket" regen: the timer runs whenever missing charges.
		# If we were full, we initiate the timer now.
		if roll_regen_timer <= 0 and current_roll_charges == roll_max_charges - 1:
			 # Logic fix: if we were full, current_roll_charges is now max-1.
			 # We need to start the timer.
			roll_regen_timer = roll_cooldown

		# Simplification: JUST make sure roll_regen_timer is valid or let process handle it?
		# Process checks < max. If timer was 0 (idle), we need to seed it.
		if roll_regen_timer <= 0:
			roll_regen_timer = roll_cooldown

		print("Roll used. Charges: ", current_roll_charges)

	# Handle Attack Interruption (Roll Cancel)
	if is_attacking:
		var can_cancel = false
		if attack_roll_cancel_threshold >= 1.0:
			can_cancel = true
		elif attack_roll_cancel_threshold > 0.0:
			# Check current attack animation progress
			var current_anim = anim_player.current_animation
			if current_anim.begins_with("Boy_attack"):
				var ratio = anim_player.current_animation_position / anim_player.current_animation_length
				# threshold 1 = start (ratio 0), threshold 0 = end (ratio 1)
				# Formula: Cancel if ratio >= (1.0 - threshold)
				if ratio >= (1.0 - attack_roll_cancel_threshold):
					can_cancel = true

		if can_cancel:
			is_attacking = false
			can_attack = true # Reset flag
			# combo_reset_timer is usually managed by attack flow,
			# but if we cancel, we might want to keep the combo count active for a moment or reset it?
			# Standard cancel often preserves combo or resets it.
			# Let's just ensure we are physically free.
			# attack_timer logic: essentially we just override the state.
		else:
			# Cannot cancel attack, block roll
			return

	# Запоминаем: бежал ли игрок ДО переката (проверяем намерение, не факт)
	var was_running = is_trying_to_run or is_auto_running

	is_rolling = true
	is_running = false
	is_stopping = false # Reset stopping flag to prevent stopping animation from interrupting roll

	# Enable invincibility frames if configured
	if roll_invincibility_duration > 0:
		is_invincible = true

	# Направление вперёд (у тебя уже работает корректно)
	var forward = global_transform.basis.z.normalized()

	# Dynamic Speed Boost
	var current_roll_speed = roll_speed
	if was_running:
		current_roll_speed += run_speed * 0.8 # 50% of run speed as bonus

	velocity.x = forward.x * current_roll_speed
	velocity.z = forward.z * current_roll_speed

	anim_player.play("Boy_roll", 0, 1.0)

	# Получаем длину анимации
	var anim_length = anim_player.get_animation("Boy_roll").length

	# Calculate i-frame duration
	var iframe_duration = anim_length * roll_invincibility_duration
	if iframe_duration > 0:
		# Disable invincibility after i-frame window
		get_tree().create_timer(iframe_duration).timeout.connect(func(): is_invincible = false)

	# Ждем чуть меньше, чем длина анимации (срезаем концовку/выход)
	# Например: 75% времени — это сам кувырок, последние 25% — вставание (которое можно срезать для движения)
	var rollout_time = anim_length * 0.75

	await get_tree().create_timer(rollout_time).timeout
	# await anim_player.animation_finished # Старый вариант

	is_rolling = false

	# Start inter-roll delay
	if roll_chain_delay > 0:
		roll_interval_timer = roll_chain_delay

	# Restoring Run State
	# If we were running before the roll, resume running immediately
	if was_running:
		is_running = true

func play_with_random_offset(anim_name: String, blend: float = -1.0, speed: float = 1.0) -> void:
	# If already playing, just update parameters (speed/blend) without restarting/seeking
	if anim_player.current_animation == anim_name:
		anim_player.play(anim_name, blend, speed)
		return

	# Start new animation
	anim_player.play(anim_name, blend, speed)

	# Seek to random position
	var anim_len = anim_player.current_animation_length
	if anim_len > 0:
		anim_player.seek(randf() * anim_len)

func perform_run() -> void:
	if is_rolling or is_attacking:
		return
	is_trying_to_run = true

func perform_air_dash() -> void:
	# Block air dash during Ground Slam
	if is_slamming:
		return
	# Require second jump, same as Ground Slam
	if is_air_dashing or is_on_floor() or air_dash_cooldown_timer > 0 or current_jump_count < 2:
		return

	is_air_dashing = true
	air_dash_start_position = global_position # Store starting position
	air_dash_cooldown_timer = air_dash_cooldown

	# Forward direction relative to camera/character (purely horizontal)
	var forward = global_transform.basis.z.normalized()
	air_dash_direction = Vector3(forward.x, 0, forward.z).normalized()

	# Instant horizontal burst - no vertical component
	velocity.x = air_dash_direction.x * air_dash_speed
	velocity.z = air_dash_direction.z * air_dash_speed
	velocity.y = 0 # Zero vertical velocity for pure horizontal dash

	# Grant bonus jump after air dash (don't increment jump count)
	# This allows: jump -> jump -> air dash -> jump (3rd jump)
	air_dash_bonus_jump_granted = true
	if current_jump_count >= max_jump_count:
		current_jump_count = max_jump_count - 1 # Allow one more jump

	anim_player.play("Boy_air_dash", 0.1, 1.0)
	print("Air Dash Started!")

func start_ground_slam() -> void:
	is_slamming = true
	is_air_dashing = false # Cancel air dash if active
	slam_cooldown_timer = slam_cooldown
	slam_windup_timer = slam_windup_delay
	slam_animation_phase = "start"
	slam_fall_time = 0.0 # Reset fall timer

	# Disable collision with enemies (pass through them)
	# Assuming enemies are on collision layer 2 (adjust if different)
	set_collision_mask_value(3, false)

	# Zero out all velocity for freeze effect
	velocity.x = 0
	velocity.z = 0
	velocity.y = 0

	# Play start animation
	anim_player.play("Boy_attack_air_naked_start", 0.1, 0.5)
	print("Ground Slam Started - Windup Phase!")

func perform_slam_impact() -> void:
	is_slamming = false
	is_playing_slam_end = false
	slam_animation_phase = ""
	set_collision_mask_value(3, true)

	# Re-enable collision with enemies
	set_collision_mask_value(3, true)

	print("Ground Slam Impact!")

	# First, push away all enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance <= slam_radius:
			# Push enemy away from impact point
			var push_dir = (enemy.global_position - global_position).normalized()
			push_dir.y = 0 # Horizontal push only
			var push_force_vec = push_dir * 3.0 # Strong push to clear space

			if enemy.has_method("receive_push"):
				enemy.receive_push(push_force_vec)

			# Then apply damage with knockback
			var knockback_dir = push_dir
			knockback_dir.y = 0.5 # Add upward component for damage knockback
			var knockback_vec = knockback_dir * slam_knockback

			if enemy.has_method("take_damage"):
				enemy.take_damage(slam_damage, knockback_vec)
				print("Slam hit enemy at distance: ", distance)

func push_obj():
	var current_push_force = push_force
	if is_rolling:
		current_push_force *= roll_push_multiplier

	for i in range(get_slide_collision_count()):
		var c = get_slide_collision(i)
		var collider = c.get_collider()
		if collider is RigidBody3D:
			collider.apply_central_impulse(-c.get_normal() * current_push_force)
		if collider is CharacterBody3D and collider.has_method("receive_push"):
			collider.receive_push(-c.get_normal() * current_push_force)

func move_logic(delta):
	# Ground Slam: Lock all movement controls
	if is_slamming:
		return

	movement_input = Input.get_vector('left', "right", "up", "down")
	var velocity_2d = Vector2(velocity.x, velocity.z)
	var is_airborne = not is_on_floor()
	var control = 1.0 if not is_airborne else clamp(air_control, 0.0, 1.0)

	# Air Dash: Lock velocity during dash (maintain horizontal speed)
	if is_air_dashing:
		velocity.x = air_dash_direction.x * air_dash_speed
		velocity.z = air_dash_direction.z * air_dash_speed
		return

	if movement_input == Vector2.ZERO:
		is_running = false
		is_trying_to_run = false
		is_auto_running = false

	# Update is_running based on intent and actual speed
	var speed_2d = Vector2(velocity.x, velocity.z).length()
	var run_speed_threshold = lerp(base_speed, run_speed, 0.7)

	# Set is_running if trying to run AND have reached speed threshold
	if is_trying_to_run or is_auto_running:
		if speed_2d >= run_speed_threshold:
			is_running = true
		else:
			is_running = false
	else:
		is_running = false

	var current_speed = run_speed if (is_trying_to_run or is_auto_running) else base_speed
	if is_airborne:
		current_speed = air_speed
	elif is_rolling:
		current_speed = roll_speed

	if movement_input != Vector2.ZERO:
		var input_factor = 1.0 if not is_attacking else attack_movement_influense

		# Control factor: Normal (1.0) vs Air vs Roll
		var final_control = control

		if is_rolling:
			# Steerable Roll: Align velocity with actual character facing
			# This creates a curved path as rot_char rotates the mesh
			var current_mag = velocity_2d.length()
			var forward = global_transform.basis.z.normalized()
			var forward_2d = Vector2(forward.x, forward.z)
			velocity_2d = forward_2d * current_mag
		else:
			velocity_2d = velocity_2d.lerp(movement_input * current_speed * input_factor, acceleration * final_control)
	else:
		if not is_rolling:
			velocity_2d = velocity_2d.move_toward(Vector2.ZERO, stop_speed * delta)

	velocity.x = velocity_2d.x
	velocity.z = velocity_2d.y

func jump_logic(delta):
	# Reset jumps when on floor
	if is_on_floor():
		current_jump_count = 0
		air_dash_bonus_jump_granted = false
		jump_phase = "" # ADD/ENSURE
	if Input.is_action_just_pressed('jump'):
		# Roll Cancellation Logic
		if is_rolling:
			var can_cancel = false
			if roll_jump_cancel_threshold >= 1.0:
				can_cancel = true
			elif roll_jump_cancel_threshold > 0.0:
				if anim_player.current_animation == "Boy_roll":
					var ratio = anim_player.current_animation_position / anim_player.current_animation_length
					# threshold 1 = start (ratio 0), threshold 0 = end (ratio 1)
					# Formula: Cancel if ratio > (1.0 - threshold)
					if ratio >= (1.0 - roll_jump_cancel_threshold):
						can_cancel = true

			if not can_cancel:
				return # Block jump

			# If cancelling, clear rolling state immediately so jump physics apply
			is_rolling = false

		# Execute Jump
		# First jump ONLY from ground, additional jumps allowed in air
		# Third jump (count=2) only allowed if air dash was performed
		var can_jump = false

		if is_on_floor() and current_jump_count == 0:
			# First jump from ground
			can_jump = true
		elif current_jump_count > 0 and current_jump_count < 2:
			# Second jump in air (always allowed)
			can_jump = true
		elif current_jump_count == 2 and air_dash_bonus_jump_granted:
			# Third jump only if air dash was performed
			can_jump = true

		if can_jump:
			if current_jump_count > 0: # ADD: Reset phase for AIR JUMPS ONLY
				jump_phase = ""
			var jump_multiplier = second_jump_multiplier if current_jump_count == 1 else 1.0
			velocity.y = - jump_velocity * jump_multiplier
			current_jump_count += 1
			air_speed = Vector2(velocity.x, velocity.z).length()

	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity

	# Air Dash: No gravity during dash (pure horizontal movement)
	if is_air_dashing:
		# Keep velocity.y at 0, no gravity - pure horizontal dash
		velocity.y = 0
		return

	# Ground Slam: Three-phase logic
	if is_slamming:
		if slam_windup_timer > 0:
			# PHASE 1: Windup - Freeze in air
			slam_windup_timer -= delta
			velocity.y = 0 # Completely freeze vertical movement
			velocity.x = 0 # Keep horizontal frozen too
			velocity.z = 0

			# Check if windup just finished
			if slam_windup_timer <= 0:
				print("Ground Slam - Descent Phase!")
				slam_animation_phase = "mid"
				# Play mid animation looping
				anim_player.play("Boy_attack_air_naked_mid", 0.5, 0.5)
		else:
			# PHASE 2: Descent - Exponential acceleration
			slam_fall_time += delta
			# Exponential formula: speed = initial_speed * exp(acceleration * time)
			# Start slow, accelerate exponentially
			var initial_speed = 5.0 # Starting descent speed
			var current_speed = initial_speed * exp(slam_acceleration * slam_fall_time)
			# Cap at max descent speed
			current_speed = min(current_speed, slam_descent_speed)
			velocity.y = - current_speed
			velocity.x = 0 # Maintain zero horizontal
			velocity.z = 0

			# Check proximity to ground for end animation
			# Use raycast to detect ground distance
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, 0.1, 0))
			query.exclude = [self]
			var result = space_state.intersect_ray(query)

			if result and slam_animation_phase == "mid":
				slam_animation_phase = "end"
				is_playing_slam_end = true # ← ВКЛ
				anim_player.play("Boy_attack_air_naked_end", 0.5, 0.5)
	else:
		# Normal gravity application
		velocity.y -= gravity * delta

func rot_char(delta):
	# Prevent rotation during knockback or Ground Slam
	if is_knockbacked or is_slamming: return

	var current_rot_speed = 0.0 if is_stopping else rot_speed

	# If rolling, scale rotation speed by roll_control
	if is_rolling:
		current_rot_speed = rot_speed * roll_control

	# If attacking, scale rotation speed by attack_rotation_influence
	if is_attacking:
		current_rot_speed = rot_speed * attack_rotation_influence

	var vel_2d = Vector2(velocity.x, -velocity.z)

	# Override rotation target if rolling: Look at Input, not Velocity
	if is_rolling:
		if movement_input != Vector2.ZERO:
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
	# Don't override special state animations
	if is_attacking or is_rolling or is_air_dashing or is_slamming or is_playing_slam_end:
		return
	var speed_2d := Vector2(velocity.x, velocity.z).length()
	var has_input := Input.get_vector("left", "right", "up", "down").length() > 0

	# Прыжки
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
			anim_player.play("Boy_jump_end", 0.1, 1.0) # FIXED speed/blend
			jump_phase = ""
	# Движение по земле
	if has_input:
		is_stopping = false
		# Calculate blend factor based on speed
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
	# Timer закончился — разрешаем новую атаку (кулдаун завершён)
	can_attack = true
	# убедимся, что флаг is_attacking уже сброшен отдельным await'ом после окончания анимации

func _on_sprint_timer_timeout():
	can_sprint = true

# Signal Handlers - Replaced by Animation Event Logic
# func _on_punch_hand_r_body_entered(body: Node3D) -> void:
# 	punch_collision(body, punch_hand_r)

# func _on_punch_hand_l_body_entered(body: Node3D) -> void:
# 	punch_collision(body, punch_hand_l)

# Called by AnimationPlayer Call Method Track
func _check_attack_hit() -> void:
	var hits_found = false
	if punch_hand_r and _check_single_hand_hit(punch_hand_r):
		hits_found = true

	if not hits_found and punch_hand_l:
		_check_single_hand_hit(punch_hand_l)

func _check_single_hand_hit(hand: Area3D) -> bool:
	for body in hand.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			punch_collision(body, hand)
			return true
	return false

func punch_collision(body: Node3D, hand: Area3D) -> void:
	if not is_attacking:
		return
	if not body.is_in_group("enemies"):
		return

	# Optional: keeping the check if body is within main attack area if strictly required
	# But typically hand overlap is sufficient.
	# if first_attack_area and body in first_attack_area.get_overlapping_bodies():

	var direction = (body.global_transform.origin - hand.global_transform.origin).normalized()

	# Apply damage with current specs
	if body.has_method("take_damage"):
		# If 3rd hit, send extra knockback if supported
		if current_attack_knockback_enabled:
			# Assumes enemy has take_damage(amount, knockback_vec)
			# Push slightly up + away
			var knockback_vec = direction * attack_knockback_strength
			knockback_vec.y = attack_knockback_height
			body.take_damage(current_attack_damage, knockback_vec)
		else:
			# Standard hit (no knockback)
			body.take_damage(current_attack_damage, Vector3.ZERO)

# ============================================================================
# ANIMATION BLENDING HELPERS
# ============================================================================
func calculate_walk_run_blend(speed: float) -> float:
	"""Calculate blend factor based on speed (0 = walk, 1 = run)"""
	# Use inverse_lerp to map speed to 0-1 range within blend zone
	var blend = inverse_lerp(walk_run_blend_start_speed, walk_run_blend_end_speed, speed)
	return clamp(blend, 0.0, 1.0)

func apply_movement_animation_blend(blend: float, speed: float) -> void:
	"""Apply blended animation based on blend factor and speed"""
	# Smooth blend transition over time
	target_movement_blend = blend
	current_movement_blend = lerp(current_movement_blend, target_movement_blend, walk_run_blend_smoothing * get_physics_process_delta_time())

	# Choose animation based on blend factor
	if current_movement_blend < 0.5:
		# Closer to walk - play walk animation
		var walk_speed_scale = lerp(0.0, 1.25, speed / base_speed)
		play_with_random_offset("Boy_walk", 0.5, walk_speed_scale)
	else:
		# Closer to run - play run animation
		var run_speed_scale = lerp(0.5, 1.25, speed / run_speed)
		play_with_random_offset("Boy_run", 0.5, run_speed_scale)
