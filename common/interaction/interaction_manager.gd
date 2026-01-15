extends Node

var active_areas: Array[InteractionArea] = []
var player: Player

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_area(area: InteractionArea):
	if not active_areas.has(area):
		active_areas.append(area)

func unregister_area(area: InteractionArea):
	active_areas.erase(area)

func _process(_delta):
	# Удаляем удаленные объекты из списка
	active_areas = active_areas.filter(func(area): return is_instance_valid(area))
	
	if active_areas.is_empty():
		return

	# --- ЛЕНИВЫЙ ПОИСК ИГРОКА ---
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player: return 
	# ----------------------------

	# Сортируем по дистанции, чтобы взаимодействовать с ближайшим
	if active_areas.size() > 1:
		var p_pos = player.global_position
		active_areas.sort_custom(func(a, b):
			var dist_a = a.global_position.distance_squared_to(p_pos)
			var dist_b = b.global_position.distance_squared_to(p_pos)
			return dist_a < dist_b
		)
	
	if Input.is_action_just_pressed("interact"):
		# Вызываем обновленный метод
		active_areas[0].do_interact()
