extends Node3D

@onready var player_start: Marker3D = $PlayerStart # Убедись, что путь верный

func _ready() -> void:
	# 1. Ждем кадр, чтобы все загрузилось
	await get_tree().process_frame
	
	# 2. Находим игрока
	var player = get_tree().get_first_node_in_group("player")
	
	if player and player_start:
		# 3. Телепортируем и задаем поворот
		player.global_position = player_start.global_position
		player.rotation.y = player_start.rotation.y
		
		# 4. Обновляем безопасную точку респавна у самого игрока
		# Чтобы при падении он вернулся сюда, а не в (0,0,0)
		if "last_safe_position" in player:
			player.last_safe_position = player_start.global_position
