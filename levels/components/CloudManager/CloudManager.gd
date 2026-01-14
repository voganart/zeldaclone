@tool
extends Node3D

@export_category("Editor Actions")
@export var generate_clouds: bool = false : set = _on_generate_btn_pressed

@export_category("Main Settings")
@export var cloud_scene: PackedScene
@export var cloud_count: int = 100

@export_category("Animation")
@export var rotation_speed: float = 0.5 # Скорость вращения (градусов в секунду)

@export_category("Spherical Spawn")
@export var spawn_radius: float = 400.0
@export var shell_thickness: float = 200.0

@export_category("Alignment")
@export var rotation_jitter_degrees: float = 20.0 

@export_category("Clustering")
@export var use_clustering: bool = true
@export var cluster_count: int = 8
@export var cluster_spread: float = 0.3

@export_category("Random Scale")
@export var scale_min: Vector3 = Vector3(3.0, 1.5, 3.0)
@export var scale_max: Vector3 = Vector3(8.0, 3.0, 8.0)

func _on_generate_btn_pressed(value):
	if value:
		spawn_clouds()
		generate_clouds = false

func _ready():
	if not Engine.is_editor_hint():
		call_deferred("spawn_clouds")

func _process(delta):
	# Вращаем сферу только во время игры, чтобы в редакторе облака не уезжали
	if not Engine.is_editor_hint():
		# Вращение вокруг оси Y (вертикальной)
		rotate_y(deg_to_rad(rotation_speed * delta))

func spawn_clouds():
	if not cloud_scene:
		print("CloudManager: Cloud Scene not assigned!")
		return
	
	# Очистка
	var children = get_children()
	for child in children:
		if Engine.is_editor_hint():
			child.free()
		else:
			child.queue_free()
	
	# --- Центры кластеров ---
	var cluster_centers: Array[Vector3] = []
	if use_clustering:
		for i in range(cluster_count):
			var dir = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			).normalized()
			cluster_centers.append(dir)

	# --- Спавн ---
	for i in range(cloud_count):
		var cloud = cloud_scene.instantiate()
		add_child(cloud)
		
		# 1. Позиция
		var direction = Vector3.UP
		
		if use_clustering and cluster_centers.size() > 0:
			var center = cluster_centers.pick_random()
			var offset = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			) * cluster_spread
			direction = (center + offset).normalized()
		else:
			direction = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			).normalized()
		
		var dist = spawn_radius + randf_range(-shell_thickness / 2.0, shell_thickness / 2.0)
		cloud.position = direction * dist
		
		# 2. ПОВОРОТ
		cloud.look_at(Vector3(0.0, cloud.position.y, 0.0), Vector3.UP)
		cloud.rotate_y(deg_to_rad(90.0))
		
		if rotation_jitter_degrees > 0.0:
			var jitter_rad = deg_to_rad(rotation_jitter_degrees)
			cloud.rotate_y(randf_range(-jitter_rad, jitter_rad))
		
		# 3. СКЕЙЛ
		var sx = randf_range(scale_min.x, scale_max.x)
		var sy = randf_range(scale_min.y, scale_max.y)
		var sz = randf_range(scale_min.z, scale_max.z)
		
		cloud.scale = Vector3(sx, sy, sz)
		
		# Для редактора
		if Engine.is_editor_hint():
			cloud.owner = get_tree().edited_scene_root
