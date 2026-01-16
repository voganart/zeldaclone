class_name InteractionArea
extends Area3D

# Сигнал, который срабатывает при нажатии кнопки взаимодействия
signal triggered

@export var action_label_key: String = "ui_interact" # Текст подсказки (ключ локализации)
@export var input_action: String = "interact" # Кнопка (E, F, Квадрат и т.д.)
@export var hint_offset: Vector3 = Vector3(0, 1.0, 0) # Высота подсказки над объектом

# --- НОВОЕ: Настройка размера ---
@export var prompt_scale: float = 1.0 # 0.5 сделает её в 2 раза меньше

const HINT_SCENE = preload("res://ui/3d_prompts/InteractionHint3D.tscn")

# Для обратной совместимости с кодом (сундуки)
var interact_callable: Callable = Callable()

var _hint_instance: Node3D = null

func _ready():
	# Слой 0 не сталкивается ни с чем, кроме того что в маске
	collision_layer = 0 
	# Маска 2 (Игрок). Убедись, что слой игрока - это 2. 
	set_collision_mask_value(2, true) 
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# Эту функцию вызывает InteractionManager, когда игрок жмет кнопку
func do_interact():
	# 1. Испускаем сигнал (для объектов, настроенных через редактор)
	triggered.emit()
	
	# 2. Вызываем функцию (для объектов, настроенных через код, типа сундуков)
	if interact_callable.is_valid():
		interact_callable.call()

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
	
	# --- ПРИМЕНЯЕМ МАСШТАБ ---
	# Важно задать это ДО add_child, чтобы _ready в hint_script подхватил правильное значение
	_hint_instance.target_scale_val = Vector3(prompt_scale, prompt_scale, prompt_scale)
	
	add_child(_hint_instance)
	_hint_instance.position = hint_offset
	# Передаем tr(action_label_key) для перевода
	_hint_instance.setup(input_action, tr(action_label_key))

func _hide_hint():
	if is_instance_valid(_hint_instance):
		_hint_instance.close()
	_hint_instance = null
