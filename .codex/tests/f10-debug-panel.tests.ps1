$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Read-ProjectFile([string]$relativePath) {
    Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot $relativePath)
}

$playerData = Read-ProjectFile 'common\autoload\player_data.gd'
$player = Read-ProjectFile 'entities\player\player.gd'
$hud = Read-ProjectFile 'ui\player_hud.gd'
$debugToolsPath = Join-Path $projectRoot 'common\autoload\debug_tools.gd'
if (-not (Test-Path $debugToolsPath)) {
    throw 'DebugTools autoload script is missing'
}
$debugTools = Get-Content -Raw -Encoding UTF8 $debugToolsPath
$inputHandler = Read-ProjectFile 'entities\player\components\input_handler.gd'
$project = Read-ProjectFile 'project.godot'
$panelScenePath = Join-Path $projectRoot 'ui\debug_panel\debug_panel.tscn'
$panelScriptPath = Join-Path $projectRoot 'ui\debug_panel\debug_panel.gd'
if (-not (Test-Path $panelScenePath)) {
    throw 'Compact debug panel scene is missing'
}
if (-not (Test-Path $panelScriptPath)) {
    throw 'Compact debug panel script is missing'
}
$panelScene = Get-Content -Raw -Encoding UTF8 $panelScenePath
$panelScript = Get-Content -Raw -Encoding UTF8 $panelScriptPath
$translations = Read-ProjectFile 'assets\translations\texts.csv'

foreach ($token in @(
    'signal ability_state_changed(',
    'func set_vabo(amount: int) -> bool:',
    'func set_ability_unlocked(',
    'ability_state_changed.emit(ability_name, unlocked)'
)) {
    if (-not $playerData.Contains($token)) {
        throw "PlayerData debug contract is missing: $token"
    }
}

if (-not $player.Contains(
    'func refresh_progression_from_player_data() -> void:'
)) {
    throw 'Player progression refresh API is missing'
}

if (-not $hud.Contains(
    'PlayerData.ability_state_changed.connect(_on_ability_state_changed)'
)) {
    throw 'HUD does not observe ability lock/unlock changes'
}

foreach ($token in @(
    'DebugTools="*res://common/autoload/debug_tools.gd"',
    'debug_panel_toggle={',
    'physical_keycode":4194341'
)) {
    if (-not $project.Contains($token)) {
        throw "Project debug-panel contract is missing: $token"
    }
}

foreach ($token in @(
    'if not OS.is_debug_build():',
    'func is_gameplay_input_blocked() -> bool:',
    'func reset_save_and_reload()',
    'func restore_health() -> bool:',
    'func set_all_abilities(unlocked: bool) -> void:',
    'func teleport_to_checkpoint() -> bool:',
    'func reload_level()'
)) {
    if (-not $debugTools.Contains($token)) {
        throw "DebugTools contract is missing: $token"
    }
}

if (-not $inputHandler.Contains(
    'DebugTools.is_gameplay_input_blocked()'
)) {
    throw 'Player input is not blocked by the debug panel'
}

foreach ($token in @(
    'offset_right = 320.0',
    'name="SaveHeader"',
    'name="SaveContent"',
    'name="PlayerHeader"',
    'name="PlayerContent"',
    'name="ProgressionHeader"',
    'name="ProgressionContent"',
    'name="CheckpointHeader"',
    'name="CheckpointContent"',
    'name="ResetConfirmRow"',
    'name="VaboSpinBox"',
    'name="StatusLabel"'
)) {
    if (-not $panelScene.Contains($token)) {
        throw "Compact debug panel scene is missing: $token"
    }
}

foreach ($token in @(
    'func set_open(value: bool) -> void:',
    'func _set_section_expanded(',
    'DebugTools.reset_save_and_reload()',
    'DebugTools.restore_health()',
    'DebugTools.set_all_abilities(true)',
    'DebugTools.set_all_abilities(false)',
    'DebugTools.teleport_to_checkpoint()',
    'DebugTools.reload_level()'
)) {
    if (-not $panelScript.Contains($token)) {
        throw "Compact debug panel script is missing: $token"
    }
}

foreach ($key in @(
    'debug_panel_title',
    'debug_category_save',
    'debug_category_player',
    'debug_category_progression',
    'debug_category_checkpoint',
    'debug_reset_save',
    'debug_reset_confirm',
    'debug_confirm',
    'debug_cancel',
    'debug_restore_health',
    'debug_reload_level',
    'debug_apply',
    'debug_unlock_all',
    'debug_lock_all',
    'debug_teleport_checkpoint',
    'debug_status_health_restored',
    'debug_status_progression_updated',
    'debug_status_checkpoint_missing',
    'debug_status_player_missing',
    'debug_status_save_reset_failed'
)) {
    if ($translations -notmatch "(?m)^$key,""[^""]+"",""[^""]+""$") {
        throw "Debug panel localization is missing: $key"
    }
}

Write-Output 'PASS: F10 debug panel controller is configured'
