class_name BasePickup
extends RigidBody3D

@export var pool_index: int = 0
@export var immunity_time: float = 0.5
@export var collect_vfx_index: int = 2 # Индекс эффекта "подбора" в VfxPool

var is_collectable: bool = false
var is_being_collected: bool = false # Защита от двойного подбора
var timer: float = 0.0

func _ready():
	$InteractionArea.body_entered.connect(_on_pickup)

func _process(delta):
	if timer > 0:
		timer -= delta
		if timer <= 0:
			is_collectable = true

func _on_pickup(body):
	# Проверяем, можно ли собирать И не собираем ли мы его прямо сейчас
	if not is_collectable or is_being_collected: return
	
	if body.is_in_group("player"):
		is_being_collected = true # Блокируем повторный вызов
		
		# 1. Применяем эффект сразу (лечим/даем золото)
		_apply_effect(body)
		
		# 2. Спавним VFX на месте предмета
		# Он живет своей жизнью, поэтому исчезновение предмета ему не помешает
		VfxPool.spawn_effect(collect_vfx_index, global_position)
		
		# 3. Анимация исчезновения (Скейл в 0)
		$AnimationPlayer.play("Collect")
		
		# 4. Ждем конца анимации
		await $AnimationPlayer.animation_finished
		
		# 5. Только теперь возвращаем в пул
		ItemPool.return_item(self, pool_index)

# Виртуальная функция
func _apply_effect(_player):
	pass

# Сброс состояния (важно сбросить флаги!)
func reset_state():
	is_collectable = false
	is_being_collected = false # Сбрасываем флаг!
	timer = immunity_time
	
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	
	# Сброс визуала (важно, так как мы скейлили его в ноль)
	$Visuals.scale = Vector3.ONE 
	
	# Запуск анимации появления
	$AnimationPlayer.play("Spawn")
	$AnimationPlayer.queue("Idle")
