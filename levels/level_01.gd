extends Node3D

@export_group("Setup")
@export var player_scene: PackedScene 
@export var auto_spawn_player: bool = true

@export_group("References")
@export var player_start: Marker3D 
@export var phantom_camera: PhantomCamera3D 
@export var hud: PlayerHUD 

# Теперь тип TutorialManager должен быть виден (если файл сохранен)
@export var tutorial_manager: TutorialManager 

func _ready() -> void:
	# ... (Код поиска камеры, как был раньше) ...
	var main_cam = get_viewport().get_camera_3d()
	if not main_cam:
		main_cam = find_child("Camera3D", true, false)
		if main_cam:
			main_cam.current = true
			main_cam.add_to_group("main_camera")

	# 1. Спавн игрока
	var current_player = get_tree().get_first_node_in_group("player")
	if not current_player and auto_spawn_player and player_scene:
		current_player = _spawn_player()
	
	# Ждем кадр для инициализации
	await get_tree().process_frame
	
	# 2. Настройка зависимостей
	if current_player:
		_setup_camera(current_player)
		_setup_hud(current_player)
		
		# 3. ЗАПУСК ТУТОРИАЛА
		# Проверяем, что все компоненты на месте
		if tutorial_manager and hud and hud.tutorial_overlay:
			tutorial_manager.setup(current_player, hud.tutorial_overlay)
		else:
			print("Warning: Tutorial system missing components.")
			if not tutorial_manager: print("- TutorialManager node not assigned in Level Inspector")
			if not hud: print("- HUD not assigned")
			elif not hud.tutorial_overlay: print("- TutorialOverlay not found in HUD scene")

# ... (Остальные функции: _spawn_player, _setup_camera, _setup_hud остаются без изменений) ...
func _spawn_player() -> CharacterBody3D:
	var new_player = player_scene.instantiate()
	add_child(new_player)
	if player_start:
		new_player.global_position = player_start.global_position
		new_player.rotation.y = player_start.rotation.y
	return new_player

func _setup_camera(player_node: CharacterBody3D) -> void:
	if not phantom_camera: return
	var target_node = player_node.get_node_or_null("CameraTarget")
	if not target_node: target_node = player_node
	phantom_camera.follow_target = target_node
	phantom_camera.look_at_target = null 
	if phantom_camera.has_method("snap_to_target"):
		phantom_camera.snap_to_target()

func _setup_hud(player_node: CharacterBody3D) -> void:
	if hud:
		hud.setup_player(player_node)
