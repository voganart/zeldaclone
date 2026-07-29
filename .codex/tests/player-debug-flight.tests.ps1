$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$project = Get-Content -Raw (Join-Path $projectRoot 'project.godot')
$constants = Get-Content -Raw (
    Join-Path $projectRoot 'common\autoload\game_constants.gd'
)
$player = Get-Content -Raw (
    Join-Path $projectRoot 'entities\player\player.gd'
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
    'debug_flight_speed_step',
    'debug_flight_active',
    'func _toggle_debug_flight()',
    'func _adjust_debug_flight_speed(direction: float)',
    'func _debug_flight_physics(delta: float)',
    'GameConstants.INPUT_DEBUG_FLIGHT_TOGGLE',
    'Input.is_action_pressed(GameConstants.INPUT_JUMP)',
    'Input.is_action_pressed(GameConstants.INPUT_CROUCH)',
    'Input.is_action_pressed(GameConstants.INPUT_RUN)',
    'collision_shape.set_deferred("disabled"',
    'global_position += direction * speed * delta',
    'event is InputEventMouseButton',
    'event.button_index == MOUSE_BUTTON_WHEEL_UP',
    'event.button_index == MOUSE_BUTTON_WHEEL_DOWN',
    'get_viewport().set_input_as_handled()'
)) {
    if (-not $player.Contains($token)) {
        throw "Player debug flight contract is missing: $token"
    }
}

$inputStart = $player.IndexOf('func _unhandled_input(event: InputEvent)')
$wheelGuard = $player.IndexOf('debug_flight_active', $inputStart)
$wheelType = $player.IndexOf('event is InputEventMouseButton', $wheelGuard)
$toggleInput = $player.IndexOf(
    'event.is_action_pressed(GameConstants.INPUT_DEBUG_FLIGHT_TOGGLE)',
    $wheelGuard
)
if (
    ($inputStart -lt 0) -or
    ($wheelGuard -lt $inputStart) -or
    ($wheelType -lt $wheelGuard) -or
    ($toggleInput -lt $wheelType)
) {
    throw 'Mouse wheel speed handling is not guarded by active flight'
}

$clampPattern = '(?s)clampf\(\s*debug_flight_speed\s*\+\s*direction\s*\*\s*' +
    'debug_flight_speed_step,\s*5\.0,\s*200\.0\s*\)'
if (-not [Regex]::IsMatch($player, $clampPattern)) {
    throw 'Flight wheel speed is not clamped to 5..200'
}

Write-Output 'PASS: debug flight controls and wheel speed are configured'
