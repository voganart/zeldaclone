@tool
extends Node3D

@export_category("Editor Actions")
@export var generate_clouds: bool = false : set = _on_generate_btn_pressed

@export_category("Main Settings")
@export var cloud_scene: PackedScene
@export var cloud_count: int = 100

@export_category("Animation")
@export var rotation_speed: float = 0.5

@export_category("Spherical Spawn")
@export var spawn_radius: float = 150.0
@export var shell_thickness: float = 50.0

# !!! НОВЫЕ НАСТРОЙКИ !!!
@export_category("Infinite World")
@export_enum("Skybox (Horizon)", "Fly Through (Recycle)") var mode: int = 0 

# Для режима Fly Through (Recycle)
# Должно быть БОЛЬШЕ чем spawn_radius + (shell_thickness / 2)
# Для твоих настроек ставь минимум 180-200.
@export var recycle_radius: float = 200.0 
# ------------------------

@export_category("Clustering")
@export var use_clustering: bool = true
@export var cluster_count: int = 8
@export var cluster_spread: float = 0.3

@export_category("Random Scale")
@export var scale_min: Vector3 = Vector3(3.0, 1.5, 3.0)
@export var scale_max: Vector3 = Vector3(8.0, 3.0, 8.0)

var player: Node3D

func _on_generate_btn_pressed(value):
	if value:
		spawn_clouds()
		generate_clouds = false

func _ready():
	if not Engine.is_editor_hint():
		call_deferred("spawn_clouds")

func _process(delta):
	if Engine.is_editor_hint(): return

	# 1. Вращение
	rotate_y(deg_to_rad(rotation_speed * delta))
	
	# Ленивый поиск игрока
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return

	var player_pos = player.global_position

	# === РЕЖИМ 0: SKYBOX (ГОРИЗОНТ) ===
	# Облака всегда вокруг игрока, до них нельзя дойти.
	if mode == 0:
		# Двигаем ВЕСЬ контейнер за игроком по X и Z
		# Y не трогаем, чтобы облака не прыгали вместе с прыжком игрока
		global_position.x = player_pos.x
		global_position.z = player_pos.z
		# Высоту можно зафиксировать или плавно менять, если уровень вертикальный
		# global_position.y = lerp(global_position.y, player_pos.y, delta * 0.5)

	# === РЕЖИМ 1: FLY THROUGH (БЕСКОНЕЧНЫЙ ПОЛЕТ) ===
	# Мы летим сквозь облака, старые телепортируются вперед.
	elif mode == 1:
		for cloud in get_children():
			if cloud.global_position.distance_squared_to(player_pos) > (recycle_radius * recycle_radius):
				_respawn_single_cloud_near_player(cloud, player_pos)

func _respawn_single_cloud_near_player(cloud: Node3D, center_pos: Vector3):
	var direction = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-0.5, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()
	
	var dist = spawn_radius + randf_range(-shell_thickness / 2.0, shell_thickness / 2.0)
	var new_global_pos = center_pos + (direction * dist)
	
	cloud.global_position = new_global_pos
	cloud.look_at(Vector3(new_global_pos.x, new_global_pos.y + 100.0, new_global_pos.z), Vector3.UP)

func spawn_clouds():
	if not cloud_scene:
		print("CloudManager: Cloud Scene not assigned!")
		return
	
	var children = get_children()
	for child in children:
		if Engine.is_editor_hint(): child.free()
		else: child.queue_free()
	
	var cluster_centers: Array[Vector3] = []
	if use_clustering:
		for i in range(cluster_count):
			cluster_centers.append(Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)).normalized())

	for i in range(cloud_count):
		var cloud = cloud_scene.instantiate()
		add_child(cloud)
		
		var direction = Vector3.UP
		if use_clustering and cluster_centers.size() > 0:
			var center = cluster_centers.pick_random()
			var offset = Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)) * cluster_spread
			direction = (center + offset).normalized()
		else:
			direction = Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)).normalized()
		
		var dist = spawn_radius + randf_range(-shell_thickness / 2.0, shell_thickness / 2.0)
		
		# Локальная позиция (относительно центра менеджера)
		cloud.position = direction * dist
		
		cloud.look_at(Vector3(0, cloud.position.y, 0), Vector3.UP)
		cloud.rotate_y(deg_to_rad(90.0))
		
		var sx = randf_range(scale_min.x, scale_max.x)
		var sy = randf_range(scale_min.y, scale_max.y)
		var sz = randf_range(scale_min.z, scale_max.z)
		cloud.scale = Vector3(sx, sy, sz)
		
		if Engine.is_editor_hint():
			cloud.owner = get_tree().edited_scene_root
