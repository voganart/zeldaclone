$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$panelScriptPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_tuning_panel.gd'
$panelScenePath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_tuning_panel.tscn'
$managerPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/CloudManager.gd'

foreach ($path in @($panelScriptPath, $panelScenePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Cloud tuning panel file is missing: $path"
    }
}

$panel = Get-Content -Raw $panelScriptPath
$scene = Get-Content -Raw $panelScenePath
$manager = Get-Content -Raw $managerPath
$project = Get-Content -Raw (Join-Path $projectRoot 'project.godot')
$constants = Get-Content -Raw (
    Join-Path $projectRoot 'common/autoload/game_constants.gd'
)
$controller = Get-Content -Raw (
    Join-Path $projectRoot 'levels/components/CloudManager/cloud_lod_controller.gd'
)
$camera = Get-Content -Raw (
    Join-Path $projectRoot 'common/components/camera_input.gd'
)

if (-not $project.Contains('cloud_tuning_toggle={')) {
    throw 'cloud_tuning_toggle input action is missing'
}
$actionStart = $project.IndexOf('cloud_tuning_toggle={')
$actionBlock = $project.Substring(
    $actionStart,
    [Math]::Min(700, $project.Length - $actionStart)
)
if (-not $actionBlock.Contains('physical_keycode":4194341')) {
    throw 'F10 is not assigned to cloud_tuning_toggle'
}
if (-not $constants.Contains(
    'const INPUT_CLOUD_TUNING_TOGGLE = "cloud_tuning_toggle"'
)) {
    throw 'Cloud tuning input constant is missing'
}

foreach ($token in @(
    'class_name CloudTuningPanel',
    'get_property_list()',
    'PROPERTY_USAGE_CATEGORY',
    'TYPE_VECTOR3',
    '"apply_tuning_profile"',
    '"save_tuning_profile"',
    '"reload_tuning_profile"',
    '"regenerate_from_profile"',
    'Input.get_mouse_mode()',
    'Input.set_mouse_mode(',
    'add_to_group(&"cloud_tuning_panel")',
    'func is_open() -> bool',
    'allowed_categories.has(',
    'PROPERTY_HINT_RANGE'
    'Weather'
    '/root/WeatherManager'
    'WeatherProfile'
    '_add_resource_fields('
    'apply_callback: Callable'
    '"apply_profile"'
    '"save_weather_profile"'
    '"reload_weather_profile"'
)) {
    if (-not $panel.Contains($token)) {
        throw "Cloud tuning panel contract is missing: $token"
    }
}
foreach ($token in @(
    'get_nodes_in_group(&"cloud_tuning_panel")',
    'panel.call("is_open")'
)) {
    if (-not $camera.Contains($token)) {
        throw "Camera tuning-panel guard is missing: $token"
    }
}
if (-not $scene.Contains('offset_right = 640.0')) {
    throw 'Cloud tuning panel is wider than the compact design'
}
foreach ($token in @(
    'Distribution',
    'Size & Shape',
    'LOD & Recycling',
    'Regenerate',
    'Save Project',
    'Reload Saved',
    'Reset'
)) {
    if (-not ($scene.Contains($token) -or $panel.Contains($token))) {
        throw "Cloud tuning UI text is missing: $token"
    }
}
foreach ($token in @(
    'func get_cloud_stats() -> Dictionary',
    'func regenerate_from_profile() -> void',
    'func save_tuning_profile() -> Error',
    'func reload_tuning_profile() -> Error',
    'func save_weather_profile() -> Error',
    'func reload_weather_profile() -> Error',
    'OS.is_debug_build()'
)) {
    if (-not $manager.Contains($token)) {
        throw "CloudManager tuning API is missing: $token"
    }
}
if (-not $controller.Contains('func get_lod_mode() -> StringName')) {
    throw 'Cloud LOD controller does not expose runtime mode'
}
