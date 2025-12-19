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
		_show_debug_indicator(enemy, true) # Показываем метку
		print("[AI] Token GRANTED: ", enemy.name)
		return true
		
	return false

func return_attack_token(enemy: Enemy) -> void:
	if enemy in current_attackers:
		current_attackers.erase(enemy)
		_show_debug_indicator(enemy, false) # Скрываем метку
		print("[AI] Token RETURNED: ", enemy.name)

# --- DEBUG VISUALIZATION ---
func _show_debug_indicator(enemy: Enemy, is_active: bool):
	# Пытаемся найти Label3D над головой врага (если есть) или красим его
	# Самый простой способ: менять цвет материала временно (если это не HitFlash)
	# Или просто выводить в консоль (уже сделано выше).
	
	# Вариант с Label3D (создай его программно):
	var label_name = "DebugAttackToken"
	var label = enemy.get_node_or_null(label_name)
	
	if is_active:
		if not label:
			label = Label3D.new()
			label.name = label_name
			label.text = "ATTACKING!"
			label.modulate = Color.RED
			label.font_size = 26
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = Vector3(0, 2.5, 0)
			enemy.add_child(label)
	else:
		if label:
			label.queue_free()
