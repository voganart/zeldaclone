class_name GroundSlamAbility
extends Node

@export_group("Ground Slam")
@export var slam_damage: float = 1.0
@export var slam_radius: float = 2.0
@export var slam_descent_speed: float = 20.0
@export var slam_knockback: float = 0.3
@export var slam_cooldown: float = 2.0
@export var slam_windup_delay: float = 0.5
@export var slam_acceleration: float = 50.0
@export var slam_min_height: float = 2.5
@export var slam_end_anim_speed: float = 1.5
@export var slam_vfx_index: int = 2

var is_slamming: bool = false
var is_recovering: bool = false

var cooldown_timer: float = 0.0
var _windup_timer: float = 0.0
var _fall_time: float = 0.0
var _animation_phase: String = ""
var _impact_processed: bool = false
var _playing_end_anim: bool = false
var is_unlocked: bool = false

@onready var actor: CharacterBody3D = get_parent()
# Анимационный плеер нужен только для получения длительности анимаций
@onready var anim_player: AnimationPlayer = actor.get_node("character/AnimationPlayer")

signal cooldown_updated(time_left: float, max_time: float)

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta
		cooldown_updated.emit(cooldown_timer, slam_cooldown)
	else:
		if cooldown_timer > -1.0:
			cooldown_updated.emit(0.0, slam_cooldown)
			cooldown_timer = -2.0

func can_slam() -> bool:
	if not is_unlocked: return false
	if is_slamming or is_recovering: return false
	if actor.is_on_floor(): return false
	if cooldown_timer > 0: return false
	if "current_jump_count" in actor and actor.current_jump_count < 2:
		return false
	
	var space_state = actor.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(actor.global_position, actor.global_position + Vector3(0, -slam_min_height, 0))
	query.exclude = [actor]
	var result = space_state.intersect_ray(query)
	if result: return false
	return true

func start_slam() -> void:
	if not can_slam(): return
	
	is_slamming = true
	is_recovering = false
	cooldown_timer = slam_cooldown
	_windup_timer = slam_windup_delay
	_fall_time = 0.0
	_animation_phase = "start"
	_impact_processed = false
	_playing_end_anim = false
	
	actor.set_collision_mask_value(3, false)
	actor.velocity = Vector3.ZERO
	
	# Устанавливаем Transition в start
	if actor.has_method("set_slam_state"):
		actor.set_slam_state("start")

func update_physics(delta: float) -> bool:
	if is_recovering:
		actor.velocity.x = move_toward(actor.velocity.x, 0, 1.0)
		actor.velocity.z = move_toward(actor.velocity.z, 0, 1.0)
		return true

	if not is_slamming: return false
	
	_break_objects_below()

	if actor.is_on_floor() and not _impact_processed:
		_perform_impact()
		return true
		
	if _windup_timer > 0:
		_windup_timer -= delta
		actor.velocity = Vector3.ZERO
		if _windup_timer <= 0:
			_animation_phase = "mid"
			# Переход в mid
			if actor.has_method("set_slam_state"):
				actor.set_slam_state("mid")
		return true
	
	_fall_time += delta
	var current_speed = 5.0 * exp(slam_acceleration * _fall_time)
	current_speed = min(current_speed, slam_descent_speed)
	
	actor.velocity.x = 0
	actor.velocity.z = 0
	actor.velocity.y = - current_speed
	
	_check_ground_proximity()
	return true

func _break_objects_below() -> void:
	var space_state = actor.get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = 0.5 
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), actor.global_position + Vector3(0, -1.0, 0))
	params.exclude = [actor]
	params.collision_mask = 0xFFFFFFFF 
	var results = space_state.intersect_shape(params)
	
	for result in results:
		var body = result.collider
		if not is_instance_valid(body): continue
		if body is RigidBody3D or body is BreakableObject:
			if body.has_method("take_damage"):
				body.take_damage(999.0, Vector3.DOWN * 10.0, true)
				if body.has_method("set_collision_layer_value"):
					body.collision_layer = 0
					body.collision_mask = 0
				elif body is CollisionObject3D:
					body.collision_layer = 0
					body.collision_mask = 0

func _check_ground_proximity() -> void:
	if _playing_end_anim: return
	if _animation_phase != "mid": return
	
	var space_state = actor.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(actor.global_position, actor.global_position + Vector3(0, 1.5, 0))
	query.exclude = [actor]
	var result = space_state.intersect_ray(query)
	
	if result:
		_animation_phase = "end"
		_playing_end_anim = true
		# Переход в end (приземление)
		if actor.has_method("set_slam_state"):
			actor.set_slam_state("end")

func _perform_impact() -> void:
	if _impact_processed: return
	_impact_processed = true
	
	is_slamming = false
	is_recovering = true
	get_tree().call_group("camera_shaker", "add_trauma", 5.8)
	if actor.get("sfx_slam_impact"):
		actor.sfx_slam_impact.play_random()
	
	# Если мы еще не включили end (ударились об пол раньше луча)
	if not _playing_end_anim:
		if actor.has_method("set_slam_state"):
			actor.set_slam_state("end")
	
	# Ждем окончания анимации
	var anim_len = anim_player.get_animation(GameConstants.ANIM_PLAYER_SLAM_END).length
	var wait_time = anim_len / slam_end_anim_speed
	
	_deal_damage()
	actor.set_collision_mask_value(3, true)
	print("Slam Impact!")
	
	await get_tree().create_timer(wait_time).timeout
	if not is_instance_valid(actor): return
	
	# Здесь мы не выключаем стейт в "off", это делает State (player_slam.gd) при выходе
	is_recovering = false
	_playing_end_anim = false
	
	var vfx = VfxPool.spawn_effect(slam_vfx_index, actor.global_position + Vector3(0, 0.05, 0))
	if vfx and vfx.has_node("AnimationPlayer"):
		vfx.get_node("AnimationPlayer").play("play")
		vfx.get_node("AnimationPlayer").seek(0, true)

func _deal_damage() -> void:
	var space_state = actor.get_world_3d().direct_space_state
	var shape = SphereShape3D.new()
	shape.radius = slam_radius
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), actor.global_position)
	params.collision_mask = 0xFFFFFFFF 
	params.exclude = [actor]
	var results = space_state.intersect_shape(params)
	
	for result in results:
		var body = result.collider
		if not is_instance_valid(body): continue
		if body.has_method("take_damage"):
			var push_dir = (body.global_position - actor.global_position).normalized()
			var knockback_vec = push_dir * 8.0 
			knockback_vec.y = 3.0
			if body.has_method("receive_push"):
				body.receive_push(push_dir * 3.0)
			elif body is RigidBody3D:
				body.apply_central_impulse(push_dir * 10.0) 
			body.take_damage(slam_damage, knockback_vec, true)
