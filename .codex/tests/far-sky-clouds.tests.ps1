$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$shaderPath = Join-Path $projectRoot 'assets/shaders/sky_gradient.gdshader'
$scenePath = Join-Path (
    $projectRoot
) 'levels/components/Environment/environment_system.tscn'
$cyclePath = Join-Path (
    $projectRoot
) 'levels/components/Environment/DayNightCycle.gd'
$baseNoisePath = Join-Path $projectRoot 'common/weather/far_cloud_noise_base.tres'
$detailNoisePath = Join-Path (
    $projectRoot
) 'common/weather/far_cloud_noise_detail.tres'

foreach ($path in @($baseNoisePath, $detailNoisePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Far cloud noise resource is missing: $path"
    }
    $noise = Get-Content -Raw $path
    foreach ($token in @('NoiseTexture2D', 'FastNoiseLite', 'seamless = true')) {
        if (-not $noise.Contains($token)) {
            throw "Noise resource contract is missing: $token in $path"
        }
    }
}

$shader = Get-Content -Raw $shaderPath
$scene = Get-Content -Raw $scenePath
$cycle = Get-Content -Raw $cyclePath

foreach ($builtInConstant in @('PI', 'TAU', 'E')) {
    if ($shader.Contains("const float $builtInConstant")) {
        throw "Sky shader redeclares Godot built-in constant: $builtInConstant"
    }
}

foreach ($token in @(
    'render_mode use_half_res_pass',
    'AT_HALF_RES_PASS',
    'AT_CUBEMAP_PASS',
    'HALF_RES_COLOR',
    'far_cloud_noise_base',
    'far_cloud_noise_detail',
    'weather_cloud_offset',
    'weather_cloud_evolution',
    'far_cloud_light_color',
    'far_cloud_shadow_color',
    'far_cloud_horizon_coverage',
    'far_cloud_upper_coverage',
    'far_cloud_lower_coverage'
)) {
    if (-not $shader.Contains($token)) {
        throw "Far sky cloud shader contract is missing: $token"
    }
}

foreach ($resourcePath in @(
    'res://common/weather/far_cloud_noise_base.tres',
    'res://common/weather/far_cloud_noise_detail.tres'
)) {
    if (-not $scene.Contains($resourcePath)) {
        throw "EnvironmentSystem does not reference: $resourcePath"
    }
}

foreach ($token in @(
    'shader_parameter/far_cloud_noise_base',
    'shader_parameter/far_cloud_noise_detail',
    'shader_parameter/far_cloud_horizon_coverage',
    'shader_parameter/far_cloud_upper_coverage',
    'shader_parameter/far_cloud_lower_coverage'
)) {
    if (-not $scene.Contains($token)) {
        throw "Far cloud scene parameter is missing: $token"
    }
}

foreach ($token in @(
    'far_cloud_light_color',
    'far_cloud_shadow_color',
    'cloud_light_color.sample(sample_pos)',
    'cloud_shadow_color.sample(sample_pos)'
)) {
    if (-not $cycle.Contains($token)) {
        throw "Day/night far cloud synchronization is missing: $token"
    }
}

Write-Host 'Far sky cloud contract checks passed.'
