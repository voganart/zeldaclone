extends Node3D

@export_group("Settings")
@export var is_opened: bool = false
@export var ability_to_unlock: String = "" # Например: "air_dash" или "ground_slam"

@export_group("Loot Pool")
# Здесь мы пишем индексы предметов из ItemPool. 
# Например: [0, 0, 0, 1] означает 3 предмета с индексом 0 (монеты) и 1 предмет с индексом 1 (сердце)
@export var loot_indices: Array[int] = [0, 0, 0] 

@export_group("Fountain Settings")
@export var up_velocity_min: float = 5.0  # Минимальная высота подлета
@export var up_velocity_max: float = 8.0  # Максимальная высота подлета
@export var spread_velocity: float = 3.0  # Насколько широко разлетаются в стороны
@export var launch_force_min: float = 4.0
@export var launch_force_max: float = 8.0
@export var spawn_interval: float = 0.1
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
	if ability_to_unlock != "":
		_unlock_ability_logic()
	
	if loot_indices.is_empty(): return
	
	for index in loot_indices:
		if not is_instance_valid(spawn_point): return
		
		# 1. Спавним
		var item = ItemPool.spawn_item(index, spawn_point.global_position)
		if not item: continue
		
		# (Тут твой код скейла/твина, если он есть)
		
		# 2. Считаем математику
		var angle = randf() * TAU 
		var horizontal_dir = Vector3(cos(angle), 0, sin(angle))
		
		var up_speed = randf_range(up_velocity_min, up_velocity_max)
		var side_speed = randf_range(spread_velocity * 0.5, spread_velocity)
		
		# 3. ПРИМЕНЯЕМ СИЛУ СРАЗУ ЖЕ
		item.linear_velocity = Vector3.ZERO
		item.angular_velocity = Vector3.ZERO
		
		item.linear_velocity = Vector3(0, up_speed, 0) + (horizontal_dir * side_speed)
		
		# 4. И ТОЛЬКО ТЕПЕРЬ ЖДЕМ перед следующим предметом
		await get_tree().create_timer(spawn_interval).timeout

func _unlock_ability_logic():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("Ability UNLOCKED: ", ability_to_unlock)
		# TODO: Здесь можно добавить вызов UI с поздравлением
		
		if ability_to_unlock == "air_dash" and player.air_dash_ability:
			player.air_dash_ability.is_unlocked = true
		elif ability_to_unlock == "ground_slam" and player.ground_slam_ability:
			player.ground_slam_ability.is_unlocked = true
