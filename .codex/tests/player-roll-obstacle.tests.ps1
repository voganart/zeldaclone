$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Assert-Contains {
    param(
        [string]$Content,
        [string]$Token,
        [string]$Message
    )

    if (-not $Content.Contains($Token)) {
        throw "$Message Missing: $Token"
    }
}

function Assert-NotContains {
    param(
        [string]$Content,
        [string]$Token,
        [string]$Message
    )

    if ($Content.Contains($Token)) {
        throw "$Message Unexpected: $Token"
    }
}

$lowPassagePath = Join-Path (
    $projectRoot
) 'entities\player\states\player_low_passage.gd'
if (-not (Test-Path $lowPassagePath)) {
    throw 'PlayerLowPassage state script must exist'
}

$player = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'entities\player\player.gd'
)
$rollState = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'entities\player\states\player_roll.gd'
)
$lowPassage = Get-Content -Raw -Encoding UTF8 $lowPassagePath
$playerScene = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'entities\player\player.tscn'
)
$constants = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'common\autoload\game_constants.gd'
)
$animationController = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'common\components\animation_controller.gd'
)

Assert-Contains `
    $constants `
    'const STATE_LOW_PASSAGE = "lowpassage"' `
    'LowPassage state constant is not registered.'
Assert-Contains `
    $rollState `
    'GameConstants.STATE_LOW_PASSAGE' `
    'Roll must route blocked standing clearance to LowPassage.'
Assert-Contains `
    $playerScene `
    '[node name="LowPassage" type="Node" parent="StateMachine"' `
    'Player scene must register the LowPassage state.'
Assert-Contains `
    $playerScene `
    'nodes/CrouchSpeed/node = SubResource(' `
    'Crouched Roll animation must have an isolated time-scale node.'
Assert-Contains `
    $animationController `
    'anim_tree.set(P_CROUCH_SPEED, maxf(speed, 0.0))' `
    'LowPassage animation speed must be controlled through AnimationTree.'

foreach ($token in @(
    'player.get_movement_vector()',
    'player.apply_movement_velocity(delta, input_vec, movement_speed)',
    'player.can_restore_collider()',
    'player.restore_collider()',
    'GameConstants.STATE_MOVE',
    'player.is_invincible = false',
    'player.anim_controller.set_crouch_state(true)'
)) {
    Assert-Contains `
        $lowPassage `
        $token `
        'PlayerLowPassage behavior contract is incomplete.'
}

foreach ($token in @(
    'check_jump(',
    'check_attack(',
    'STATE_ROLL',
    'player.is_invincible = true'
)) {
    Assert-NotContains `
        $lowPassage `
        $token `
        'PlayerLowPassage must block combat actions and Roll invulnerability.'
}

foreach ($token in @(
    'roll_passage_motion_active',
    'roll_passage_velocity',
    'func set_roll_passage_motion(',
    'func clear_roll_passage_motion('
)) {
    Assert-NotContains `
        $player `
        $token `
        'Forced Roll passage movement must be removed from Player.'
}

foreach ($token in @(
    'passage_speed',
    'fixed_roll_direction',
    'set_roll_passage_motion(',
    'clear_roll_passage_motion('
)) {
    Assert-NotContains `
        $rollState `
        $token `
        'Roll must not force the player through a low passage.'
}

if ($rollState.Contains('player.move_and_slide()')) {
    throw 'Roll state must not move the CharacterBody independently'
}
if ($lowPassage.Contains('player.move_and_slide()')) {
    throw 'LowPassage must use the shared player physics move'
}
if (-not $playerScene.Contains('collision_mask = 256')) {
    throw 'Roll standing-clearance cast must detect Obstacles layer 9'
}

Write-Output (
    'PASS: Roll hands blocked stand-up to controllable low-passage movement'
)
