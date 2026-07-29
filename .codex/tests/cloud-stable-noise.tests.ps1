$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$shaderPath = Join-Path $projectRoot (
    'assets\shaders\Cloud_volumetric\cloud_volumetric.gdshader'
)
$shader = Get-Content -Raw $shaderPath

if ($shader.Contains('v_world_pos_center')) {
    throw 'Cloud noise still depends on the moving CloudManager world center'
}
if (-not $shader.Contains('TIME * move_speed * erosion_offset_speed')) {
    throw 'Cloud erosion noise no longer animates over time'
}
if (-not $shader.Contains('TIME * move_speed')) {
    throw 'Cloud detail noise no longer animates over time'
}

foreach ($discardedToken in @(
    'weather_cloud_offset',
    'weather_cloud_evolution',
    'lod_is_impostor',
    'pool_fade'
)) {
    if ($shader.Contains($discardedToken)) {
        throw "Discarded cloud subsystem leaked into simple shader: $discardedToken"
    }
}

Write-Output 'PASS: simple cloud noise is stable and time-animated'
