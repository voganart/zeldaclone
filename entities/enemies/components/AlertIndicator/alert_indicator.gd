extends Node3D

@onready var sprite: Sprite3D = $AlertSprite

@export var aggro_color: Color = Color.YELLOW
@export var attack_color: Color = Color.RED
@export var icon_scale: Vector3 = Vector3(1.0, 1.0, 1.0)

var tween: Tween

func _ready() -> void:
	# Скрываем при старте (масштаб в 0)
	sprite.scale = Vector3.ZERO
	sprite.modulate = aggro_color

## Вызывается, когда враг заметил игрока
func play_aggro() -> void:
	_play_pop_animation(aggro_color, 1.0)

## Вызывается перед атакой
func play_attack_warning(duration: float = 0.5) -> void:
	_play_pop_animation(attack_color, duration)

func _play_pop_animation(color: Color, duration: float) -> void:
	# Убиваем старый твин, если он был
	if tween and tween.is_valid():
		tween.kill()
	
	tween = create_tween()
	sprite.modulate = color
	
	# 1. Pop Up (Быстрое появление с перехлестом scale)
	tween.tween_property(sprite, "scale", icon_scale * 1.2, 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 2. Возврат к нормальному размеру
	tween.tween_property(sprite, "scale", icon_scale, 0.1)
	
	# 3. Удержание (Wait)
	tween.tween_interval(duration)
	
	# 4. Исчезновение (Scale to 0)
	tween.tween_property(sprite, "scale", Vector3.ZERO, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
