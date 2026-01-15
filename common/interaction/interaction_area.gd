class_name InteractionArea
extends Area3D

@export var action_label_key: String = "ui_interact" # Ключ локализации (например, "Открыть")
@export var input_action: String = "interact" # Название действия в InputMap
@export var hint_offset: Vector3 = Vector3(0, 1.5, 0)

const HINT_SCENE = preload("res://ui/3d_prompts/InteractionHint3D.tscn")

var interact: Callable = func(): pass
var _hint_instance: Node3D = null

func _ready():
	collision_layer = 0 
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		InteractionManager.register_area(self)
		_show_hint()

func _on_body_exited(body):
	if body.is_in_group("player"):
		InteractionManager.unregister_area(self)
		_hide_hint()

func _show_hint():
	if _hint_instance: return
	_hint_instance = HINT_SCENE.instantiate()
	add_child(_hint_instance)
	_hint_instance.position = hint_offset
	# Передаем tr(action_label_key) для перевода
	_hint_instance.setup(input_action, tr(action_label_key))

func _hide_hint():
	if is_instance_valid(_hint_instance):
		_hint_instance.close()
	_hint_instance = null
