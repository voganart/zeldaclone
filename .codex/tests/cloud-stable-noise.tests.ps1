$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$shaderPaths = @(
    'assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader',
    'assets/shaders/Cloud_impostor/cloud_impostor.gdshader'
)

foreach ($relativePath in $shaderPaths) {
    $shader = Get-Content -Raw (Join-Path $projectRoot $relativePath)

    foreach ($requiredToken in @(
        'global uniform vec3 weather_cloud_offset',
        'instance uniform vec3 shape_offset',
        'shape_offset + weather_cloud_offset',
        'shape_offset * 1.7 + weather_cloud_offset'
    )) {
        if (-not $shader.Contains($requiredToken)) {
            throw "$relativePath does not implement stable weather-driven noise: $requiredToken"
        }
    }

    foreach ($forbiddenPattern in @(
        'v_world_pos_center\s*\*\s*0\.1',
        'v_world_center\s*\*\s*0\.1'
    )) {
        if ($shader -match $forbiddenPattern) {
            throw "$relativePath still ties cloud shape noise to recycled world position: $forbiddenPattern"
        }
    }
}

Write-Output 'Stable cloud noise contract checks passed.'
