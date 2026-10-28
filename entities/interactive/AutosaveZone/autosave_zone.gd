class_name AutosaveZone
extends Area3D

## Автосохранение при входе игрока в ключевое место.
## Точка возрождения — дочерний SpawnPoint (или сама зона).

@export var checkpoint_id: StringName


func _ready() -> void:
	add_to_group("memory_nodes")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if checkpoint_id.is_empty():
		push_warning("AutosaveZone requires checkpoint_id")
		return
	if PlayerData.active_checkpoint_id == String(checkpoint_id):
		return

	var current_scene := get_tree().current_scene
	if not current_scene:
		return
	if SaveManager.save_checkpoint(current_scene.scene_file_path, checkpoint_id) == OK:
		GameEvents.save_feedback_requested.emit(&"save_autosaved")


func get_spawn_transform() -> Transform3D:
	var spawn_point := get_node_or_null("SpawnPoint") as Node3D
	return spawn_point.global_transform if spawn_point else global_transform
