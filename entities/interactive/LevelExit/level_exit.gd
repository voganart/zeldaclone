class_name LevelExit
extends Area3D

## Конец уровня: сообщение, сохранение и возврат в меню.

@export var persistent_id: StringName = &"level_01_complete"
@export var message_key: StringName = &"level_demo_complete"
@export var delay_before_menu: float = 3.0

var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	if not persistent_id.is_empty():
		SaveManager.complete_persistent_id(persistent_id)
	GameEvents.save_feedback_requested.emit(message_key)
	await get_tree().create_timer(delay_before_menu).timeout
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	SceneManager.open_main_menu()
