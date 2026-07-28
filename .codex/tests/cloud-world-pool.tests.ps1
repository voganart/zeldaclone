$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$layoutPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_cell_layout.gd'
$managerPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/CloudManager.gd'

if (-not (Test-Path -LiteralPath $layoutPath)) {
    throw 'Cloud cell layout helper is missing'
}

$layout = Get-Content -Raw $layoutPath
$manager = Get-Content -Raw $managerPath

foreach ($token in @(
    'static func world_to_cell(',
    'static func desired_cells(',
    'static func cell_transform(',
    'horizontal_radius = maxi(horizontal_radius, 1)',
    'vertical_radius = maxi(vertical_radius, 0)',
    'density = clampf(density, 0.0, 1.0)',
    'candidates.resize(limit)'
)) {
    if (-not $layout.Contains($token)) {
        throw "Cloud cell layout contract is missing: $token"
    }
}

foreach ($token in @(
    'const CloudCellLayout = preload(',
    'world_seed',
    'cell_size',
    'horizontal_cell_radius',
    'vertical_cell_radius',
    'cell_density',
    'pool_updates_per_frame',
    '_active_cells',
    '_free_clouds',
    '_requested_cells',
    'CloudCellLayout.world_to_cell(',
    'CloudCellLayout.desired_cells(',
    'CloudCellLayout.cell_transform('
)) {
    if (-not $manager.Contains($token)) {
        throw "Cloud manager pool contract is missing: $token"
    }
}

$runtimeProcessStart = $manager.IndexOf('func _process(')
if ($runtimeProcessStart -lt 0) {
    throw 'Cloud manager runtime process is missing'
}
$runtimeProcessEnd = $manager.IndexOf(
    'func _initialize_runtime_pool',
    $runtimeProcessStart
)
if ($runtimeProcessEnd -lt 0) {
    throw 'Cloud manager pool initialization is missing'
}
$runtimeProcess = $manager.Substring(
    $runtimeProcessStart,
    $runtimeProcessEnd - $runtimeProcessStart
)
if ($runtimeProcess.Contains('rotate_y(')) {
    throw 'Cloud manager still rotates the cloud root at runtime'
}
if ($runtimeProcess.Contains('global_position.x = player_pos.x')) {
    throw 'Cloud manager still follows the player at runtime'
}
