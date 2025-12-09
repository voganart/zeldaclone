extends Node3D

@export var enemy_scene: PackedScene
@export var enemy_parent: NodePath = ".."  # куда спавнить врагов
@onready var area: CollisionShape3D = $Area3D/CollisionShape3D

func _input(event):
	if event.is_action_pressed("spawn"):
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

	# корректный порядок: СНАЧАЛА ДОБАВИТЬ, ПОТОМ ПОЗИЦИЯ
	var enemy = enemy_scene.instantiate()
	var parent_node = get_node(enemy_parent)
	parent_node.add_child(enemy)

	enemy.global_position = global_transform.origin + random_pos
	await get_tree().process_frame
	enemy.initialize_navigation()
	enemy.enter_state(enemy.State.PATROL) # важно!
