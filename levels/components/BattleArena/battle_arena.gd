extends Node3D

@export var enemy_scene_to_spawn: PackedScene
@export var portal_scene: PackedScene
@export var total_enemies_to_kill: int = 3
@export var max_active_enemies: int = 2 # Сколько одновременно на арене

var active_enemies: int = 0
var enemies_spawned_total: int = 0
var enemies_killed: int = 0
var is_active: bool = false
var is_cleared: bool = false

@onready var barriers = $Barriers
@onready var spawn_positions = $SpawnPositions.get_children()

func _ready():
	# Скрываем барьеры в начале
	if barriers: barriers.visible = false
	# Отключаем коллизию барьеров (если они StaticBody)
	_set_barriers_collision(false)
	
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
	
	# Запускаем спавн
	_try_spawn_next()

func _try_spawn_next():
	# Пока не достигли лимита спавна и лимита активных
	while active_enemies < max_active_enemies and enemies_spawned_total < total_enemies_to_kill:
		_spawn_one_enemy()
		await get_tree().create_timer(0.5).timeout # Небольшая пауза между спавнами

func _spawn_one_enemy():
	if not portal_scene: return
	
	enemies_spawned_total += 1
	active_enemies += 1
	
	# Выбираем случайную точку
	var pos_node = spawn_positions.pick_random()
	
	# Создаем ПОРТАЛ
	var portal = portal_scene.instantiate()
	portal.enemy_scene = enemy_scene_to_spawn
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
	
	if enemies_killed >= total_enemies_to_kill:
		end_battle()
	else:
		_try_spawn_next()

func end_battle():
	print("Arena Cleared!")
	is_active = false
	is_cleared = true
	
	# Убираем барьеры
	if barriers: barriers.visible = false
	_set_barriers_collision(false)
	
	# Тут можно заспавнить награду (Сундук)
	# spawn_chest()

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
