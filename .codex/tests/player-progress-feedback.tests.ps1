$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hudScript = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'ui\player_hud.gd'
)
$hudScene = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'ui\player_hud.tscn'
)
$translations = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'assets\translations\texts.csv'
)
$roadmap = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot '.codex\ROADMAP.md'
)
$handoff = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot '.codex\HANDOFF.md'
)

foreach ($relativePath in @(
    'assets\textures\ui\DoubleJump.png',
    'assets\textures\ui\AirDash.png',
    'assets\textures\ui\Combo3Hit.png'
)) {
    if (-not (Test-Path (Join-Path $projectRoot $relativePath))) {
        throw "Missing progress icon: $relativePath"
    }
}

foreach ($token in @(
    '@onready var vabo_value: Label',
    '@onready var roll_container: HBoxContainer',
    '@onready var double_jump_icon: TextureRect',
    '@onready var air_dash_icon: TextureRect',
    '@onready var combo_icon: TextureRect',
    'func _connect_progress_signals() -> void',
    'PlayerData.vabo_changed.connect(_on_vabo_changed)',
    'PlayerData.ability_unlocked.connect(_on_ability_unlocked)',
    'func _sync_progress_feedback() -> void',
    'func _on_vabo_changed(new_amount: int) -> void',
    'func _on_ability_unlocked(_ability_name: StringName) -> void',
    'PlayerData.is_ability_unlocked(ability_name)',
    'if indicator is TextureRect and indicator.texture == null'
)) {
    if (-not $hudScript.Contains($token)) {
        throw "Player HUD progress contract is missing: $token"
    }
}

foreach ($token in @(
    'path="res://assets/textures/ui/DoubleJump.png"',
    'path="res://assets/textures/ui/AirDash.png"',
    'path="res://assets/textures/ui/Combo3Hit.png"',
    '[node name="HealthRow" type="HBoxContainer" parent="HealthContainer"]',
    '[node name="VaboContainer" type="HBoxContainer" parent="HealthContainer/HealthRow"]',
    '[node name="VaboValue" type="Label" parent="HealthContainer/HealthRow/VaboContainer"]',
    '[node name="AbilityStrip" type="HBoxContainer" parent="ActionsContainer"]',
    '[node name="DoubleJumpIcon" type="TextureRect" parent="ActionsContainer/AbilityStrip"]',
    '[node name="AirDashIcon" type="TextureRect" parent="ActionsContainer/AbilityStrip"]',
    '[node name="ComboIcon" type="TextureRect" parent="ActionsContainer/AbilityStrip"]',
    'text = "ui_vabo"'
)) {
    if (-not $hudScene.Contains($token)) {
        throw "Player HUD scene contract is missing: $token"
    }
}

$russianVabo = -join @(
    [char]0x0412,
    [char]0x0430,
    [char]0x0431,
    [char]0x043E
)
$vaboTranslationRow = 'ui_vabo,"Vabo","' + $russianVabo + '"'
if (-not $translations.Contains($vaboTranslationRow)) {
    throw 'Vabo localization is missing English and Russian values'
}

$completedIndex = $roadmap.IndexOf('## Completed')
$progressIndex = $roadmap.IndexOf('### Player Progress Feedback')
$nextIndex = $roadmap.IndexOf('## Next')
if (
    $completedIndex -lt 0 -or
    $progressIndex -le $completedIndex -or
    $nextIndex -le $progressIndex
) {
    throw 'Roadmap does not record Player Progress Feedback as completed'
}
if (-not $handoff.Contains('### Player Progress Feedback')) {
    throw 'Handoff does not record Player Progress Feedback'
}

Write-Output 'PASS: player progress feedback is configured'
