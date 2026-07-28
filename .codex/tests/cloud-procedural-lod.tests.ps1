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

$billboardMaterialPath = Join-Path (
    $projectRoot
) 'assets/shaders/Cloud_impostor/cloud_procedural_billboard.tres'
if (-not (Test-Path -LiteralPath $billboardMaterialPath)) {
    throw 'Procedural cloud billboard material is missing'
}

$cloudScene = Get-Content -Raw (
    Join-Path $projectRoot 'assets/shaders/Cloud_volumetric/cloud.tscn'
)
if (-not $cloudScene.Contains(
    'path="res://assets/shaders/Cloud_impostor/cloud_procedural_billboard.tres"'
)) {
    throw 'Cloud scene does not use the procedural billboard material'
}
if ($cloudScene.Contains('cloud_01_albedo.png')) {
    throw 'Cloud scene still depends on the baked atlas'
}
