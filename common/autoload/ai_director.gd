extends Node

const MAX_ATTACKERS = 1
const SLOT_COUNT = 8
const SLOT_DISTANCE = 2.5

var current_attackers: Array[Enemy] = []
# Словарь: { slot_index: Enemy_ref }
var occupied_slots: Dictionary = {}

func _ready():
	for i in range(SLOT_COUNT):
		occupied_slots[i] = null

## Запрос свободного слота вокруг игрока
func request_position_slot(enemy: Enemy) -> int:
	# Если враг уже в слоте, возвращаем его
	for i in occupied_slots:
		if occupied_slots[i] == enemy: return i
	
	# Ищем ближайший свободный слот
	var best_slot = -1
	var min_dist = INF
	var player = get_tree().get_first_node_in_group("player")
	if not player: return -1

	for i in range(SLOT_COUNT):
		if occupied_slots[i] == null:
			var slot_pos = get_slot_world_pos(i, player)
			var d = enemy.global_position.distance_to(slot_pos)
			if d < min_dist:
				min_dist = d
				best_slot = i
				
	if best_slot != -1:
		occupied_slots[best_slot] = enemy
	return best_slot

func release_slot(enemy: Enemy):
	for i in occupied_slots:
		if occupied_slots[i] == enemy:
			occupied_slots[i] = null

## Вычисление мировой позиции слота
func get_slot_world_pos(index: int, player: Node3D) -> Vector3:
	var angle = (TAU / SLOT_COUNT) * index
	var offset = Vector3(cos(angle), 0, sin(angle)) * SLOT_DISTANCE
	return player.global_position + offset

func request_attack_token(enemy: Enemy) -> bool:
	if enemy in current_attackers:
		return true
		
	if current_attackers.size() < MAX_ATTACKERS:
		current_attackers.append(enemy)
		print("[AI] Token GRANTED: ", enemy.name)
		return true
		
	return false

func return_attack_token(enemy: Enemy) -> void:
	if enemy in current_attackers:
		current_attackers.erase(enemy)
		print("[AI] Token RETURNED: ", enemy.name)
