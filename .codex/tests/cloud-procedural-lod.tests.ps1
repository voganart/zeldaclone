$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$noisePath = Join-Path $projectRoot 'assets/shaders/Cloud_volumetric/cloud_noise.tres'

if (-not (Test-Path -LiteralPath $noisePath)) {
    throw 'Shared cloud NoiseTexture3D is missing'
}

$volumeMaterial = Get-Content -Raw (
    Join-Path $projectRoot 'assets/shaders/Cloud_volumetric/cloud_volumetric.tres'
)
if (-not $volumeMaterial.Contains(
    'path="res://assets/shaders/Cloud_volumetric/cloud_noise.tres"'
)) {
    throw 'Volume material does not use the shared cloud noise'
}
