extends Node3D

@export_group("Settings")
@export var is_opened: bool = false
@export var ability_to_unlock: String = "" # Например: "air_dash" или "ground_slam"

@export_group("Loot Pool")
# Здесь мы пишем индексы предметов из ItemPool. 
# Например: [0, 0, 0, 1] означает 3 предмета с индексом 0 (монеты) и 1 предмет с индексом 1 (сердце)
@export var loot_indices: Array[int] = [0, 0, 0] 

@export var launch_force_min: float = 4.0
@export var launch_force_max: float = 8.0

# Ссылки
@onready var anim_player = $Chest_1/AnimationPlayer
@onready var interaction_area = $InteractionArea
@onready var spawn_point = $Chest_1/Chest_1_rig/Skeleton3D/Base/LootSpawnPoint

func _ready():
	if interaction_area:
		interaction_area.interact = Callable(self, "_on_interact")

func _on_interact():
	if is_opened: return
	open_chest()

func open_chest():
	is_opened = true
	
	# Запускаем анимацию открытия
	# ВАЖНО: В анимации должен быть Call Method Track, который вызывает spawn_loot()
	anim_player.play("Chest_open")
	
	# Удаляем зону взаимодействия
	if is_instance_valid(interaction_area):
		interaction_area.queue_free()

# Эта функция вызывается из AnimationPlayer
func spawn_loot():
	# 1. Выдача способности
	if ability_to_unlock != "":
		_unlock_ability_logic()
	
	# 2. Спавн предметов через Пул
	if loot_indices.is_empty(): return
	
	for index in loot_indices:
		# Просим пул выдать предмет по индексу
		# Убедись, что ItemPool добавлен в Autoload!
		var item = ItemPool.spawn_item(index, spawn_point.global_position)
		
		if not item: continue
		
		# --- Анимация появления (Скейл из 0.1 в 1.0) ---
		item.scale = Vector3.ONE * 0.1
		var tween = create_tween()
		tween.tween_property(item, "scale", Vector3.ONE, 0.5)\
			.set_trans(Tween.TRANS_ELASTIC)\
			.set_ease(Tween.EASE_OUT)
		# -----------------------------------------------
			
		# Физика вылета (Фонтанчик)
		var random_dir = Vector3(
			randf_range(-0.5, 0.5),
			1.0, # Вверх
			randf_range(-0.5, 0.5)
		).normalized()
		
		var force = randf_range(launch_force_min, launch_force_max)
		
		# Сбрасываем старую скорость (важно для пула!)
		item.linear_velocity = Vector3.ZERO
		item.angular_velocity = Vector3.ZERO
		
		item.apply_central_impulse(random_dir * force)
		item.apply_torque_impulse(Vector3.ONE * randf() * 1.0)

func _unlock_ability_logic():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("Ability UNLOCKED: ", ability_to_unlock)
		# TODO: Здесь можно добавить вызов UI с поздравлением
		
		if ability_to_unlock == "air_dash" and player.air_dash_ability:
			player.air_dash_ability.is_unlocked = true
		elif ability_to_unlock == "ground_slam" and player.ground_slam_ability:
			player.ground_slam_ability.is_unlocked = true
