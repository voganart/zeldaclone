extends Node

signal state_changed

const PANEL_SCENE_PATH := "res://ui/debug_panel/debug_panel.tscn"
const AI_TEST_ARENA_PATH := "res://levels/test_level/ai_test_arena.tscn"
const ARENA_SPAWN_GROUP := "ai_arena_spawn_points"
const ABILITY_NAMES: Array[StringName] = [
	&"roll_ability",
	&"double_jump",
	&"ground_slam",
	&"air_dash",
	&"3_hit_combo",
]
const ENEMY_KINDS: Array[StringName] = [&"standard", &"gogo_runt"]
const ENEMY_SCENE_PATHS: Dictionary = {
	&"standard": "res://entities/enemies/enemy.tscn",
	&"gogo_runt": "res://entities/enemies/enemy_gogo_runt.tscn",
}
const SPAWN_DISTANCE := 4.0
const SPAWN_SPACING := 1.5
const SPAWN_HEIGHT := 0.5
const TIME_SCALE_STEPS: Array[float] = [1.0, 0.5, 0.25, 0.1, 2.0]
const MIN_TIME_SCALE := 0.1
const MAX_TIME_SCALE := 2.0

var god_mode := false
var infinite_health := false
var no_cooldowns := false
var enemy_ai_frozen := false
var enemy_debug_labels := false
var enemy_vision_debug := false
var navigation_debug := false
var collision_debug := false

var _panel: CanvasLayer
var _debug_enabled := false
var _mouse_mode_before_open: int = Input.MOUSE_MODE_VISIBLE
var _level_return_snapshot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_debug_enabled = OS.is_debug_build()
	if not OS.is_debug_build():
		set_process_input(false)
		set_process(false)
		set_physics_process(false)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(GameConstants.INPUT_DEBUG_PANEL_TOGGLE):
		if not is_gameplay_input_blocked() and not _get_player():
			return
		set_panel_open(not is_gameplay_input_blocked())
		get_viewport().set_input_as_handled()
		return
	var key_event := event as InputEventKey
	if (
		key_event
		and key_event.pressed
		and not key_event.echo
		and key_event.alt_pressed
		and _get_player()
		and _handle_hotkey(key_event.physical_keycode)
	):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if infinite_health:
		_keep_player_alive()
	if no_cooldowns:
		_reset_player_cooldowns()


func _physics_process(_delta: float) -> void:
	if not enemy_ai_frozen:
		return
	for enemy: Node3D in get_enemies():
		_set_enemy_frozen(enemy, true)


func set_panel_open(value: bool) -> void:
	if not _debug_enabled:
		return
	if value and not _get_player():
		return
	if not _ensure_panel():
		return
	if value == is_gameplay_input_blocked():
		return
	if value:
		_mouse_mode_before_open = Input.get_mouse_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_panel.call("set_open", value)
	if not value:
		Input.set_mouse_mode(_mouse_mode_before_open)


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


func add_vabo(amount: int) -> void:
	PlayerData.add_vabo(amount)


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


# ============================================================================
# ЧИТЫ ИГРОКА
# ============================================================================
func set_god_mode(value: bool) -> void:
	god_mode = value
	print("Debug god mode: ", "ON" if value else "OFF")
	state_changed.emit()


func set_infinite_health(value: bool) -> void:
	infinite_health = value
	state_changed.emit()


func set_no_cooldowns(value: bool) -> void:
	no_cooldowns = value
	state_changed.emit()


func toggle_flight() -> bool:
	var player := _get_player()
	if not player:
		return false
	player._toggle_debug_flight()
	state_changed.emit()
	return true


func is_flight_active() -> bool:
	var player := _get_player()
	return player != null and player.debug_flight_active


func get_flight_speed() -> float:
	var player := _get_player()
	return player.debug_flight_speed if player else 30.0


func set_flight_speed(value: float) -> void:
	var player := _get_player()
	if player:
		player.debug_flight_speed = value


func _keep_player_alive() -> void:
	var player := _get_player()
	if not player or not player.health_component:
		return
	if player.health_component.current_health <= 1.0:
		player.health_component.heal(player.health_component.max_health)


func _reset_player_cooldowns() -> void:
	var player := _get_player()
	if not player:
		return
	var roll := player.roll_ability
	if roll:
		roll.roll_interval_timer = 0.0
		if (
			roll.is_roll_recharging
			or roll.current_roll_charges < roll.roll_max_charges
		):
			roll.is_roll_recharging = false
			roll.roll_penalty_timer = 0.0
			roll.current_roll_charges = roll.roll_max_charges
			roll.roll_charges_changed.emit(
				roll.current_roll_charges,
				roll.roll_max_charges,
				false
			)
	if player.air_dash_ability and player.air_dash_ability.cooldown_timer > 0.0:
		player.air_dash_ability.cooldown_timer = 0.0
	if (
		player.ground_slam_ability
		and player.ground_slam_ability.cooldown_timer > 0.0
	):
		player.ground_slam_ability.cooldown_timer = 0.0


# ============================================================================
# ВРЕМЯ
# ============================================================================
func get_time_scale() -> float:
	return GameManager.base_time_scale


func set_time_scale(value: float) -> void:
	GameManager.set_global_time_scale(
		clampf(value, MIN_TIME_SCALE, MAX_TIME_SCALE)
	)
	state_changed.emit()


func cycle_time_scale() -> void:
	var current := get_time_scale()
	var next_index := 0
	for i: int in TIME_SCALE_STEPS.size():
		if is_equal_approx(TIME_SCALE_STEPS[i], current):
			next_index = (i + 1) % TIME_SCALE_STEPS.size()
			break
	set_time_scale(TIME_SCALE_STEPS[next_index])


# ============================================================================
# ВРАГИ
# ============================================================================
func get_enemies() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(
		GameConstants.GROUP_ENEMIES
	):
		if node is Node3D and not _is_enemy_dead(node):
			result.append(node as Node3D)
	return result


func is_enemy_scene_available(kind: StringName) -> bool:
	return ResourceLoader.exists(String(ENEMY_SCENE_PATHS.get(kind, "")))


func spawn_enemies(kind: StringName, count: int, elite: bool = false) -> int:
	var player := _get_player()
	var scene := _load_enemy_scene(kind)
	if not player or not scene:
		return 0
	var forward := _get_spawn_forward(player)
	var right := forward.cross(Vector3.UP).normalized()
	var origin := (
		player.global_position
		+ forward * SPAWN_DISTANCE
		+ Vector3.UP * SPAWN_HEIGHT
	)
	var spawned := 0
	for i: int in count:
		var offset := (float(i) - float(count - 1) * 0.5) * SPAWN_SPACING
		if _spawn_enemy_at(scene, origin + right * offset, elite):
			spawned += 1
	return spawned


# Волна по точкам арены (группа ai_arena_spawn_points); без точек — перед игроком
func spawn_wave(kind: StringName, count: int, elite: bool = false) -> int:
	var points: Array[Node3D] = []
	var current_scene := get_tree().current_scene
	for node: Node in get_tree().get_nodes_in_group(ARENA_SPAWN_GROUP):
		if (
			node is Node3D
			and current_scene
			and current_scene.is_ancestor_of(node)
		):
			points.append(node as Node3D)
	if points.is_empty():
		return spawn_enemies(kind, count, elite)
	var scene := _load_enemy_scene(kind)
	if not scene:
		return 0
	var spawned := 0
	for i: int in count:
		var point := points[i % points.size()]
		var jitter := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		if _spawn_enemy_at(
			scene,
			point.global_position + jitter + Vector3.UP * SPAWN_HEIGHT,
			elite
		):
			spawned += 1
	return spawned


func kill_all_enemies() -> int:
	var killed := 0
	for enemy: Node3D in get_enemies():
		_set_enemy_frozen(enemy, false)
		var health: Node = enemy.get("health_component")
		if health and health.has_method("take_damage"):
			health.call(
				"take_damage",
				float(health.get("current_health")) + 1.0
			)
			killed += 1
	return killed


func set_enemy_ai_frozen(value: bool) -> void:
	enemy_ai_frozen = value
	if not value:
		for enemy: Node3D in get_enemies():
			_set_enemy_frozen(enemy, false)
	print("Debug enemy AI frozen: ", "ON" if value else "OFF")
	state_changed.emit()


func set_enemy_debug_labels(value: bool) -> void:
	enemy_debug_labels = value
	_apply_debug_flags_to_all_enemies()


func set_enemy_vision_debug(value: bool) -> void:
	enemy_vision_debug = value
	_apply_debug_flags_to_all_enemies()


func set_navigation_debug(value: bool) -> void:
	navigation_debug = value
	get_tree().debug_navigation_hint = value
	if NavigationServer3D.has_method("set_debug_enabled"):
		NavigationServer3D.call("set_debug_enabled", value)
	_apply_debug_flags_to_all_enemies()


# Включение работает сразу (перестраиваем debug-меши через changed у шейпов),
# выключение уже созданных мешей — только после перезапуска уровня.
func set_collision_debug(value: bool) -> void:
	collision_debug = value
	get_tree().debug_collisions_hint = value
	var current_scene := get_tree().current_scene
	if value and current_scene:
		for node: Node in current_scene.find_children(
			"*",
			"CollisionShape3D",
			true,
			false
		):
			var shape := (node as CollisionShape3D).shape
			if shape:
				shape.emit_changed()
	state_changed.emit()


func _load_enemy_scene(kind: StringName) -> PackedScene:
	var path := String(ENEMY_SCENE_PATHS.get(kind, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("DebugTools: enemy scene is missing: %s" % path)
		return null
	return load(path) as PackedScene


func _spawn_enemy_at(
	scene: PackedScene,
	spawn_position: Vector3,
	elite: bool
) -> bool:
	var parent := get_tree().current_scene
	var enemy := scene.instantiate() as Node3D
	if not parent or not enemy:
		return false
	if elite and "elite_chance" in enemy:
		enemy.set("elite_chance", 1.0)
	parent.add_child(enemy)
	enemy.global_position = spawn_position
	_apply_enemy_debug_flags(enemy)
	return true


func _get_spawn_forward(player: Player) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var forward := (
		-camera.global_basis.z
		if camera
		else player.global_basis.z
	)
	forward.y = 0.0
	if forward.is_zero_approx():
		return Vector3.FORWARD
	return forward.normalized()


func _is_enemy_dead(enemy: Node) -> bool:
	return enemy.has_method("is_dead") and bool(enemy.call("is_dead"))


# Заморозка ИИ без правок enemy.gd: отключаем стейт-машину и гасим скорость.
# Если у врага появится set_debug_frozen(bool) — используем его.
func _set_enemy_frozen(enemy: Node3D, frozen: bool) -> void:
	if enemy.has_method("set_debug_frozen"):
		enemy.call("set_debug_frozen", frozen)
		return
	var state_machine: Node = enemy.get("state_machine")
	if not state_machine:
		return
	var ai_locked: bool = enemy.get("is_ai_locked") == true
	var run_ai := not frozen and not ai_locked
	state_machine.set_process(run_ai)
	state_machine.set_physics_process(run_ai)
	if frozen and enemy is CharacterBody3D:
		var body := enemy as CharacterBody3D
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		var nav_agent := enemy.get("nav_agent") as NavigationAgent3D
		if nav_agent:
			nav_agent.set_velocity(Vector3.ZERO)


func _apply_debug_flags_to_all_enemies() -> void:
	for enemy: Node3D in get_enemies():
		_apply_enemy_debug_flags(enemy)
	state_changed.emit()


func _apply_enemy_debug_flags(enemy: Node3D) -> void:
	if "show_debug_label" in enemy:
		enemy.set("show_debug_label", enemy_debug_labels)
	var vision: Node = enemy.get("vision_component")
	if vision and "debug_vision" in vision:
		vision.set("debug_vision", enemy_vision_debug)
	var nav_agent := enemy.get("nav_agent") as NavigationAgent3D
	if nav_agent:
		nav_agent.debug_enabled = navigation_debug


func _handle_hotkey(keycode: Key) -> bool:
	match keycode:
		KEY_1:
			set_god_mode(not god_mode)
		KEY_2:
			print("Debug: killed enemies: ", kill_all_enemies())
		KEY_3:
			spawn_enemies(&"standard", 1)
		KEY_4:
			spawn_wave(&"standard", 3)
		KEY_5:
			cycle_time_scale()
		KEY_6:
			set_enemy_ai_frozen(not enemy_ai_frozen)
		_:
			return false
	return true


# ============================================================================
# СОХРАНЕНИЕ / ЧЕКПОИНТЫ / УРОВНИ
# ============================================================================
func save_now() -> Error:
	return SaveManager.save_permanent_event()


func get_level_checkpoints() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var current_scene := get_tree().current_scene
	if not current_scene:
		return result
	for node: Node in get_tree().get_nodes_in_group("memory_nodes"):
		if (
			node is Node3D
			and current_scene.is_ancestor_of(node)
			and node.has_method("get_spawn_transform")
		):
			result.append(node as Node3D)
	return result


func teleport_to_node(node: Node3D) -> bool:
	var player := _get_player()
	if not player or not is_instance_valid(node):
		return false
	player.global_transform = node.call("get_spawn_transform")
	player.velocity = Vector3.ZERO
	return true


# Снимок прогресса в памяти, чтобы арена не испортила Level 01 (сейв не пишем)
func open_ai_test_arena() -> void:
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.scene_file_path == AI_TEST_ARENA_PATH:
		return
	_level_return_snapshot = PlayerData.create_snapshot()
	set_panel_open(false)
	SceneManager.change_scene_with_loading(AI_TEST_ARENA_PATH)


func return_to_level_01() -> void:
	if not _level_return_snapshot.is_empty():
		PlayerData.apply_snapshot(_level_return_snapshot)
		_level_return_snapshot = {}
	set_panel_open(false)
	SceneManager.change_scene_with_loading(SceneManager.LEVEL_1_PATH)


func get_stats_lines() -> PackedStringArray:
	var attackers: Variant = AIDirector.get("current_attackers")
	var attackers_text := (
		str(attackers.size()) if attackers is Array else "-"
	)
	return PackedStringArray([
		tr("debug_stats_perf") % [
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		],
		tr("debug_stats_ai") % [
			get_enemies().size(),
			attackers_text,
			Engine.time_scale,
		],
	])


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
