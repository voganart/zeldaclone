class_name MovementComponent
extends Node

# --- ГЛАВНЫЕ НАСТРОЙКИ ДВИЖЕНИЯ ---
@export_group("Speed Stats")
@export var walk_speed: float = 3.0   
@export var run_speed: float = 4.5    
@export var rotation_speed: float = 10.0 

@export_group("Ground Physics")
@export var acceleration: float = 8.0  
@export var friction: float = 10.0     

@export_group("Air Physics")
@export var air_acceleration: float = 4.0 
## Трение в воздухе. Ставим маленькое значение, чтобы инерция от платформы сохранялась.
@export var air_friction: float = 0.5     

@export_group("Physics Interaction")
@export var push_force: float = 200.0 
@export var roll_push_multiplier: float = 3.0 

@export_group("Jump Settings")
@export var jump_height: float = 1.25
@export var jump_time_to_peak: float = 0.45
@export var jump_time_to_descent: float = 0.28
@export var max_jump_count: int = 1 
@export var second_jump_multiplier: float = 1.2

@export_group("Visuals")
@export var jump_vfx_index: int = 5
@export var land_vfx_index: int = 5

var actor: CharacterBody3D
var current_jump_count: int = 0
var was_on_floor: bool = true
var is_passing_through: bool = false 
var stop_speed: float = 8.0 

@onready var jump_velocity: float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity: float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity: float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

func _ready() -> void:
	var p = get_parent()
	if p and p.get_parent() is CharacterBody3D:
		actor = p.get_parent()

func init(character: CharacterBody3D) -> void:
	actor = character

func unlock_double_jump():
	max_jump_count = 2
	print("MovementComponent: Double Jump Unlocked!")
	
func _physics_process(_delta: float) -> void:
	if not actor: return
	
	if actor.is_on_floor() and not was_on_floor:
		current_jump_count = 0
		if actor.has_method("reset_air_abilities"):
			actor.reset_air_abilities()
		
		if actor.has_node("/root/VfxPool"):
			VfxPool.spawn_effect(land_vfx_index, actor.global_position)
			
	was_on_floor = actor.is_on_floor()
	_handle_pass_through()

func apply_gravity(delta: float) -> void:
	if not actor: return
	var gravity = jump_gravity if actor.velocity.y > 0.0 else fall_gravity
	actor.velocity.y -= gravity * delta

func move(delta: float, input_dir: Vector2, target_speed: float, is_root_motion: bool = false) -> void:
	if not actor: return
	
	if is_root_motion and actor.is_on_floor():
		pass 
	else:
		var current_accel = acceleration
		var current_friction = friction
		
		if not actor.is_on_floor():
			current_accel = air_acceleration
			current_friction = air_friction # Здесь теперь используется низкое значение (0.5)

		var velocity_2d = Vector2(actor.velocity.x, actor.velocity.z)
		
		if input_dir != Vector2.ZERO:
			# Если есть ввод, мы управляем персонажем
			velocity_2d = velocity_2d.move_toward(input_dir * target_speed, current_accel * delta)
		else:
			# Если ввода НЕТ:
			if actor.is_on_floor():
				# На земле тормозим быстро (как раньше)
				var fric = max(current_friction, stop_speed)
				velocity_2d = velocity_2d.move_toward(Vector2.ZERO, fric * delta)
			else:
				# В ВОЗДУХЕ тормозим ОЧЕНЬ МЕДЛЕННО (сохраняем инерцию платформы)
				# velocity_2d.move_toward уменьшает длину вектора.
				# С маленьким air_friction (0.5) скорость почти не падает.
				velocity_2d = velocity_2d.move_toward(Vector2.ZERO, current_friction * delta)
			
		actor.velocity.x = velocity_2d.x
		actor.velocity.z = velocity_2d.y

func jump(bonus_jump_allowed: bool = false) -> bool:
	if not actor: return false
	var can_jump = false
	if current_jump_count < max_jump_count: can_jump = true
	elif current_jump_count == max_jump_count and bonus_jump_allowed: can_jump = true
	
	if can_jump:
		# === ИНЕРЦИЯ ПЛАТФОРМЫ (ИСПРАВЛЕНО) ===
		# Мы добавляем скорость платформы к скорости игрока ТОЛЬКО в момент прыжка.
		# Так как мы уходим с пола, move_and_slide перестанет нас тащить,
		# но добавленная здесь скорость сохранится в actor.velocity благодаря низкому air_friction.
		if actor.is_on_floor():
			var platform_vel = _get_floor_velocity()
			# Добавляем только X и Z, чтобы не портить высоту прыжка
			actor.velocity.x += platform_vel.x
			actor.velocity.z += platform_vel.z
		# ======================================
		
		var multiplier = second_jump_multiplier if current_jump_count >= 1 else 1.0
		actor.velocity.y = -jump_velocity * multiplier
		
		if current_jump_count >= 1:
			if actor.has_node("/root/VfxPool"):
				VfxPool.spawn_effect(jump_vfx_index, actor.global_position + Vector3(0, 0.5, 0))
		
		current_jump_count += 1
		return true
	return false

# Хелпер для получения скорости пола (ищем MovingPlatform)
func _get_floor_velocity() -> Vector3:
	var col_count = actor.get_slide_collision_count()
	for i in range(col_count):
		var col = actor.get_slide_collision(i)
		var collider = col.get_collider()
		
		# Пытаемся найти переменную current_velocity у коллайдера или его родителя
		if is_instance_valid(collider):
			if "current_velocity" in collider:
				return collider.current_velocity
			elif collider.get_parent() and "current_velocity" in collider.get_parent():
				return collider.get_parent().current_velocity
	return Vector3.ZERO

func rotate_towards(delta: float, direction: Vector2, speed_modifier: float = 1.0) -> void:
	if not actor: return
	if direction.length_squared() > 0.001:
		var target_angle = atan2(direction.x, direction.y)
		actor.rotation.y = lerp_angle(actor.rotation.y, target_angle, rotation_speed * speed_modifier * delta)

func tilt_character(delta: float, mesh_node: Node3D, is_running: bool) -> void:
	if not actor or not mesh_node: return
	var target_tilt = 0.0
	if actor.is_on_floor():
		var tilt_angle = 10 if is_running and actor.velocity.length() > walk_speed + 1 else 3
		var move_vec = Vector3(actor.velocity.x, 0, actor.velocity.z)
		var local_move = actor.global_transform.basis.inverse() * move_vec
		target_tilt = clamp(-local_move.x, -1, 1) * deg_to_rad(tilt_angle)
	
	mesh_node.rotation.z = lerp_angle(mesh_node.rotation.z, target_tilt, 10.0 * delta)

func handle_pushing(is_rolling: bool) -> void:
	if not actor: return
	var dt = get_physics_process_delta_time()
	var collision_count = actor.get_slide_collision_count()
	
	for i in range(collision_count):
		var c = actor.get_slide_collision(i)
		if c.get_normal().y > 0.7: continue
		
		var collider = c.get_collider()
		var push_dir = -c.get_normal()
		push_dir.y = 0 
		
		if push_dir.length_squared() < 0.001: continue
		push_dir = push_dir.normalized()
		
		if collider is RigidBody3D:
			collider.sleeping = false
			var current_force = push_force
			if is_rolling: current_force *= roll_push_multiplier
			collider.apply_central_impulse(push_dir * current_force * dt)
			
		elif collider is CharacterBody3D and collider.has_method("receive_push"):
			var nudge_strength = 10.0 * dt
			if is_rolling: 
				nudge_strength *= 3.0 
				actor.velocity *= 0.95
			collider.receive_push(push_dir * nudge_strength)

func _handle_pass_through() -> void:
	if is_passing_through:
		if actor.is_on_floor():
			is_passing_through = false
			actor.set_collision_mask_value(3, true)
		return
	if actor.is_on_floor():
		for i in actor.get_slide_collision_count():
			var c = actor.get_slide_collision(i)
			if c.get_collider().is_in_group("enemies"):
				if c.get_normal().y > 0.6:
					is_passing_through = true
					actor.set_collision_mask_value(3, false)
					actor.global_position.y -= 0.05
					break

func force_velocity(vec: Vector3) -> void:
	if actor:
		actor.velocity = vec
