class_name PersistentState
extends Node

@export var persistent_id: StringName

signal completed_on_load


func _ready() -> void:
	if is_completed():
		completed_on_load.emit()


func is_completed() -> bool:
	return (
		not persistent_id.is_empty()
		and SaveManager.is_persistent_id_complete(persistent_id)
	)


func mark_completed() -> bool:
	if persistent_id.is_empty():
		push_warning("PersistentState requires a non-empty persistent_id")
		return false
	return SaveManager.complete_persistent_id(persistent_id)
