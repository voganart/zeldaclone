$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$shaderPaths = @(
    'assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader',
    'assets/shaders/Cloud_impostor/cloud_impostor.gdshader'
)

foreach ($relativePath in $shaderPaths) {
    $absolutePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath)) {
        throw "Cloud LOD shader is missing: $relativePath"
    }
    $source = Get-Content -LiteralPath $absolutePath -Raw
    foreach ($requiredToken in @(
        'instance uniform float lod_fade',
        'instance uniform bool lod_is_impostor',
        'lod_bayer4x4',
        'lod_threshold'
    )) {
        if (-not $source.Contains($requiredToken)) {
            throw "$relativePath is missing complementary dither token: $requiredToken"
        }
    }
}

$impostorSource = Get-Content -LiteralPath (
    Join-Path $projectRoot 'assets/shaders/Cloud_impostor/cloud_impostor.gdshader'
) -Raw
foreach ($requiredToken in @(
    'uniform sampler3D noise_texture',
    'uniform int billboard_steps',
    'ray_box_intersection',
    'get_density',
    'color_light',
    'color_shadow'
)) {
    if (-not $impostorSource.Contains($requiredToken)) {
        throw "Cloud billboard shader is missing procedural token: $requiredToken"
    }
}
foreach ($forbiddenToken in @('albedo_atlas', 'atlas_frames', 'sample_atlas_frame')) {
    if ($impostorSource.Contains($forbiddenToken)) {
        throw "Runtime cloud billboard still depends on baked atlas token: $forbiddenToken"
    }
}

$volumeSource = Get-Content -LiteralPath (
    Join-Path $projectRoot 'assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader'
) -Raw
foreach ($requiredToken in @(
    'shape_override_enabled',
    'shape_override_scale',
    'shape_override_offset',
    'instance uniform float volume_lod_factor',
    'uniform int cheap_steps',
    'active_steps'
)) {
    if (-not $volumeSource.Contains($requiredToken)) {
        throw "Cloud volume shader is missing preview/bake override token: $requiredToken"
    }
}
