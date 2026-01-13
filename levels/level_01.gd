extends Node3D

@export_group("Setup")
@export var player_scene: PackedScene 
@export var auto_spawn_player: bool = true

@export_group("References")
@export var player_start: Marker3D 
@export var phantom_camera: PhantomCamera3D 
@export var hud: PlayerHUD 

func _ready() -> void:
	# 1. Принудительно делаем камеру уровня активной
	# Обычно Camera3D является ребенком PhantomCameraHost или лежит рядом
	var main_cam = get_viewport().get_camera_3d()
	if not main_cam:
		# Попытка найти камеру в сцене, если viewport вернул null
		main_cam = find_child("Camera3D", true, false)
		if main_cam:
			main_cam.current = true
			main_cam.add_to_group("main_camera") # Для поиска в Player.gd
			print("Level: Found and set Main Camera to Current.")
	else:
		# Если камера уже есть, просто добавляем в группу для надежности
		if not main_cam.is_in_group("main_camera"):
			main_cam.add_to_group("main_camera")

	# 2. Спавним или ищем игрока
	var current_player = get_tree().get_first_node_in_group("player")
	
	if not current_player and auto_spawn_player and player_scene:
		current_player = _spawn_player()
	
	# 3. ЖДЕМ ОДИН КАДР (ФИКС ОШИБКИ !is_inside_tree)
	await get_tree().process_frame
	
	# 4. Настраиваем всё остальное
	if current_player:
		_setup_camera(current_player)
		_setup_hud(current_player)

func _spawn_player() -> CharacterBody3D:
	var new_player = player_scene.instantiate()
	add_child(new_player) # Добавляем в дерево
	
	if player_start:
		new_player.global_position = player_start.global_position
		new_player.rotation.y = player_start.rotation.y
		
		if "last_safe_position" in new_player:
			new_player.last_safe_position = player_start.global_position
	else:
		new_player.global_position = Vector3.ZERO
		
	return new_player

func _setup_camera(player_node: CharacterBody3D) -> void:
	if not phantom_camera: return
	
	var target_node = player_node.get_node_or_null("CameraTarget")
	if not target_node: target_node = player_node
	
	# 1. СЛЕДИМ за игроком
	phantom_camera.follow_target = target_node
	
	# 2. ВАЖНО: НЕ назначаем LookAt для режима Third Person!
	phantom_camera.look_at_target = null 
	
	if phantom_camera.has_method("snap_to_target"):
		phantom_camera.snap_to_target()
	
	# Устанавливаем начальный поворот
	if phantom_camera.has_method("set_third_person_rotation"):
		var start_yaw = player_start.rotation.y if player_start else 0.0
		var start_pitch = deg_to_rad(-25.0) 
		var target_rot = Vector3(start_pitch, start_yaw, 0)
		phantom_camera.set_third_person_rotation(target_rot)
	else:
		if player_start:
			phantom_camera.global_rotation = player_start.global_rotation

func _setup_hud(player_node: CharacterBody3D) -> void:
	if hud:
		hud.setup_player(player_node)
