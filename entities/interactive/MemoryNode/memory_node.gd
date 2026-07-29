class_name MemoryNode
extends Node3D

@export var checkpoint_id: StringName

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var light: OmniLight3D = $OmniLight3D
@onready var crystal: MeshInstance3D = $Crystal
@onready var activation_vfx: GPUParticles3D = $ActivationVfx

var _active := false
var _pulse_tween: Tween


func _ready() -> void:
	interaction_area.interact_callable = _on_interact
	if not SaveManager.checkpoint_changed.is_connected(_on_checkpoint_changed):
		SaveManager.checkpoint_changed.connect(_on_checkpoint_changed)
	_set_active(PlayerData.active_checkpoint_id == String(checkpoint_id))


func _on_interact() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		activate(player)


func activate(player: Node) -> void:
	if checkpoint_id.is_empty():
		push_warning("MemoryNode requires checkpoint_id")
		return

	var health_component: Node = player.get("health_component")
	if health_component:
		health_component.heal(health_component.max_health)

	var current_scene := get_tree().current_scene
	if not current_scene:
		return
	if (
		SaveManager.save_checkpoint(
			current_scene.scene_file_path,
			checkpoint_id
		)
		!= OK
	):
		return

	_set_active(true)
	_play_activation_feedback()
	GameEvents.save_feedback_requested.emit(&"save_memory_anchored")


func get_spawn_transform() -> Transform3D:
	return spawn_point.global_transform


func is_active() -> bool:
	return _active


func _on_checkpoint_changed(new_checkpoint_id: StringName) -> void:
	_set_active(new_checkpoint_id == checkpoint_id)


func _set_active(value: bool) -> void:
	_active = value
	light.light_energy = 2.0 if value else 0.35
	crystal.scale = Vector3.ONE * (1.1 if value else 0.9)


func _play_activation_feedback() -> void:
	activation_vfx.restart()
	activation_vfx.emitting = true
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(light, "light_energy", 5.0, 0.15)
	_pulse_tween.tween_property(light, "light_energy", 2.0, 0.65)
