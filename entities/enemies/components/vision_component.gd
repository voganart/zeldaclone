class_name VisionComponent
extends Node3D

@export_group("Detection")
@export var sight_range: float = 10.0
@export var lost_sight_range: float = 15.0
@export_range(0, 360) var sight_angle: float = 120.0
@export var proximity_detection_range: float = 3.0
@export var eye_height_offset: float = 1.0
@export var player_height_offset: float = 0.5
@export var scan_interval: float = 0.2
@export var debug_vision: bool = false

# Кэшированные ссылки на дебаг-меши
var _debug_sight_mesh: MeshInstance3D
var _debug_proximity_mesh: MeshInstance3D
var _debug_container: Node3D

var _can_see_player: bool = false
var _scan_timer: Timer
var player_target: Node3D 

@onready var actor: Node3D = get_parent()

func _ready() -> void:
	_scan_timer = Timer.new()
	_scan_timer.wait_time = scan_interval + randf_range(-0.05, 0.05)
	_scan_timer.autostart = true
	_scan_timer.one_shot = false
	_scan_timer.timeout.connect(_perform_scan)
	add_child(_scan_timer)
	
	player_target = get_tree().get_first_node_in_group("player")
	
	if debug_vision:
		_setup_debug_meshes()

func _process(_delta: float) -> void:
	if debug_vision:
		if not _debug_container:
			_setup_debug_meshes()
		_update_debug_meshes()
	elif _debug_container:
		_debug_container.visible = false

func can_see_target(target: Node3D) -> bool:
	if not is_instance_valid(target): return false
	if target != player_target: return _check_vision_logic(target)
	return _can_see_player

func _perform_scan() -> void:
	if not is_instance_valid(player_target):
		player_target = get_tree().get_first_node_in_group("player")
		_can_see_player = false
		return
	_can_see_player = _check_vision_logic(player_target)

func _check_vision_logic(target: Node3D) -> bool:
	if not is_instance_valid(target): return false
	
	var owner_pos = actor.global_position
	var dist = owner_pos.distance_to(target.global_position)
	
	if dist > sight_range: return false
	
	var in_proximity = dist <= proximity_detection_range
	
	if not in_proximity:
		var direction_to_target = (target.global_position - owner_pos).normalized()
		var forward_vector = -actor.global_transform.basis.z 
		var angle_to_target = rad_to_deg(forward_vector.angle_to(direction_to_target))
		if angle_to_target > sight_angle / 2.0:
			return false

	var space_state = get_world_3d().direct_space_state
	var origin_pos = owner_pos + Vector3(0, eye_height_offset, 0)
	var target_pos = target.global_position + Vector3(0, player_height_offset, 0)
	
	var query = PhysicsRayQueryParameters3D.create(origin_pos, target_pos)
	query.exclude = [self, actor]
	
	var result = space_state.intersect_ray(query)
	if result: return result.collider == target
	return false

# --- ВОССТАНОВЛЕННЫЙ ДЕБАГ ---

func _setup_debug_meshes() -> void:
	_debug_container = Node3D.new()
	_debug_container.name = "VisionDebugVisuals"
	add_child(_debug_container)

	# Сфера основного зрения (Красная)
	_debug_sight_mesh = MeshInstance3D.new()
	var s_mesh = SphereMesh.new()
	s_mesh.radius = 1.0 # Базовый радиус, будем скейлить
	s_mesh.height = 2.0
	_debug_sight_mesh.mesh = s_mesh
	
	var mat_sight = StandardMaterial3D.new()
	mat_sight.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat_sight.albedo_color = Color(1, 0, 0, 0.1) # Едва заметный красный
	mat_sight.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	_debug_sight_mesh.material_override = mat_sight
	_debug_container.add_child(_debug_sight_mesh)

	# Сфера близости (Зеленая)
	_debug_proximity_mesh = MeshInstance3D.new()
	var p_mesh = SphereMesh.new()
	p_mesh.radius = 1.0
	p_mesh.height = 2.0
	_debug_proximity_mesh.mesh = p_mesh
	
	var mat_prox = StandardMaterial3D.new()
	mat_prox.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat_prox.albedo_color = Color(0, 1, 0, 0.2) # Зеленый чуть ярче
	mat_prox.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	_debug_proximity_mesh.material_override = mat_prox
	_debug_container.add_child(_debug_proximity_mesh)

func _update_debug_meshes() -> void:
	if not _debug_container: return
	
	_debug_container.visible = true
	# Сферы центрируются по высоте "глаз"
	var offset = Vector3(0, eye_height_offset, 0)
	_debug_sight_mesh.position = offset
	_debug_proximity_mesh.position = offset
	
	# Скейлим сферы под текущие настройки радиусов
	_debug_sight_mesh.scale = Vector3.ONE * sight_range
	_debug_proximity_mesh.scale = Vector3.ONE * proximity_detection_range
