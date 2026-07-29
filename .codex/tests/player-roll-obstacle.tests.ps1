$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$player = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'entities\player\player.gd'
)
$rollState = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'entities\player\states\player_roll.gd'
)
$playerScene = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'entities\player\player.tscn'
)

if ($rollState.Contains('player.move_and_slide()')) {
    throw 'Roll state must not move the CharacterBody independently'
}

foreach ($token in @(
    'func set_roll_passage_motion(direction: Vector3, speed: float) -> void',
    'func clear_roll_passage_motion() -> void',
    'func can_restore_collider() -> bool',
    'if roll_passage_motion_active:',
    'velocity.x = roll_passage_velocity.x',
    'velocity.z = roll_passage_velocity.z',
    'var standing_capsule := CapsuleShape3D.new()',
    'standing_capsule.height = default_col_height',
    'standing_capsule.radius = default_capsule_radius'
)) {
    if (-not $player.Contains($token)) {
        throw "Player Roll passage contract is missing: $token"
    }
}

foreach ($token in @(
    '@export var passage_speed: float = 5.0',
    'player.shrink_collider()',
    'player.set_roll_passage_motion(fixed_roll_direction, passage_speed)',
    'player.clear_roll_passage_motion()',
    'player.can_restore_collider()'
)) {
    if (-not $rollState.Contains($token)) {
        throw "Roll state passage contract is missing: $token"
    }
}

$enterStart = $rollState.IndexOf('func enter() -> void:')
$physicsStart = $rollState.IndexOf('func physics_update(delta: float) -> void:')
$shrinkCall = $rollState.IndexOf('player.shrink_collider()', $enterStart)
if (
    ($enterStart -lt 0) -or
    ($physicsStart -le $enterStart) -or
    ($shrinkCall -le $enterStart) -or
    ($shrinkCall -ge $physicsStart)
) {
    throw 'Roll collider must shrink during enter before physics movement'
}

$physicsProcessStart = $player.IndexOf('func _physics_process(delta: float) -> void:')
$passageOverride = $player.IndexOf(
    'if roll_passage_motion_active:',
    $physicsProcessStart
)
$mainMove = $player.IndexOf('move_and_slide()', $passageOverride)
if (
    ($physicsProcessStart -lt 0) -or
    ($passageOverride -le $physicsProcessStart) -or
    ($mainMove -le $passageOverride)
) {
    throw 'Roll passage velocity must be applied before the main physics move'
}

if (-not $playerScene.Contains('collision_mask = 256')) {
    throw 'Roll standing-clearance cast must detect Obstacles layer 9'
}
if ($playerScene.Contains('dive_entry_margin =')) {
    throw 'Obsolete virtual-wall scene override is still configured'
}
if ($rollState.Contains('HeadWallDetector')) {
    throw 'Obsolete virtual wall still competes with Roll obstacle physics'
}

Write-Output (
    'PASS: Roll obstacle passage uses one physics move and safe clearance'
)
