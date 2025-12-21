class_name StateMachine
extends Node

@export var initial_state: State
var current_state: State
var states: Dictionary = {}

func init(actor: CharacterBody3D) -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			# Передаем актера
			child.entity = actor
			child.state_machine = self
			
			# БЕЗОПАСНОЕ ПОДКЛЮЧЕНИЕ:
			# Проверяем, не подключен ли уже сигнал, прежде чем подключать
			if not child.transitioned.is_connected(on_child_transition):
				child.transitioned.connect(on_child_transition)
			
	if initial_state:
		# Сначала устанавливаем состояние, потом входим в него
		current_state = initial_state
		current_state.enter()
	else:
		push_warning("StateMachine: Initial state not set")

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func on_child_transition(state: State, new_state_name: String) -> void:
	if state != current_state:
		return
	
	change_state(new_state_name)

func change_state(new_state_name: String) -> void:
	var new_state = states.get(new_state_name.to_lower())
	
	if not new_state:
		push_warning("StateMachine: State does not exist: " + new_state_name)
		return
	
	if current_state:
		current_state.exit()
	
	new_state.enter()
	current_state = new_state
