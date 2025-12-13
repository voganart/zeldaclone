class_name StateMachine
extends Node

@export var initial_state: State
var current_state: State
var states: Dictionary = {}

# Убираем _ready() и await owner.ready
# Добавляем явный метод инициализации
func init(actor: CharacterBody3D) -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			# Передаем актера явно
			child.entity = actor
			child.state_machine = self
			child.transitioned.connect(on_child_transition)
			
			# Если у состояний есть свой метод init, можно вызвать и его
			# if child.has_method("init"): child.init()
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state
	else:
		push_warning("StateMachine: Initial state not set")


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
