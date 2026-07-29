$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Read-ProjectFile([string]$relativePath) {
    Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot $relativePath)
}

$playerData = Read-ProjectFile 'common\autoload\player_data.gd'
$player = Read-ProjectFile 'entities\player\player.gd'
$hud = Read-ProjectFile 'ui\player_hud.gd'

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

Write-Output 'PASS: F10 debug panel progression API is configured'
