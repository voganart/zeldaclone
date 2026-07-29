$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$mathPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_exclusion_math.gd'
$volumePath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_exclusion_volume.gd'
$scenePath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_exclusion_volume.tscn'
$managerPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/CloudManager.gd'

foreach ($path in @($mathPath, $volumePath, $scenePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Cloud exclusion file is missing: $path"
    }
}

$math = Get-Content -Raw $mathPath
$volume = Get-Content -Raw $volumePath
$scene = Get-Content -Raw $scenePath
$manager = Get-Content -Raw $managerPath

foreach ($token in @(
    'class_name CloudExclusionMath',
    'func intersects_cloud(',
    'shape is BoxShape3D',
    'shape is SphereShape3D',
    'cloud_radius',
    'clearance',
    'affine_inverse()'
)) {
    if (-not $math.Contains($token)) {
        throw "Cloud exclusion math contract is missing: $token"
    }
}
foreach ($token in @(
    'class_name CloudExclusionVolume',
    'extends Area3D',
    'add_to_group(&"cloud_exclusion")',
    'func get_exclusion_shape() -> Shape3D',
    'func get_exclusion_transform() -> Transform3D',
    '@export_range(0.0, 500.0'
)) {
    if (-not $volume.Contains($token)) {
        throw "Cloud exclusion volume contract is missing: $token"
    }
}
foreach ($token in @(
    '[node name="CloudExclusionVolume" type="Area3D"]',
    '[node name="CollisionShape3D" type="CollisionShape3D"'
)) {
    if (-not $scene.Contains($token)) {
        throw "Cloud exclusion scene contract is missing: $token"
    }
}
foreach ($token in @(
    '_exclusion_volumes',
    '_refresh_exclusion_volumes()',
    '_member_is_excluded(',
    'CloudWeatherField.member_data(',
    'cloud_transform.origin += _current_cloud_offset',
    'CloudExclusionMath.intersects_cloud('
)) {
    if (-not $manager.Contains($token)) {
        throw "CloudManager exclusion integration is missing: $token"
    }
}
