extends Node

const PANEL_SCENE_PATH := "res://ui/debug_panel/debug_panel.tscn"
const ABILITY_NAMES: Array[StringName] = [
	&"roll_ability",
	&"double_jump",
	&"ground_slam",
	&"air_dash",
	&"3_hit_combo",
]

var _panel: CanvasLayer
var _debug_enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_debug_enabled = OS.is_debug_build()
	if not OS.is_debug_build():
		set_process_input(false)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(
		GameConstants.INPUT_DEBUG_PANEL_TOGGLE
	):
		return
	if not is_gameplay_input_blocked() and not _get_player():
		return
	set_panel_open(not is_gameplay_input_blocked())
	get_viewport().set_input_as_handled()


func set_panel_open(value: bool) -> void:
	if not _debug_enabled:
		return
	if value and not _get_player():
		return
	if not _ensure_panel():
		return
	_panel.call("set_open", value)


func is_gameplay_input_blocked() -> bool:
	return (
		_debug_enabled
		and is_instance_valid(_panel)
		and _panel.visible
	)


func restore_health() -> bool:
	var player := _get_player()
	if not player or not player.health_component:
		return false
	player.health_component.heal(player.health_component.max_health)
	return true


func set_vabo(amount: int) -> void:
	PlayerData.set_vabo(amount)


func set_all_abilities(unlocked: bool) -> void:
	for ability_name: StringName in ABILITY_NAMES:
		PlayerData.set_ability_unlocked(ability_name, unlocked)
	var player := _get_player()
	if player:
		player.refresh_progression_from_player_data()


func teleport_to_checkpoint() -> bool:
	var player := _get_player()
	var memory_node := _get_active_memory_node()
	if not player or not memory_node:
		return false
	player.global_transform = memory_node.get_spawn_transform()
	player.velocity = Vector3.ZERO
	return true


func reset_save_and_reload() -> Error:
	var error := SaveManager.clear_save()
	if error != OK:
		return error
	PlayerData.reset_progress()
	set_panel_open(false)
	await SceneManager.reload_current_scene()
	return OK


func reload_level() -> void:
	set_panel_open(false)
	SceneManager.reload_current_scene()


func _ensure_panel() -> bool:
	if is_instance_valid(_panel):
		return true
	var panel_scene := load(PANEL_SCENE_PATH) as PackedScene
	if not panel_scene:
		push_error("DebugTools: debug panel scene is missing")
		return false
	_panel = panel_scene.instantiate() as CanvasLayer
	if not _panel:
		push_error("DebugTools: debug panel root must be CanvasLayer")
		return false
	add_child(_panel)
	return true


func _get_player() -> Player:
	return get_tree().get_first_node_in_group(
		GameConstants.GROUP_PLAYER
	) as Player


func _get_active_memory_node() -> MemoryNode:
	var checkpoint_id := PlayerData.active_checkpoint_id
	if checkpoint_id.is_empty():
		return null
	var current_scene := get_tree().current_scene
	for node: Node in get_tree().get_nodes_in_group("memory_nodes"):
		if (
			node is MemoryNode
			and current_scene
			and current_scene.is_ancestor_of(node)
			and String(node.checkpoint_id) == checkpoint_id
		):
			return node
	return null
