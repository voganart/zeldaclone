$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$layoutPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_cluster_layout.gd'
$profilePath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_tuning_profile.gd'
$resourcePath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_tuning_profile.tres'

if (-not (Test-Path -LiteralPath $layoutPath)) {
    throw 'Shared CloudClusterLayout helper is missing'
}

$layout = Get-Content -Raw $layoutPath
$profile = Get-Content -Raw $profilePath
$resource = Get-Content -Raw $resourcePath

foreach ($token in @(
    'class_name CloudClusterLayout',
    'static func world_to_sector(',
    'static func candidate_sectors(',
    'static func candidate_members(',
    'margin: float = 0.0',
    'static func member_data(',
    'static func preview_members(',
    'static func preview_shape_offset(',
    'Array[Vector4i]',
    '"transform"',
    '"shape_offset"',
    '"cloud_radius"',
    'sector.x',
    'sector.y',
    'sector.z',
    'member_index',
    'world_seed',
    'salt'
)) {
    if (-not $layout.Contains($token)) {
        throw "CloudClusterLayout contract is missing: $token"
    }
}

foreach ($token in @(
    'retention_margin',
    'retention_margin = maxf(retention_margin, prewarm_margin)'
)) {
    if (-not $profile.Contains($token)) {
        throw "Retention profile contract is missing: $token"
    }
}

foreach ($token in @(
    'coverage_radius = 1200.0',
    'coverage_height = 1200.0',
    'target_cloud_count = 80',
    'pool_capacity = 120',
    'cell_size = 300.0',
    'scale_min = Vector3(40, 20, 80)',
    'scale_max = Vector3(100, 80, 150)',
    'cluster_min_members = 1',
    'cluster_max_members = 3',
    'cluster_spread = 70.0',
    'prewarm_margin = 500.0',
    'retention_margin = 800.0'
)) {
    if (-not $resource.Contains($token)) {
        throw "Project cloud profile value is missing: $token"
    }
}

Write-Output 'Cloud cluster layout contract checks passed.'
