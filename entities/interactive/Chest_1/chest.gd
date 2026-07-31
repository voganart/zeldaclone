extends Node3D

@export_group("Settings")
@export var is_opened: bool = false
@export var persistent_id: StringName

@export_group("Loot Pool")
@export var loot_entries: Array[ChestLootEntry] = [
	ChestLootEntry.new(),
	ChestLootEntry.new(),
	ChestLootEntry.new(),
]

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
@onready var persistent_state: PersistentState = $PersistentState

var _restoring_persistent_state := false


func _ready() -> void:
	persistent_state.persistent_id = persistent_id
	if persistent_state.is_completed():
		_apply_persistent_open_state()
		return
	if interaction_area:
		interaction_area.interact_callable = Callable(self, "_on_interact")

func _on_interact() -> void:
	if is_opened: return
	open_chest()


func open_chest() -> void:
	is_opened = true
	
	# Запускаем анимацию открытия
	# ВАЖНО: В анимации должен быть Call Method Track, который вызывает spawn_loot()
	anim_player.play("Chest_open")
	
	# Удаляем зону взаимодействия
	if is_instance_valid(interaction_area):
		interaction_area.queue_free()

# Эта функция вызывается из AnimationPlayer
func spawn_loot() -> void:
	if _restoring_persistent_state:
		return
	
	if loot_entries.is_empty(): return
	
	for loot_entry in loot_entries:
		if not loot_entry:
			continue

		var item = ItemPool.spawn_item(loot_entry.item_index, spawn_point.global_position)
		if not item: continue

		if item is SkillPickup:
			item.set_ability_id(loot_entry.ability_id)
			if not loot_entry.ability_id.is_empty():
				persistent_state.mark_completed()
		
		# === КИНЕМАТОГРАФИЧНЫЙ ВЫЛЕТ ===
		
		# 1. Рандомный вектор вылета (Конус вверх)
		var angle = randf() * TAU
		var spread_rad = randf_range(0.2, 1.0)
		var dir = Vector3(cos(angle) * spread_rad, 1.0, sin(angle) * spread_rad).normalized()
		
		# 2. Сила с вариацией
		var force = randf_range(launch_force_min, launch_force_max)
		
		# 3. Вращение (Обязательно для "веса")
		var torque = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		) * 10.0 # Сила вращения
		
		item.apply_impulse(dir * force)
		item.apply_torque_impulse(torque)
		
		# Настройка физики самого предмета (если это RigidBody)
		if item.gravity_scale < 2.0:
			item.gravity_scale = 2.5 # Тяжелое падение
			
		await get_tree().create_timer(spawn_interval).timeout


func _apply_persistent_open_state() -> void:
	_restoring_persistent_state = true
	is_opened = true
	if is_instance_valid(interaction_area):
		interaction_area.queue_free()
	anim_player.play("Chest_open")
	anim_player.seek(anim_player.current_animation_length, true)
	anim_player.pause()
	_restoring_persistent_state = false
