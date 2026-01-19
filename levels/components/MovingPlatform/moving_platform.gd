@tool
extends Node3D

@export_category("Movement Configuration")
@export var platform_node: AnimatableBody3D

@export var move_offset: Vector3 = Vector3(0, 0, 0):
	set(value):
		move_offset = value
		if Engine.is_editor_hint():
			_update_debug_line()
			_update_platform_position()

@export_range(0.0, 1.0) var preview_progress: float = 0.0:
	set(value):
		preview_progress = value
		if Engine.is_editor_hint():
			_update_platform_position()

@export var speed: float = 3.0
@export var pause_at_ends: float = 1.0
@export var enabled: bool = true

@export_group("Animation")
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

@export_category("Destruction")
@export var is_fragile: bool = false
@export var collapse_delay: float = 1.0
@export var respawn_time: float = 3.0

var _body: AnimatableBody3D
var _trigger: Area3D

# Дебаг
var debug_mesh_instance: MeshInstance3D
var debug_mesh: ImmediateMesh

var start_pos: Vector3 = Vector3.ZERO
var target_pos: Vector3 = Vector3.ZERO
var tween: Tween

var is_collapsing: bool = false

# === ФИЗИКА ===
# Эту переменную будет читать игрок при прыжке
var current_velocity: Vector3 = Vector3.ZERO
var _prev_global_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	_initialize_nodes()
	
	start_pos = Vector3.ZERO 
	target_pos = move_offset
	
	if Engine.is_editor_hint():
		_setup_debug_drawing()
		_update_debug_line()
		_update_platform_position()
		return

	if _body:
		_update_platform_position()
		_prev_global_pos = _body.global_position
		# ВАЖНО: Включаем sync_to_physics, чтобы CharacterBody3D корректно ездил на платформе
		_body.sync_to_physics = true
	
	if is_fragile:
		if not _trigger and _body:
			_trigger = _body.get_node_or_null("TriggerArea")
		if _trigger:
			if not _trigger.body_entered.is_connected(_on_player_stepped):
				_trigger.body_entered.connect(_on_player_stepped)
	
	if enabled:
		_start_move_cycle(preview_progress)

func _initialize_nodes() -> void:
	if platform_node:
		_body = platform_node
	else:
		var child = get_node_or_null("PlatformBody")
		if child is AnimatableBody3D:
			_body = child
		else:
			for c in get_children():
				if c is AnimatableBody3D:
					_body = c
					break

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _body: return
	
	var curr_g_pos = _body.global_position
	if delta > 0.0001:
		var diff = curr_g_pos - _prev_global_pos
		# Фильтр телепортации: если смещение слишком огромное, считаем скорость 0
		if diff.length_squared() > 4.0: 
			current_velocity = Vector3.ZERO
		else:
			current_velocity = diff / delta
	else:
		current_velocity = Vector3.ZERO
		
	_prev_global_pos = curr_g_pos

# --- ДВИЖЕНИЕ ---
func _start_move_cycle(start_from_ratio: float = 0.0, is_returning: bool = false) -> void:
	if is_collapsing or not _body: return
	
	var distance = start_pos.distance_to(target_pos)
	var full_duration = distance / max(speed, 0.1)
	
	if tween: tween.kill()
	tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	if not is_returning:
		var remaining_duration = full_duration * (1.0 - start_from_ratio)
		if remaining_duration > 0.01:
			tween.tween_property(_body, "position", target_pos, remaining_duration)\
				.set_trans(transition_type).set_ease(ease_type)
		
		tween.tween_interval(pause_at_ends)
		tween.tween_property(_body, "position", start_pos, full_duration)\
			.set_trans(transition_type).set_ease(ease_type)
		tween.tween_interval(pause_at_ends)
	else:
		var remaining_duration = full_duration * (1.0 - start_from_ratio)
		if remaining_duration > 0.01:
			tween.tween_property(_body, "position", start_pos, remaining_duration)\
				.set_trans(transition_type).set_ease(ease_type)
		tween.tween_interval(pause_at_ends)

	tween.finished.connect(func(): _start_full_loop())

func _start_full_loop():
	if is_collapsing or not _body: return
	var distance = start_pos.distance_to(target_pos)
	var duration = distance / max(speed, 0.1)
	
	if tween: tween.kill()
	tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	tween.tween_property(_body, "position", target_pos, duration)\
		.set_trans(transition_type).set_ease(ease_type)
	tween.tween_interval(pause_at_ends)
	tween.tween_property(_body, "position", start_pos, duration)\
		.set_trans(transition_type).set_ease(ease_type)
	tween.tween_interval(pause_at_ends)
	tween.set_loops()

# --- УТИЛИТЫ ---
func _update_platform_position():
	if not _body:
		_initialize_nodes()
		if not _body: return
	var current_target = Vector3.ZERO.lerp(move_offset, preview_progress)
	_body.position = current_target

# --- РАЗРУШЕНИЕ ---
func _on_player_stepped(body: Node3D) -> void:
	if not is_fragile or is_collapsing: return
	if body.is_in_group("player"):
		_start_collapse()

func _start_collapse() -> void:
	is_collapsing = true
	if tween: tween.kill()
	
	var shake_tween = create_tween()
	var shake_count = 10
	var shake_duration = collapse_delay / float(shake_count)
	for i in range(shake_count):
		var offset = Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))
		shake_tween.tween_property(_body, "position", _body.position + offset, shake_duration)
		shake_tween.tween_property(_body, "position", _body.position - offset, shake_duration)
	await shake_tween.finished
	
	_set_collision(false)
	var fall_tween = create_tween()
	fall_tween.tween_property(_body, "position:y", _body.position.y - 10.0, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.parallel().tween_property(_body, "scale", Vector3.ZERO, 0.5)
	await fall_tween.finished
	
	if respawn_time > 0:
		await get_tree().create_timer(respawn_time).timeout
		_reset_platform()

func _reset_platform() -> void:
	_body.position = start_pos
	_body.scale = Vector3.ONE
	_set_collision(true)
	is_collapsing = false
	if enabled:
		_start_full_loop()

func _set_collision(is_active: bool) -> void:
	if not _body: return
	var col = _body.find_child("CollisionShape3D", true, false)
	if col: col.set_deferred("disabled", not is_active)

# --- ДЕБАГ ---
func _setup_debug_drawing():
	if not has_node("DebugPathLines"):
		debug_mesh_instance = MeshInstance3D.new()
		debug_mesh_instance.name = "DebugPathLines"
		debug_mesh = ImmediateMesh.new()
		debug_mesh_instance.mesh = debug_mesh
		var mat = StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.5, 0.0)
		debug_mesh_instance.material_override = mat
		add_child(debug_mesh_instance)
	else:
		debug_mesh_instance = get_node("DebugPathLines")
		debug_mesh = debug_mesh_instance.mesh

func _update_debug_line():
	if not debug_mesh: return
	debug_mesh.clear_surfaces()
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	debug_mesh.surface_add_vertex(Vector3.ZERO)
	debug_mesh.surface_add_vertex(move_offset)
	debug_mesh.surface_end()
