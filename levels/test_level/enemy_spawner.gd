extends Node3D

@export var enemy_scene: PackedScene
@export var enemy_parent: NodePath = ".." # куда спавнить врагов
@onready var area: CollisionShape3D = $Area3D/CollisionShape3D
@onready var label: Label = $Container/BoxContainer/EnemyCounter
var enemy_count: int = 0

func _ready():
	enemy_count = 0
	# Подпишемся на всех врагов в проекте, которые в группе "enemies"
	for enemy in get_tree().get_nodes_in_group(GameConstants.GROUP_ENEMIES):
		enemy_count += 1
		# Подключаемся только если у врага есть сигнал и еще нет подключения
		if enemy.has_signal("died") and not enemy.is_connected("died", Callable(self, "_on_enemy_died")):
			enemy.connect("died", Callable(self, "_on_enemy_died"))
	_update_label()
	
func _update_label():
	label.text = "Врагов осталось: %d" % enemy_count
	
func _input(event):
	if event.is_action_pressed(GameConstants.INPUT_SPAWN):
		_spawn_enemy_inside()

func _spawn_enemy_inside():
	if enemy_scene == null:
		push_warning("EnemySpawner: enemy_scene is not assigned!")
		return

	var shape = area.shape
	if not (shape is BoxShape3D):
		push_warning("EnemySpawner: CollisionShape3D must use BoxShape3D!")
		return

	var extents: Vector3 = shape.size * 0.5
	var random_pos = Vector3(
		randf_range(-extents.x, extents.x),
		randf_range(-extents.y, extents.y),
		randf_range(-extents.z, extents.z)
	)

	var enemy = enemy_scene.instantiate()
	var parent_node = get_node(enemy_parent)
	parent_node.add_child(enemy)

	# позиционируем
	enemy.global_transform = Transform3D(enemy.global_transform.basis, global_transform.origin + random_pos)

	# убедимся, что враг в группе (на всякий случай)
	enemy.add_to_group(GameConstants.GROUP_ENEMIES)

	# подключаем сигнал до увеличения счётчика
	if enemy.has_signal("died"):
		enemy.connect("died", Callable(self, "_on_enemy_died"))
	else:
		push_warning("Spawned enemy has no 'died' signal — _on_enemy_died won't be called.")

	# инициализация и старт состояния
	await get_tree().process_frame
	if enemy.has_method("initialize_navigation"):
		enemy.initialize_navigation()
	if enemy.has_method("enter_state"):
		enemy.enter_state(enemy.State.PATROL)

	# УВЕЛИЧИВАЕМ СЧЁТЧИК ТОЛЬКО ОДИН РАЗ
	enemy_count += 1
	_update_label()
	print("Spawned enemy, total:", enemy_count)


func _on_enemy_died():
	enemy_count -= 1
	_update_label()
