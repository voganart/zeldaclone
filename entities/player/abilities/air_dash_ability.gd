class_name AirDashAbility
extends Node

@export_group("Air Dash")
@export var air_dash_speed: float = 15.0
@export var air_dash_distance: float = 3.0
@export var air_dash_cooldown: float = 1.0

var is_dashing: bool = false
var dash_used_in_air: bool = false
var bonus_jump_granted: bool = false
var cooldown_timer: float = 0.0

var _start_position: Vector3 = Vector3.ZERO
var _dash_direction: Vector3 = Vector3.ZERO
var is_unlocked: bool = false

@onready var actor: CharacterBody3D = get_parent()

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta

	if is_dashing:
		var dist = actor.global_position.distance_to(_start_position)
		if dist >= air_dash_distance:
			stop_dash()

func _physics_process(_delta: float) -> void:
	if is_dashing:
		_handle_dash_physics()

func reset_air_state() -> void:
	dash_used_in_air = false
	bonus_jump_granted = false
	if is_dashing:
		stop_dash()

func can_dash() -> bool:
	if not is_unlocked: return false
	if is_dashing: return false
	if actor.is_on_floor(): return false
	if dash_used_in_air: return false
	if cooldown_timer > 0: return false
	if "current_jump_count" in actor and actor.current_jump_count < 2:
		return false
	return true

func perform_dash() -> void:
	if not can_dash(): return
	
	is_dashing = true
	dash_used_in_air = true
	bonus_jump_granted = true
	cooldown_timer = air_dash_cooldown
	_start_position = actor.global_position
	
	var forward = actor.global_transform.basis.z.normalized()
	_dash_direction = Vector3(forward.x, 0, forward.z).normalized()
	
	# Используем метод API игрока для запуска анимации
	if actor.has_method("trigger_air_dash"):
		actor.trigger_air_dash()
	
	print("Air Dash Ability Started!")

func stop_dash() -> void:
	is_dashing = false
	actor.velocity.y = -0.1

func _handle_dash_physics() -> void:
	actor.velocity.x = _dash_direction.x * air_dash_speed
	actor.velocity.z = _dash_direction.z * air_dash_speed
	actor.velocity.y = 0
	
	var collision = actor.get_last_slide_collision()
	if collision:
		if collision.get_normal().dot(Vector3.UP) < 0.7:
			stop_dash()
