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
        'instance uniform float lobe_spread',
        'instance uniform float lobe_variation',
        'float multi_lobe_mask(vec3 p, vec3 seed)',
        'multi_lobe_mask(p, shape_offset)',
        'vec3 reference_lighting(float local_height)',
        'float raw_alpha = 1.0 - transmittance',
        'raw_alpha * pool_fade',
        'lod_bayer4x4',
        'lod_threshold'
    )) {
        if (-not $source.Contains($requiredToken)) {
            throw "$relativePath is missing complementary dither token: $requiredToken"
        }
    }
}

foreach ($relativePath in $shaderPaths) {
    $source = Get-Content -LiteralPath (
        Join-Path $projectRoot $relativePath
    ) -Raw
    if ($source.Contains('physical_alpha *= pool_fade')) {
        throw "$relativePath normalizes RGB with faded alpha and can flash"
    }
}

$controllerSource = Get-Content -LiteralPath (
    Join-Path $projectRoot 'levels/components/CloudManager/cloud_lod_controller.gd'
) -Raw
foreach ($requiredToken in @(
    'func set_lobe_shape(spread: float, variation: float) -> void',
    '&"lobe_spread"',
    '&"lobe_variation"',
    'profile.lobe_spread',
    'profile.lobe_variation'
)) {
    if (-not $controllerSource.Contains($requiredToken)) {
        throw "Cloud LOD controller is missing lobe shape token: $requiredToken"
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
    'color_shadow',
    'shape_override_enabled',
    'shape_override_scale',
    'shape_override_offset'
    'reference_lighting(plane_position.y)'
)) {
    if (-not $impostorSource.Contains($requiredToken)) {
        throw "Cloud billboard shader is missing procedural token: $requiredToken"
    }
}
$billboardFragmentStart = $impostorSource.IndexOf('void fragment()')
if ($billboardFragmentStart -lt 0) {
    throw 'Cloud billboard fragment function is missing'
}
$billboardFragment = $impostorSource.Substring($billboardFragmentStart)
foreach ($wastedToken in @(
    'vec3 accum_color',
    'float density_factor',
    'accum_color +='
)) {
    if ($billboardFragment.Contains($wastedToken)) {
        throw "Cloud billboard still calculates unused lighting: $wastedToken"
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
    'mix(final_rgb, reference_color, clamp(volume_lod_factor'
)) {
    if (-not $volumeSource.Contains($requiredToken)) {
        throw "Cloud volume shader is missing preview/bake override token: $requiredToken"
    }
}
