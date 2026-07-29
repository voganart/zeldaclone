extends SceneTree

var failures: Array[String] = []
var player_data: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append(
			"%s: expected %s, got %s" % [message, str(expected), str(actual)]
		)


func _run() -> void:
	player_data = load("res://common/autoload/player_data.gd").new()
	root.add_child(player_data)

	player_data.reset_progress()
	player_data.apply_snapshot({
		"current_vabo": 27,
		"max_health": 5.0,
		"abilities": {
			"roll_ability": true,
			"double_jump": true,
			"ground_slam": false,
			"air_dash": false,
			"3_hit_combo": false,
		},
		"completed_persistent_ids": ["level_01_gate"],
		"current_level_path": "res://levels/Level_01.tscn",
		"active_checkpoint_id": "level_01_after_crates",
	})
	_expect_equal(player_data.current_vabo, 27, "Vabo restores")
	_expect_equal(player_data.max_health, 5.0, "max health restores")
	_expect_equal(
		player_data.is_ability_unlocked("double_jump"),
		true,
		"ability restores"
	)
	_expect_equal(
		player_data.is_persistent_id_complete("level_01_gate"),
		true,
		"persistent ID restores"
	)

	player_data.apply_snapshot({
		"current_vabo": -10,
		"max_health": 0.0,
		"abilities": {"unknown_ability": true},
	})
	_expect_equal(player_data.current_vabo, 0, "negative Vabo clamps")
	_expect_equal(player_data.max_health, 1.0, "health minimum clamps")
	_expect_equal(
		player_data.is_ability_unlocked("unknown_ability"),
		false,
		"unknown abilities are ignored"
	)

	player_data.reset_progress()
	_expect_equal(player_data.current_vabo, 0, "reset clears Vabo")
	_expect_equal(player_data.max_health, 3.0, "reset restores default health")
	_expect_equal(
		player_data.completed_persistent_ids,
		[],
		"reset clears persistent IDs"
	)
	_test_save_manager()
	_test_resources_load()

	if failures.is_empty():
		print("PASS: PlayerData runtime progression")
		player_data.free()
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	player_data.free()
	quit(1)


func _test_save_manager() -> void:
	var manager: Node = load("res://common/autoload/save_manager.gd").new()
	manager.save_path = "user://codex_save_system_test.json"
	manager.set_player_data_source(player_data)
	root.add_child(manager)
	manager.clear_save()

	player_data.reset_progress()
	player_data.add_vabo(42)
	player_data.max_health = 6.0
	player_data.unlock_ability("roll_ability")
	_expect_equal(
		manager.save_checkpoint(
			"res://levels/Level_01.tscn",
			"level_01_after_crates"
		),
		OK,
		"checkpoint writes"
	)
	player_data.reset_progress()
	_expect_equal(manager.load_save(), true, "valid save loads")
	_expect_equal(player_data.current_vabo, 42, "disk Vabo round-trip")
	_expect_equal(
		player_data.active_checkpoint_id,
		"level_01_after_crates",
		"checkpoint round-trip"
	)

	var file := FileAccess.open(manager.save_path, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	_expect_equal(manager.load_save(), false, "invalid JSON rejected")
	_expect_equal(manager.has_save(), false, "invalid save removed")
	_expect_equal(
		manager.invalid_save_recovered,
		true,
		"recovery status retained for UI"
	)
	manager.clear_save()
	manager.free()


func _test_resources_load() -> void:
	var memory_scene: PackedScene = load(
		"res://entities/interactive/MemoryNode/MemoryNode.tscn"
	)
	_expect_equal(
		memory_scene != null,
		true,
		"Memory Node scene loads"
	)
	if memory_scene:
		var memory_node := memory_scene.instantiate()
		root.add_child(memory_node)
		_expect_equal(
			memory_node.get_spawn_transform() is Transform3D,
			true,
			"Memory Node instance exposes spawn transform"
		)
		memory_node.free()
	_expect_equal(
		load("res://levels/Level_01.tscn") != null,
		true,
		"Level_01 scene loads with save integration"
	)
