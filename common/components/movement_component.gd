class_name MovementComponent
extends Node

# --- ЕДИНЫЕ НАСТРОЙКИ ДВИЖЕНИЯ ДЛЯ ВСЕХ ---
@export_group("Base Movement Stats")
@export var base_speed: float = 3.0 ## Базовая скорость (ходьба)
@export var run_speed: float = 4.5  ## Скорость бега / погони
@export var rotation_speed: float = 10.0 ## Скорость поворота (Lerp weight)
@export var acceleration: float = 0.3
@export var stop_speed: float = 8.0

@export_group("Physics Interaction")
@export var push_force: float = 200.0 ## Сила толкания физических объектов
@export var roll_push_multiplier: float = 3.0 

@export_group("Jump Settings")
@export var jump_height: float = 1.25
@export var jump_time_to_peak: float = 0.45
@export var jump_time_to_descent: float = 0.28
@export var max_jump_count: int = 2
@export var second_jump_multiplier: float = 1.2

var actor: CharacterBody3D
var current_jump_count: int = 0
var was_on_floor: bool = true
var is_passing_through: bool = false 

# Расчет гравитации (кэшируем при старте)
@onready var jump_velocity: float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity: float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity: float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

func _ready() -> void:
	var p = get_parent()
	if p and p.get_parent() is CharacterBody3D:
		actor = p.get_parent()

func init(character: CharacterBody3D) -> void:
	actor = character

func _physics_process(delta: float) -> void:
	if not actor: return
	
	if actor.is_on_floor() and not was_on_floor:
		current_jump_count = 0
		if actor.has_method("reset_air_abilities"):
			actor.reset_air_abilities()
			
	was_on_floor = actor.is_on_floor()
	_handle_pass_through()

func apply_gravity(delta: float) -> void:
	if not actor: return
	var gravity = jump_gravity if actor.velocity.y > 0.0 else fall_gravity
	actor.velocity.y -= gravity * delta

func move(delta: float, input_dir: Vector2, target_speed: float, is_root_motion: bool = false) -> void:
	if not actor: return
	if is_root_motion and actor.is_on_floor():
		return 

	var velocity_2d = Vector2(actor.velocity.x, actor.velocity.z)
	
	if input_dir != Vector2.ZERO:
		velocity_2d = velocity_2d.lerp(input_dir * target_speed, acceleration)
	else:
		velocity_2d = velocity_2d.move_toward(Vector2.ZERO, stop_speed * delta)
		
	actor.velocity.x = velocity_2d.x
	actor.velocity.z = velocity_2d.y

func jump(bonus_jump_allowed: bool = false) -> bool:
	if not actor: return false
	var can_jump = false
	if current_jump_count < max_jump_count: can_jump = true
	elif current_jump_count == max_jump_count and bonus_jump_allowed: can_jump = true
	if can_jump:
		var multiplier = second_jump_multiplier if current_jump_count >= 1 else 1.0
		actor.velocity.y = -jump_velocity * multiplier
		current_jump_count += 1
		return true
	return false

func rotate_towards(delta: float, direction: Vector2, speed_modifier: float = 1.0) -> void:
	if not actor: return
	if direction.length_squared() > 0.001:
		var target_angle = atan2(direction.x, direction.y)
		actor.rotation.y = lerp_angle(actor.rotation.y, target_angle, rotation_speed * speed_modifier * delta)

func tilt_character(delta: float, mesh_node: Node3D, is_running: bool) -> void:
	if not actor or not mesh_node: return
	var target_tilt = 0.0
	if actor.is_on_floor():
		var tilt_angle = 10 if is_running and actor.velocity.length() > base_speed + 1 else 3
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
		
		# Игнорируем пол
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
