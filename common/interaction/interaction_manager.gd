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
	active_areas = active_areas.filter(func(area): return is_instance_valid(area))
	
	if active_areas.is_empty():
		return

	# --- ЛЕНИВЫЙ ПОИСК ИГРОКА (С ОБНОВЛЕНИЕМ) ---
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player: return 
	# --------------------------------------------

	if active_areas.size() > 1:
		var p_pos = player.global_position
		active_areas.sort_custom(func(a, b):
			var dist_a = a.global_position.distance_squared_to(p_pos)
			var dist_b = b.global_position.distance_squared_to(p_pos)
			return dist_a < dist_b
		)
	
	if Input.is_action_just_pressed("interact"): # Убедись, что action называется "interact" в настройках
		active_areas[0].interact.call()
