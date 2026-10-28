extends Node

const MAX_ATTACKERS = 2
const SLOT_COUNT = 8
const SLOT_DISTANCE = 4.5 ## Кольцо ожидания вокруг игрока
const SLOT_MIN_DISTANCE = 2.0
const SLOT_MAX_NAV_OFFSET = 1.0
const SLOT_WALL_PADDING = 0.8
const SLOT_REFRESH_TIME = 0.2
const RING_ROTATION_SPEED = 0.25 ## рад/с — медленное окружение
const FLANK_WEIGHT = 0.6
const ATTACK_HANDOFF_DELAY = 0.3

var current_attackers: Array[Enemy] = []
var next_attack_time_msec: int = 0
# Словарь: { slot_index: Enemy_ref }
var occupied_slots: Dictionary = {}
var ring_angle: float = 0.0
var _slot_positions: Array[Vector3] = []
var _slot_valid: Array[bool] = []
var _slot_refresh_timer: float = 0.0

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

## Запрос слота вокруг игрока. Слоты — кольцо, которое медленно вращается,
## поэтому стоящие в ожидании враги сами обходят игрока по кругу.
func request_position_slot(enemy: Enemy) -> int:
	for i in occupied_slots:
		if occupied_slots[i] == enemy and _is_slot_valid(i):
			return i
	release_slot(enemy)

	var best_slot = -1
	var best_score = INF
	for i in range(SLOT_COUNT):
		if occupied_slots[i] != null or not _is_slot_valid(i):
			continue
		var score = enemy.global_position.distance_to(_slot_positions[i])
		# Фланкирование: чем дальше от соседей, тем лучше
		score -= _distance_to_nearest_occupied(i) * FLANK_WEIGHT
		if score < best_score:
			best_score = score
			best_slot = i

	if best_slot != -1:
		occupied_slots[best_slot] = enemy
	return best_slot

## Сменить слот (обход с фланга). Возвращает новый индекс или текущий.
func shift_position_slot(enemy: Enemy) -> int:
	var current := -1
	for i in occupied_slots:
		if occupied_slots[i] == enemy:
			current = i
	var candidates: Array[int] = []
	for i in range(SLOT_COUNT):
		if occupied_slots[i] == null and _is_slot_valid(i) and i != current:
			candidates.append(i)
	if candidates.is_empty():
		return current
	# Соседние слоты (±1..2) — короткий обход, а не перебежка через игрока
	candidates.sort_custom(func(a, b): return _ring_distance(a, current) < _ring_distance(b, current))
	var pick = candidates[randi() % mini(2, candidates.size())]
	release_slot(enemy)
	occupied_slots[pick] = enemy
	return pick

func release_slot(enemy: Enemy):
	for i in occupied_slots:
		if occupied_slots[i] == enemy:
			occupied_slots[i] = null

## Вычисление мировой позиции слота (кэшируется раз в SLOT_REFRESH_TIME)
func get_slot_world_pos(index: int, player: Node3D) -> Vector3:
	if index >= 0 and index < _slot_positions.size():
		return _slot_positions[index]
	var angle = ring_angle + (TAU / SLOT_COUNT) * index
	return player.global_position + Vector3(cos(angle), 0, sin(angle)) * SLOT_DISTANCE

func _is_slot_valid(index: int) -> bool:
	return index >= 0 and index < _slot_valid.size() and _slot_valid[index]

func _ring_distance(a: int, b: int) -> int:
	if b < 0: return 0
	var d = abs(a - b)
	return mini(d, SLOT_COUNT - d)

func _distance_to_nearest_occupied(index: int) -> float:
	var best = SLOT_DISTANCE * 2.0
	for i in occupied_slots:
		if i != index and occupied_slots[i] != null and i < _slot_positions.size():
			best = minf(best, _slot_positions[i].distance_to(_slot_positions[index]))
	return best

func _refresh_slots() -> void:
	_slot_positions.resize(SLOT_COUNT)
	_slot_valid.resize(SLOT_COUNT)
	if not is_instance_valid(player_ref):
		_slot_valid.fill(false)
		return
	var world := player_ref.get_world_3d()
	var map := world.navigation_map
	var space := world.direct_space_state
	var center := player_ref.global_position
	var eye := center + Vector3(0, 1.0, 0)
	for i in range(SLOT_COUNT):
		var angle = ring_angle + (TAU / SLOT_COUNT) * i
		var wanted := center + Vector3(cos(angle), 0, sin(angle)) * SLOT_DISTANCE
		# Стены и барьеры: подтягиваем слот к игроку, если между ними препятствие
		var query := PhysicsRayQueryParameters3D.create(eye, wanted + Vector3(0, 1.0, 0))
		query.exclude = [player_ref.get_rid()]
		for _attempt in 3:
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			if hit.collider is StaticBody3D or hit.collider is CSGShape3D:
				var hit_pos: Vector3 = hit.position
				var back: Vector3 = (hit_pos - eye).normalized() * SLOT_WALL_PADDING
				wanted = hit_pos - back
				wanted.y = center.y
				break
			var ex: Array[RID] = query.exclude
			ex.append(hit.rid)
			query.exclude = ex
		# Слот должен стоять на навмеше (не в пропасти и не в стене)
		var on_mesh := NavigationServer3D.map_get_closest_point(map, wanted)
		var flat_offset := Vector2(on_mesh.x - wanted.x, on_mesh.z - wanted.z).length()
		_slot_positions[i] = on_mesh
		_slot_valid[i] = flat_offset < SLOT_MAX_NAV_OFFSET and absf(on_mesh.y - center.y) < 2.0 and on_mesh.distance_to(center) > SLOT_MIN_DISTANCE

func request_attack_token(enemy: Enemy) -> bool:
	if enemy in current_attackers:
		return true

	var time_now = Time.get_ticks_msec()
	if time_now < next_attack_time_msec:
		return false
		
	if current_attackers.size() < MAX_ATTACKERS:
		current_attackers.append(enemy)
		next_attack_time_msec = time_now + int(ATTACK_HANDOFF_DELAY * 1000.0)
		return true
		
	return false

func return_attack_token(enemy: Enemy) -> void:
	if enemy in current_attackers:
		current_attackers.erase(enemy)
		next_attack_time_msec = Time.get_ticks_msec() + int(ATTACK_HANDOFF_DELAY * 1000.0)

func _physics_process(delta: float) -> void:
	ring_angle = wrapf(ring_angle + RING_ROTATION_SPEED * delta, 0.0, TAU)
	for i in occupied_slots:
		if occupied_slots[i] != null and not is_instance_valid(occupied_slots[i]):
			occupied_slots[i] = null
	for i in range(current_attackers.size() - 1, -1, -1):
		if not is_instance_valid(current_attackers[i]):
			current_attackers.remove_at(i)
	_slot_refresh_timer -= delta
	if _slot_refresh_timer <= 0.0:
		_slot_refresh_timer = SLOT_REFRESH_TIME
		_refresh_slots()
