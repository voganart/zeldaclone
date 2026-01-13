extends Node

const MAX_ATTACKERS = 2
const SLOT_COUNT = 6
const SLOT_DISTANCE = 2.5

var current_attackers: Array[Enemy] = []
# Словарь: { slot_index: Enemy_ref }
var occupied_slots: Dictionary = {}

# --- Система Animation LOD ---
var registered_enemies: Array[Enemy] = []
var player_ref: Player = null

# --- ИЗМЕНЕНИЕ: Заменяем const на var и задаем значения по умолчанию (HIGH) ---
var anim_lod_dists_sq: Array[float] = [8.0*8.0, 15.0*15.0, 20.0*20.0]
var anim_lod_skips: Array[int] = [2, 5, 15]
# --------------------------------------------------------------------------

var frame_count: int = 0 # Счетчик кадров для распределения нагрузки

func _ready():
	for i in range(SLOT_COUNT):
		occupied_slots[i] = null
	
	# --- НОВОЕ: Подписываемся на сигнал от GraphicsManager ---
	GraphicsManager.quality_changed.connect(_on_quality_changed)

# --- НОВАЯ ФУНКЦИЯ: Обработчик сигнала ---
func _on_quality_changed(settings: Dictionary):
	# Обновляем наши переменные из словаря настроек
	if settings.has("ai_anim_lod_dists_sq"):
		anim_lod_dists_sq = settings["ai_anim_lod_dists_sq"]
	if settings.has("ai_anim_lod_skips"):
		anim_lod_skips = settings["ai_anim_lod_skips"]
	print("AI Director: Animation LODs updated to new quality preset.")

func _process(delta: float):
	frame_count += 1
	if player_ref == null:
		player_ref = get_tree().get_first_node_in_group("player")
		if player_ref == null: return

	if not is_instance_valid(player_ref) or not player_ref.is_inside_tree():
		player_ref = null
		return

	var player_pos = player_ref.global_position

	for enemy in registered_enemies:
		if not is_instance_valid(enemy): continue
		
		if not enemy.anim_tree.active:
			continue
		
		var dist_sq = enemy.global_position.distance_squared_to(player_pos)
		
		# --- ИЗМЕНЕНИЕ: Используем переменные вместо констант ---
		# LOD 0: Близко.
		if dist_sq < anim_lod_dists_sq[0]:
			enemy.set_animation_process_mode(false)
		
		# LOD 1: Средняя дистанция.
		elif dist_sq < anim_lod_dists_sq[1]:
			enemy.set_animation_process_mode(true)
			if (enemy.get_instance_id() + frame_count) % anim_lod_skips[0] == 0:
				enemy.manual_animation_advance(delta * anim_lod_skips[0])
		
		# LOD 2: Далеко.
		elif dist_sq < anim_lod_dists_sq[2]: 
			enemy.set_animation_process_mode(true)
			if (enemy.get_instance_id() + frame_count) % anim_lod_skips[1] == 0:
				enemy.manual_animation_advance(delta * anim_lod_skips[1])
		
		# LOD 3: Очень далеко.
		else: 
			enemy.set_animation_process_mode(true)
			if (enemy.get_instance_id() + frame_count) % anim_lod_skips[2] == 0:
				enemy.manual_animation_advance(delta * anim_lod_skips[2])

func register_enemy(enemy: Enemy):
	if not enemy in registered_enemies:
		registered_enemies.append(enemy)

func unregister_enemy(enemy: Enemy):
	if enemy in registered_enemies:
		enemy.set_animation_process_mode(false)
		registered_enemies.erase(enemy)

## Запрос свободного слота вокруг игрока
func request_position_slot(enemy: Enemy) -> int:
	for i in occupied_slots:
		if occupied_slots[i] == enemy: return i
	
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
