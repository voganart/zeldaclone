$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$layoutPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_cell_layout.gd'
$managerPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/CloudManager.gd'
$controllerPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_lod_controller.gd'
$volumeShaderPath = Join-Path (
    $projectRoot
) 'assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader'
$impostorShaderPath = Join-Path (
    $projectRoot
) 'assets/shaders/Cloud_impostor/cloud_impostor.gdshader'
$graphicsPath = Join-Path (
    $projectRoot
) 'common/autoload/graphics_manager.gd'

if (-not (Test-Path -LiteralPath $layoutPath)) {
    throw 'Cloud cell layout helper is missing'
}

$layout = Get-Content -Raw $layoutPath
$manager = Get-Content -Raw $managerPath
$controller = Get-Content -Raw $controllerPath
$volumeShader = Get-Content -Raw $volumeShaderPath
$impostorShader = Get-Content -Raw $impostorShaderPath
$graphics = Get-Content -Raw $graphicsPath

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

foreach ($shader in @($volumeShader, $impostorShader)) {
    if (-not $shader.Contains('instance uniform float pool_fade')) {
        throw 'Cloud shader is missing per-instance pool fade'
    }
    if (-not $shader.Contains('physical_alpha *= pool_fade')) {
        throw 'Cloud shader does not apply pool fade to final opacity'
    }
}
if (-not $controller.Contains('func set_pool_fade(value: float)')) {
    throw 'Cloud LOD controller cannot apply pool fade'
}
foreach ($token in @(
    'enum RecyclePhase',
    'recycle_fade_duration',
    'RecyclePhase.FADING_OUT',
    'RecyclePhase.FADING_IN',
    'set_pool_fade'
)) {
    if (-not $manager.Contains($token)) {
        throw "Cloud recycling fade contract is missing: $token"
    }
}

foreach ($token in @(
    '"cloud_pool_horizontal_radius"',
    '"cloud_pool_vertical_radius"',
    '"cloud_pool_density"',
    '"cloud_pool_updates_per_frame"'
)) {
    $matches = [regex]::Matches($graphics, [regex]::Escape($token)).Count
    if ($matches -ne 3) {
        throw "Cloud pool quality setting must exist in 3 presets: $token"
    }
}
