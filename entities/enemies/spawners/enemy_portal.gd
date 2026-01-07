extends Node3D

@export var enemy_scene: PackedScene # Кого спавнить
@export var spawn_delay: float = 1.0 # Задержка перед появлением (пока идет анимация)

signal enemy_spawned(enemy_node)

func spawn():
	# 1. Запуск анимации появления портала
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("open")
	
	# 2. Ждем
	await get_tree().create_timer(spawn_delay).timeout
	
	# 3. Спавним врага
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		get_parent().add_child(enemy) # Добавляем в ту же сцену, где портал
		enemy.global_position = $SpawnPoint.global_position
		enemy.rotation = global_rotation # Чтобы смотрел туда же, куда портал
		
		# Подключаем его к системе (если надо, например к Арене)
		emit_signal("enemy_spawned", enemy)
		
	# 4. Закрываем портал
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("close")
		await $AnimationPlayer.animation_finished
		
	queue_free() # Удаляем портал после использования
