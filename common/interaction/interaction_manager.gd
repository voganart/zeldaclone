extends Node

var active_areas: Array[InteractionArea] = []
var player: Player

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_area(area: InteractionArea):
	active_areas.append(area)

func unregister_area(area: InteractionArea):
	active_areas.erase(area)

func _process(_delta):
	# 1. Очищаем список от удаленных объектов (на всякий случай)
	active_areas = active_areas.filter(func(area): return is_instance_valid(area))
	
	if active_areas.is_empty():
		return

	# 2. Проверяем игрока ДО сортировки
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return # Если игрока всё еще нет, сортировать нет смысла

	# 3. Сортируем только если областей больше одной
	if active_areas.size() > 1:
		var p_pos = player.global_position
		active_areas.sort_custom(func(a, b):
			var dist_a = a.global_position.distance_squared_to(p_pos)
			var dist_b = b.global_position.distance_squared_to(p_pos)
			return dist_a < dist_b
		)
	
	# 4. Взаимодействие с ближайшим
	if Input.is_action_just_pressed("interact"):
		active_areas[0].interact.call()
