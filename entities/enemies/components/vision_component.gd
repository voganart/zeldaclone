class_name VisionComponent
extends Node3D

@export_group("Detection")
@export var sight_range: float = 10.0
@export var lost_sight_range: float = 15.0
@export_range(0, 360) var sight_angle: float = 120.0 # Field of view in degrees
@export var proximity_detection_range: float = 3.0 # Detect player in 360 degrees if overly close
@export var eye_height_offset: float = 1.0 # Height of enemy eyes
@export var player_height_offset: float = 0.5 # Height of player target point
@export var debug_vision: bool = false # Draw debug info for vision

# Debug Visuals
var debug_sight_mesh: MeshInstance3D
var debug_proximity_mesh: MeshInstance3D

# Ссылка на владельца (Enemy), чтобы исключать его из RayCast
@onready var actor: Node3D = get_parent()

func _ready() -> void:
	if debug_vision:
		_setup_debug_meshes()

func _process(_delta: float) -> void:
	if debug_vision:
		_update_debug_meshes()

## Основной метод проверки видимости цели
func can_see_target(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false
	
	# Используем глобальную позицию владельца компонента
	var owner_pos = actor.global_position
	var dist = owner_pos.distance_to(target.global_position)
	
	# 1. Absolute Range Check
	if dist > sight_range:
		return false
	
	# 2. Field of View (FOV) & Proximity Check
	# If player is within proximity range, they are detected 360 degrees (blind spot mitigation)
	# Otherwise, we check the view angle.
	var in_proximity = dist <= proximity_detection_range
	
	if not in_proximity:
		var direction_to_target = (target.global_position - owner_pos).normalized()
		# Assuming standard forward is -Z in local space, transformed to global
		var forward_vector = actor.global_transform.basis.z
		
		# Calculate angle
		var angle_to_target = rad_to_deg(forward_vector.angle_to(direction_to_target))
		
		# If angle is outside half of the FOV, we can't see them
		if angle_to_target > sight_angle / 2.0:
			return false

	# 3. Physical Line of Sight (Raycast)
	# Even if close or in angle, walls should block vision.
	var space_state = get_world_3d().direct_space_state
	
	# Считаем точку глаз от позиции владельца + оффсет
	var origin_pos = owner_pos + Vector3(0, eye_height_offset, 0)
	var target_pos = target.global_position + Vector3(0, player_height_offset, 0)
	
	var query = PhysicsRayQueryParameters3D.create(origin_pos, target_pos)
	query.exclude = [self, actor] # Don't hit self or component owner
	# query.collision_mask = 1 # Optional: Define vision layers if needed
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider == target:
			if debug_vision:
				# print("Target Seen! Dist: %.1f" % dist)
				pass
			return true
		else:
			if debug_vision:
				# print("Vision blocked by: ", result.collider.name)
				pass
			return false
	
	return false

# ============================================================================
# DEBUG VISUALIZATION
# ============================================================================
func _setup_debug_meshes() -> void:
	# 1. Sight Range Sphere (Yellow)
	debug_sight_mesh = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.1) # Transparent Yellow
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # See from inside
	sphere_mesh.material = mat
	debug_sight_mesh.mesh = sphere_mesh
	add_child(debug_sight_mesh)
	
	# 2. Proximity Range Sphere (Red)
	debug_proximity_mesh = MeshInstance3D.new()
	var prox_mesh = SphereMesh.new()
	var prox_mat = StandardMaterial3D.new()
	prox_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.5) # Transparent Red
	prox_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	prox_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	prox_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	prox_mesh.material = prox_mat
	debug_proximity_mesh.mesh = prox_mesh
	add_child(debug_proximity_mesh)

func _update_debug_meshes() -> void:
	if debug_sight_mesh:
		debug_sight_mesh.scale = Vector3(sight_range * 2, sight_range * 2, sight_range * 2)

	if debug_proximity_mesh:
		debug_proximity_mesh.scale = Vector3(proximity_detection_range * 2, proximity_detection_range * 2, proximity_detection_range * 2)
