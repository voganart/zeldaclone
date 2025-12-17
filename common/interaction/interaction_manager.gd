extends Node

# Ссылка на метку "Press E", которую мы будем показывать над объектом
var label_prefab: Label3D 
var active_areas: Array[InteractionArea] = []
var player: Player

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_area(area: InteractionArea):
	active_areas.append(area)

func unregister_area(area: InteractionArea):
	active_areas.erase(area)

func _process(delta):
	if active_areas.size() > 0 and is_instance_valid(active_areas[0]):
		# Сортируем, чтобы найти ближайшую зону
		active_areas.sort_custom(_sort_by_distance)
		var closest = active_areas[0]
		
		# Если нажали E (нужно добавить Action "interact" в Input Map)
		if Input.is_action_just_pressed("interact"):
			closest.interact.call()
			
func _sort_by_distance(a, b):
	if not player: 
		player = get_tree().get_first_node_in_group("player")
		return false
	var dist_a = a.global_position.distance_squared_to(player.global_position)
	var dist_b = b.global_position.distance_squared_to(player.global_position)
	return dist_a < dist_b
