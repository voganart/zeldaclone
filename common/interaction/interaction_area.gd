class_name InteractionArea
extends Area3D

@export var action_label: String = "Interact"
var interact: Callable = func(): pass

func _ready():
	collision_layer = 0 
	collision_mask = 1 # Слой игрока (проверь свои слои!)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body is Player:
		InteractionManager.register_area(self)
		# Тут можно показать UI подсказку "E"

func _on_body_exited(body):
	if body is Player:
		InteractionManager.unregister_area(self)
		# Тут скрыть UI подсказку
