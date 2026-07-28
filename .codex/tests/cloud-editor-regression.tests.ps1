$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

$cloudScene = Get-Content -LiteralPath (
    Join-Path $projectRoot 'assets/shaders/Cloud_volumetric/cloud.tscn'
) -Raw
$volumeNodes = [regex]::Matches(
    $cloudScene,
    '(?m)^\[node name="VolumetricMesh[^"]*" type="MeshInstance3D" parent="\."(?: [^\]]+)?\]'
)
if ($volumeNodes.Count -ne 1) {
    throw "cloud.tscn must contain one runtime VolumetricMesh, found $($volumeNodes.Count)"
}
$volumeSection = [regex]::Match(
    $cloudScene,
    '(?ms)^\[node name="VolumetricMesh".*?(?=^\[|\z)'
).Value
if ($volumeSection -match '(?m)^visible = false$') {
    throw 'Standalone cloud scene must keep VolumetricMesh visible for editing'
}
$impostorSection = [regex]::Match(
    $cloudScene,
    '(?ms)^\[node name="ImpostorMesh".*?(?=^\[|\z)'
).Value
if ($impostorSection -notmatch '(?m)^visible = false$') {
    throw 'ImpostorMesh must start hidden until the LOD controller selects it'
}
if ($cloudScene -notmatch 'size = Vector2\(1\.15, 1\.15\)') {
    throw 'Impostor quad must use the single-cloud reference size'
}

$controller = Get-Content -LiteralPath (
    Join-Path $projectRoot 'levels/components/CloudManager/cloud_lod_controller.gd'
) -Raw
foreach ($requiredToken in @(
    '_editor_preview_distance',
    'get_tree().edited_scene_root == self',
    '_set_shape_override',
    'shape_override_enabled',
    'volume_lod_factor',
    'PreviewMode',
    'cheap_volume_start'
)) {
    if (-not $controller.Contains($requiredToken)) {
        throw "Cloud LOD controller is missing editor-safe behavior: $requiredToken"
    }
}

$manager = Get-Content -LiteralPath (
    Join-Path $projectRoot 'levels/components/CloudManager/CloudManager.gd'
) -Raw
foreach ($axis in @('x', 'y', 'z')) {
    if (-not $manager.Contains("randf_range(scale_min.$axis, scale_max.$axis)")) {
        throw "CloudManager must randomize scale.$axis independently"
    }
}
foreach ($requiredToken in @(
    '_configure_existing_cloud_lods',
    'preview_lod_in_editor',
    'call_deferred("_configure_existing_cloud_lods")'
)) {
    if (-not $manager.Contains($requiredToken)) {
        throw "CloudManager is missing Level editor LOD propagation: $requiredToken"
    }
}

$environment = Get-Content -LiteralPath (
    Join-Path $projectRoot 'levels/components/Environment/environment_system.tscn'
) -Raw
if (-not $environment.Contains('scale_min = Vector3(40, 20, 80)')) {
    throw 'Environment cloud minimum scale no longer matches the original look'
}
if (-not $environment.Contains('scale_max = Vector3(100, 80, 150)')) {
    throw 'Environment cloud maximum scale no longer matches the original look'
}

$baker = Get-Content -LiteralPath (
    Join-Path $projectRoot 'addons/cloud_impostor_baker/cloud_impostor_baker.gd'
) -Raw
foreach ($requiredToken in @(
    '&"shape_override_enabled", 1.0',
    '&"shape_override_scale"',
    '&"shape_override_offset"'
)) {
    if (-not $baker.Contains($requiredToken)) {
        throw "Cloud baker is missing representative shape override: $requiredToken"
    }
}
