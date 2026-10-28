extends Node3D

signal cleared

@export var enemy_scene_to_spawn: PackedScene
@export var portal_scene: PackedScene
@export var total_enemies_to_kill: int = 3 # Используется, если waves пуст
@export var max_active_enemies: int = 2 # Сколько одновременно на арене

@export_group("Waves")
@export var waves: Array[int] = [] # Количество врагов в каждой волне
@export var wave_delay: float = 1.5
@export var wave_enemy_scenes: Array[PackedScene] = [] # Враг для каждой волны (иначе enemy_scene_to_spawn)

@export_group("Reward")
@export var reward_node: Node3D # Скрыт до победы (например, сундук)
@export var persistent_id: StringName # Если задан — арена проходится один раз

var active_enemies: int = 0
var enemies_spawned_total: int = 0
var enemies_killed: int = 0
var is_active: bool = false
var is_cleared: bool = false
var current_wave: int = 0

@onready var barriers = $Barriers
@onready var dressing: Node3D = get_node_or_null("Dressing")
@onready var spawn_positions = $SpawnPositions.get_children()

func _ready():
	# Скрываем барьеры в начале
	if barriers: barriers.visible = false
	# Отключаем коллизию барьеров (если они StaticBody)
	_set_barriers_collision(false)

	if not persistent_id.is_empty() and SaveManager.is_persistent_id_complete(persistent_id):
		is_cleared = true
	_set_reward_visible(is_cleared)

	$TriggerArea.body_entered.connect(_on_player_entered)

func _on_player_entered(body):
	if is_active or is_cleared: return
	if body.is_in_group("player"):
		start_battle()

func start_battle():
	print("Arena Started!")
	is_active = true

	# Включаем барьеры
	if barriers: barriers.visible = true
	_set_barriers_collision(true)
	if dressing: dressing.set_active(true)

	_start_wave(0)

func _start_wave(index: int):
	current_wave = index
	enemies_spawned_total = 0
	enemies_killed = 0
	_try_spawn_next()

func _get_wave_size() -> int:
	if waves.is_empty():
		return total_enemies_to_kill
	return waves[current_wave]

func _try_spawn_next():
	# Пока не достигли лимита спавна и лимита активных
	while active_enemies < max_active_enemies and enemies_spawned_total < _get_wave_size():
		_spawn_one_enemy()
		await get_tree().create_timer(0.5).timeout # Небольшая пауза между спавнами
		if not is_inside_tree(): return

func _spawn_one_enemy():
	if not portal_scene: return

	enemies_spawned_total += 1
	active_enemies += 1

	# Выбираем случайную точку
	var pos_node = spawn_positions.pick_random()

	# Создаем ПОРТАЛ
	var portal = portal_scene.instantiate()
	portal.enemy_scene = enemy_scene_to_spawn
	if current_wave < wave_enemy_scenes.size() and wave_enemy_scenes[current_wave]:
		portal.enemy_scene = wave_enemy_scenes[current_wave]
	add_child(portal)
	portal.global_position = pos_node.global_position

	# Подписываемся на спавн врага из портала
	portal.enemy_spawned.connect(_on_enemy_spawned_from_portal)

	# Запускаем
	portal.spawn()

func _on_enemy_spawned_from_portal(enemy):
	# Подписываемся на смерть врага
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)

func _on_enemy_died():
	active_enemies -= 1
	enemies_killed += 1

	if enemies_killed < _get_wave_size():
		_try_spawn_next()
	elif current_wave + 1 < waves.size():
		await get_tree().create_timer(wave_delay).timeout
		if not is_inside_tree(): return
		_start_wave(current_wave + 1)
	else:
		end_battle()

func end_battle():
	print("Arena Cleared!")
	is_active = false
	is_cleared = true

	# Убираем барьеры
	if barriers: barriers.visible = false
	_set_barriers_collision(false)
	if dressing: dressing.set_active(false)

	_set_reward_visible(true)
	if not persistent_id.is_empty():
		SaveManager.complete_persistent_id(persistent_id)
	cleared.emit()

func _set_reward_visible(value: bool):
	if not reward_node: return
	reward_node.visible = value
	reward_node.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED

func _set_barriers_collision(enabled: bool):
	if not barriers: return

	# Запускаем рекурсивный поиск по всему дереву узлов внутри Barriers
	_apply_collision_recursive(barriers, enabled)

func _apply_collision_recursive(node: Node, enabled: bool):
	# 1. Если это CSG (включая CSGPolygon3D)
	if node is CSGShape3D:
		node.use_collision = enabled

	# 2. Если это StaticBody3D (обычные меши)
	elif node is CollisionObject3D:
		for sub_child in node.get_children():
			if sub_child is CollisionShape3D or sub_child is CollisionPolygon3D:
				sub_child.set_deferred("disabled", not enabled)

	# Рекурсия: заходим во всех детей текущего узла
	for child in node.get_children():
		_apply_collision_recursive(child, enabled)
