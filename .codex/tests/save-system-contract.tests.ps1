$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$playerData = Get-Content -Raw (
    Join-Path $projectRoot 'common\autoload\player_data.gd'
)
$saveManager = Get-Content -Raw (
    Join-Path $projectRoot 'common\autoload\save_manager.gd'
)
$project = Get-Content -Raw (Join-Path $projectRoot 'project.godot')
$persistentState = Get-Content -Raw (
    Join-Path $projectRoot 'common\persistence\persistent_state.gd'
)
$player = Get-Content -Raw (
    Join-Path $projectRoot 'entities\player\player.gd'
)
$chest = Get-Content -Raw (
    Join-Path $projectRoot 'entities\interactive\Chest_1\chest.gd'
)
$memoryNode = Get-Content -Raw (
    Join-Path $projectRoot 'entities\interactive\MemoryNode\memory_node.gd'
)
$translations = Get-Content -Raw (
    Join-Path $projectRoot 'assets\translations\texts.csv'
)
$levelScript = Get-Content -Raw (
    Join-Path $projectRoot 'levels\level_01.gd'
)
$levelScene = Get-Content -Raw (
    Join-Path $projectRoot 'levels\Level_01.tscn'
)
$sceneManager = Get-Content -Raw (
    Join-Path $projectRoot 'common\autoload\scene_manager.gd'
)
$mainMenu = Get-Content -Raw (
    Join-Path $projectRoot 'ui\menus\main_menu.gd'
)

foreach ($token in @(
    'const DEFAULT_ABILITIES',
    '"roll_ability": false',
    '"double_jump": false',
    '"ground_slam": false',
    '"air_dash": false',
    '"3_hit_combo": false',
    'func reset_progress()',
    'func create_snapshot()',
    'func apply_snapshot(snapshot: Dictionary)',
    'func unlock_ability(ability_name: StringName) -> bool',
    'func complete_persistent_id(id: StringName) -> bool',
    'maxi(int(snapshot.get("current_vabo", 0)), 0)',
    'maxf('
)) {
    if (-not $playerData.Contains($token)) {
        throw "PlayerData save contract is missing: $token"
    }
}

foreach ($token in @(
    'const SAVE_VERSION := 1',
    'const DEFAULT_SAVE_PATH := "user://savegame.json"',
    'func save_checkpoint(level_path: String, checkpoint_id: StringName)',
    'func save_permanent_event()',
    'func complete_persistent_id(id: StringName)',
    'func load_save() -> bool',
    'func clear_save() -> Error',
    '"version": SAVE_VERSION',
    '"player_data": data.create_snapshot()',
    'invalid_save_recovered = true'
)) {
    if (-not $saveManager.Contains($token)) {
        throw "SaveManager contract is missing: $token"
    }
}

if (-not $project.Contains(
    'SaveManager="*res://common/autoload/save_manager.gd"'
)) {
    throw 'SaveManager is not registered as an autoload'
}

foreach ($token in @(
    'PlayerData.is_ability_unlocked(&"double_jump")',
    'PlayerData.unlock_ability(StringName(normalized_name))',
    'SaveManager.save_permanent_event()'
)) {
    if (-not $player.Contains($token)) {
        throw "Player progression integration is missing: $token"
    }
}

foreach ($token in @(
    'class_name PersistentState',
    'func is_completed() -> bool',
    'func mark_completed() -> bool',
    'SaveManager.complete_persistent_id(persistent_id)'
)) {
    if (-not $persistentState.Contains($token)) {
        throw "Persistent state contract is missing: $token"
    }
}

foreach ($token in @(
    '@export var persistent_id: StringName',
    'persistent_state.persistent_id = persistent_id',
    'persistent_state.mark_completed()',
    'func _apply_persistent_open_state()'
)) {
    if (-not $chest.Contains($token)) {
        throw "Persistent chest integration is missing: $token"
    }
}

foreach ($token in @(
    'class_name MemoryNode',
    '@export var checkpoint_id: StringName',
    'func activate(player: Node)',
    'SaveManager.save_checkpoint(',
    'health_component.heal(health_component.max_health)',
    'GameEvents.save_feedback_requested.emit(&"save_memory_anchored")',
    'func get_spawn_transform() -> Transform3D'
)) {
    if (-not $memoryNode.Contains($token)) {
        throw "Memory Node contract is missing: $token"
    }
}

foreach ($row in @(
    'ui_continue,"Continue"',
    'save_memory_anchored,"Memory anchored"',
    'save_data_invalid,"Save data was reset"'
)) {
    if (-not $translations.Contains($row)) {
        throw "Save localization is missing: $row"
    }
}

foreach ($token in @(
    'func resolve_player_spawn_transform() -> Transform3D',
    'get_tree().get_nodes_in_group("memory_nodes")',
    'PlayerData.active_checkpoint_id',
    'new_player.global_transform = resolve_player_spawn_transform()'
)) {
    if (-not $levelScript.Contains($token)) {
        throw "Checkpoint spawn integration is missing: $token"
    }
}

foreach ($token in @(
    'checkpoint_id = &"level_01_after_crates"',
    'persistent_id = &"level_01_air_dash_chest"',
    'persistent_id = &"level_01_ground_slam_chest"',
    'persistent_id = &"level_01_roll_chest"'
)) {
    if (-not $levelScene.Contains($token)) {
        throw "Level_01 save integration is missing: $token"
    }
}

foreach ($token in @(
    'const LEVEL_1_PATH = "res://levels/Level_01.tscn"',
    'func continue_or_start_game()',
    'SaveManager.start_new_game()',
    'var restart_path := PlayerData.current_level_path'
)) {
    if (-not $sceneManager.Contains($token)) {
        throw "Scene save flow is missing: $token"
    }
}

foreach ($token in @(
    'btn_new_game.text = tr("ui_continue" if can_continue else "ui_new_game")',
    'SceneManager.continue_or_start_game()',
    'SaveManager.invalid_save_recovered'
)) {
    if (-not $mainMenu.Contains($token)) {
        throw "Main menu save flow is missing: $token"
    }
}

Write-Output 'PASS: PlayerData save contract is configured'
