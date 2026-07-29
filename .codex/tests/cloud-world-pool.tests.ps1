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
    'static func candidate_cells(',
    'static func occupancy_threshold(',
    'static func cell_data(',
    'static func candidate_members(',
    'static func member_data(',
    'Array[Vector4i]',
    'Vector4i(',
    'member_index',
    'profile.coverage_radius + profile.prewarm_margin',
    'profile.cluster_spread',
    'profile.cluster_scale_variation',
    '"shape_offset"',
    '"cloud_radius"'
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
    'CloudCellLayout.candidate_members(',
    'CloudCellLayout.member_data(',
    '_requested_cells',
    'set_shape_offset'
)) {
    if (-not $manager.Contains($token)) {
        throw "Cloud manager pool contract is missing: $token"
    }
}
if ($layout.Contains('candidates.resize(limit)')) {
    throw 'Cloud layout still truncates the nearest cells'
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
foreach ($unsafeInference in @(
    'var target_cell := _requested_cells.pop_front()',
    'var released := _released_clouds.pop_back()',
    'var center := cluster_centers.pick_random()'
)) {
    if ($manager.Contains($unsafeInference)) {
        throw "Variant inference warning remains: $unsafeInference"
    }
}

foreach ($shader in @($volumeShader, $impostorShader)) {
    if (-not $shader.Contains('instance uniform float pool_fade')) {
        throw 'Cloud shader is missing per-instance pool fade'
    }
    if (-not $shader.Contains('raw_alpha * pool_fade')) {
        throw 'Cloud shader does not apply pool fade to final opacity'
    }
    if (-not $shader.Contains('instance uniform vec3 shape_offset')) {
        throw 'Cloud shader is missing stable per-instance shape variation'
    }
}
if (-not $controller.Contains('func set_pool_fade(value: float)')) {
    throw 'Cloud LOD controller cannot apply pool fade'
}
foreach ($token in @(
    'func configure_from_profile(profile: CloudTuningProfile)',
    'func set_shape_offset(offset: Vector3)'
)) {
    if (-not $controller.Contains($token)) {
        throw "Cloud LOD profile contract is missing: $token"
    }
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

$fadeMatch = [regex]::Match(
    $manager,
    'recycle_fade_duration:\s*float\s*=\s*([0-9.]+)'
)
if (-not $fadeMatch.Success -or [double]$fadeMatch.Groups[1].Value -lt 0.8) {
    throw 'Cloud recycle fade duration must be at least 0.8 seconds'
}
