$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$profileScriptPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_tuning_profile.gd'
$profileResourcePath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_tuning_profile.tres'
$managerPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/CloudManager.gd'
$graphicsPath = Join-Path (
    $projectRoot
) 'common/autoload/graphics_manager.gd'

foreach ($path in @($profileScriptPath, $profileResourcePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Cloud tuning profile file is missing: $path"
    }
}

$script = Get-Content -Raw $profileScriptPath
$resource = Get-Content -Raw $profileResourcePath
$manager = Get-Content -Raw $managerPath
$graphics = Get-Content -Raw $graphicsPath

foreach ($token in @(
    'class_name CloudTuningProfile',
    'coverage_radius',
    'coverage_height',
    'target_cloud_count',
    'pool_capacity',
    'cell_size',
    'world_seed',
    'scale_min',
    'scale_max',
    'aspect_variation',
    'large_cloud_chance',
    'large_cloud_multiplier',
    'shape_variation',
    'full_volume_distance',
    'cheap_volume_distance',
    'billboard_transition_start',
    'billboard_transition_end',
    'recycle_fade_duration',
    'updates_per_frame',
    'func sanitize() -> void',
    'func copy_values_from(source: CloudTuningProfile) -> void'
)) {
    if (-not $script.Contains($token)) {
        throw "Cloud tuning profile contract is missing: $token"
    }
}

foreach ($token in @(
    'coverage_radius = 1400.0',
    'target_cloud_count = 80',
    'pool_capacity = 96'
)) {
    if (-not $resource.Contains($token)) {
        throw "Cloud tuning default is missing: $token"
    }
}

foreach ($token in @(
    '@export var tuning_profile: CloudTuningProfile',
    'func apply_tuning_profile(profile: CloudTuningProfile) -> void',
    'tuning_profile.sanitize()'
)) {
    if (-not $manager.Contains($token)) {
        throw "CloudManager profile integration is missing: $token"
    }
}

foreach ($legacyKey in @(
    '"cloud_pool_horizontal_radius"',
    '"cloud_pool_vertical_radius"',
    '"cloud_pool_density"',
    '"cloud_pool_updates_per_frame"'
)) {
    if ($graphics.Contains($legacyKey)) {
        throw "GraphicsManager still overwrites profile value: $legacyKey"
    }
}
