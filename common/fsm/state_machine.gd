class_name StateMachine
extends Node

## Начальное состояние. Должно быть установлено в инспекторе.
@export var initial_state: State

## Текущее активное состояние.
var current_state: State

## Словарь всех доступных состояний: {"имя_состояния": узел_состояния}
var states: Dictionary = {}

func _ready() -> void:
	# Ожидаем готовности родителя (Entity), чтобы гарантировать доступ к его узлам
	await owner.ready
	
	# Автоматически собираем все дочерние узлы типа State
	for child in get_children():
		if child is State:
			# Приводим имя к нижнему регистру для удобства (например "Idle" -> "idle")
			states[child.name.to_lower()] = child
			
			# Передаем ссылку на владельца (например, Player или Enemy) в состояние
			# Предполагаем, что StateMachine является прямым потомком Entity
			child.entity = get_parent() as CharacterBody3D
			child.state_machine = self
			
			# Подписываемся на сигнал перехода
			child.transitioned.connect(on_child_transition)
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state
	else:
		push_warning("StateMachine: Initial state not set for " + str(get_parent().name))

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

## Обработчик сигнала перехода от состояний
func on_child_transition(state: State, new_state_name: String) -> void:
	# Защита: если сигнал пришел не от текущего состояния, игнорируем его
	if state != current_state:
		return
	
	change_state(new_state_name)

## Метод принудительной смены состояния
func change_state(new_state_name: String) -> void:
	var new_state = states.get(new_state_name.to_lower())
	
	if not new_state:
		push_warning("StateMachine: State does not exist: " + new_state_name)
		return
	
	if current_state:
		current_state.exit()
	
	# Небольшой дебаг для отслеживания переключений (можно убрать в релизе)
	# print("[FSM] " + current_state.name + " -> " + new_state.name)
	
	new_state.enter()
	current_state = new_state
