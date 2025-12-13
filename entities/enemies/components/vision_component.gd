class_name VisionComponent
extends Node3D

@export_group("Detection")
@export var sight_range: float = 10.0
@export var lost_sight_range: float = 15.0
@export_range(0, 360) var sight_angle: float = 120.0
@export var proximity_detection_range: float = 3.0
@export var eye_height_offset: float = 1.0
@export var player_height_offset: float = 0.5
@export var scan_interval: float = 0.2 # Как часто проверять (сек)
@export var debug_vision: bool = false

# Кэшированный результат
var _can_see_player: bool = false
var _scan_timer: Timer

@onready var actor: Node3D = get_parent()
# Пытаемся найти игрока один раз при старте или обновляем кэш
var player_target: Node3D 

func _ready() -> void:
	# Создаем таймер программно
	_scan_timer = Timer.new()
	_scan_timer.wait_time = scan_interval + randf_range(-0.05, 0.05) # Рандом, чтобы все враги не сканировали в один кадр
	_scan_timer.autostart = true
	_scan_timer.one_shot = false
	_scan_timer.timeout.connect(_perform_scan)
	add_child(_scan_timer)
	
	# Ищем игрока сразу
	player_target = get_tree().get_first_node_in_group("player")
	
	if debug_vision:
		_setup_debug_meshes()

func _process(_delta: float) -> void:
	if debug_vision:
		_update_debug_meshes()

## Публичный метод теперь просто возвращает сохраненное значение
## Это ОЧЕНЬ быстро и не грузит процессор
func can_see_target(target: Node3D) -> bool:
	# 1. Сначала проверяем, существует ли цель вообще
	if not is_instance_valid(target):
		return false
		
	# Если запрашивают не игрока, делаем быструю проверку (редкий кейс)
	if target != player_target:
		return _check_vision_logic(target)
		
	return _can_see_player

## Тяжелая логика перенесена сюда и вызывается таймером
func _perform_scan() -> void:
	if not is_instance_valid(player_target):
		# Пробуем найти игрока снова (вдруг заспавнился)
		player_target = get_tree().get_first_node_in_group("player")
		_can_see_player = false
		return
		
	_can_see_player = _check_vision_logic(player_target)

## Внутренняя логика проверки (RayCast и математика)
func _check_vision_logic(target: Node3D) -> bool:
	# !!! ВАЖНО: Еще одна проверка безопасности перед расчетами
	if not is_instance_valid(target):
		return false
	
	var owner_pos = actor.global_position
	# Ошибка была здесь. Теперь она защищена проверкой выше.
	var dist = owner_pos.distance_to(target.global_position)
	
	if dist > sight_range:
		return false
	
	var in_proximity = dist <= proximity_detection_range
	
	if not in_proximity:
		var direction_to_target = (target.global_position - owner_pos).normalized()
		var forward_vector = -actor.global_transform.basis.z 
		var angle_to_target = rad_to_deg(forward_vector.angle_to(direction_to_target))
		if angle_to_target > sight_angle / 2.0:
			return false

	var space_state = get_world_3d().direct_space_state
	var origin_pos = owner_pos + Vector3(0, eye_height_offset, 0)
	var target_pos = target.global_position + Vector3(0, player_height_offset, 0)
	
	var query = PhysicsRayQueryParameters3D.create(origin_pos, target_pos)
	query.exclude = [self, actor]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.collider == target
	
	return false

# ... (Оставь методы debug meshes как были в оригинале) ...
func _setup_debug_meshes() -> void:
	pass # Вставь код из оригинала если нужен дебаг

func _update_debug_meshes() -> void:
	pass # Вставь код из оригинала если нужен дебаг
