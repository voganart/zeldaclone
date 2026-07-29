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

Write-Output 'PASS: F10 debug panel controller is configured'
