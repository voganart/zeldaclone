$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$project = Get-Content -Raw (Join-Path $projectRoot 'project.godot')
$constants = Get-Content -Raw (
    Join-Path $projectRoot 'common/autoload/game_constants.gd'
)
$player = Get-Content -Raw (
    Join-Path $projectRoot 'entities/player/player.gd'
)

$f4Keycode = 'physical_keycode":4194335'
$f7Keycode = 'physical_keycode":4194338'

$cameraStart = $project.IndexOf('toggle_camera={')
$flightStart = $project.IndexOf('debug_flight_toggle={')
if ($cameraStart -lt 0) {
    throw 'Existing toggle_camera action is missing'
}
if ($flightStart -lt 0) {
    throw 'debug_flight_toggle action is missing'
}

$cameraBlock = $project.Substring(
    $cameraStart,
    [Math]::Min(900, $project.Length - $cameraStart)
)
$flightBlock = $project.Substring(
    $flightStart,
    [Math]::Min(700, $project.Length - $flightStart)
)
if (-not $cameraBlock.Contains($f4Keycode)) {
    throw 'F4 is no longer assigned to toggle_camera'
}
if (-not $flightBlock.Contains($f7Keycode)) {
    throw 'F7 is not assigned to debug_flight_toggle'
}
if (-not $constants.Contains(
    'const INPUT_DEBUG_FLIGHT_TOGGLE = "debug_flight_toggle"'
)) {
    throw 'Debug flight input constant is missing'
}

foreach ($token in @(
    'debug_flight_available',
    'debug_flight_speed',
    'debug_flight_boost',
    'func _toggle_debug_flight()',
    'func _debug_flight_physics(delta: float)',
    'GameConstants.INPUT_DEBUG_FLIGHT_TOGGLE',
    'Input.is_action_pressed(GameConstants.INPUT_JUMP)',
    'Input.is_action_pressed(GameConstants.INPUT_CROUCH)',
    'Input.is_action_pressed(GameConstants.INPUT_RUN)',
    'collision_shape.set_deferred("disabled"',
    'global_position += direction * speed * delta'
)) {
    if (-not $player.Contains($token)) {
        throw "Player debug flight contract is missing: $token"
    }
}
