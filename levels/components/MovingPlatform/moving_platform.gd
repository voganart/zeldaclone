extends Node3D

@export_category("Movement")
@export var speed: float = 3.0
@export var pause_at_ends: float = 1.0
@export var enabled: bool = true

@export_category("Destruction")
@export var is_fragile: bool = false ## Если true, платформа упадет
@export var collapse_delay: float = 1.0 ## Время дрожания перед падением
@export var respawn_time: float = 3.0 ## Через сколько вернется (0 = никогда)

@onready var platform_body: AnimatableBody3D = $PlatformBody
@onready var end_point_node: Marker3D = $EndPoint
@onready var trigger_area: Area3D = $PlatformBody/TriggerArea

var start_pos: Vector3
var target_pos: Vector3
var tween: Tween

var is_collapsing: bool = false
var original_y: float

func _ready() -> void:
	# Запоминаем локальные координаты относительно родителя
	start_pos = platform_body.position
	target_pos = end_point_node.position
	original_y = start_pos.y
	
	# Скрываем маркер в игре
	if end_point_node: end_point_node.visible = false
	
	# Подключаем триггер разрушения
	if is_fragile:
		trigger_area.body_entered.connect(_on_player_stepped)
	
	if enabled:
		_start_move_cycle()

# --- ЛОГИКА ДВИЖЕНИЯ ---
func _start_move_cycle() -> void:
	if is_collapsing: return # Не двигаемся, если падаем
	
	# Рассчитываем время пути: Время = Расстояние / Скорость
	var distance = start_pos.distance_to(target_pos)
	var duration = distance / max(speed, 0.1)
	
	# Создаем Tween для движения
	if tween: tween.kill()
	tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	# 1. Движение к цели
	tween.tween_property(platform_body, "position", target_pos, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(pause_at_ends)
	
	# 2. Движение обратно
	tween.tween_property(platform_body, "position", start_pos, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(pause_at_ends)
	
	# 3. Зацикливаем
	tween.finished.connect(_start_move_cycle)

# --- ЛОГИКА РАЗРУШЕНИЯ ---
func _on_player_stepped(body: Node3D) -> void:
	if not is_fragile or is_collapsing: return
	if body.is_in_group("player"):
		_start_collapse()

func _start_collapse() -> void:
	is_collapsing = true
	if tween: tween.kill() # Останавливаем движение
	
	# 1. Фаза тряски (Shake)
	var shake_tween = create_tween()
	var shake_count = 10
	var shake_duration = collapse_delay / float(shake_count)
	
	for i in range(shake_count):
		var offset = Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))
		shake_tween.tween_property(platform_body, "position", platform_body.position + offset, shake_duration)
		shake_tween.tween_property(platform_body, "position", platform_body.position - offset, shake_duration)
	
	await shake_tween.finished
	
	# 2. Фаза падения
	# Отключаем коллизию, чтобы игрок упал сквозь (или можно уронить саму платформу физически)
	_set_collision(false)
	
	var fall_tween = create_tween()
	fall_tween.tween_property(platform_body, "position:y", platform_body.position.y - 10.0, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.parallel().tween_property(platform_body, "scale", Vector3.ZERO, 0.5)
	
	await fall_tween.finished
	
	# 3. Респавн (если нужно)
	if respawn_time > 0:
		await get_tree().create_timer(respawn_time).timeout
		_reset_platform()

func _reset_platform() -> void:
	platform_body.position = start_pos
	platform_body.scale = Vector3.ONE
	_set_collision(true)
	is_collapsing = false
	if enabled:
		_start_move_cycle()

func _set_collision(is_active: bool) -> void:
	var col = platform_body.get_node_or_null("CollisionShape3D")
	if col: col.set_deferred("disabled", not is_active)
