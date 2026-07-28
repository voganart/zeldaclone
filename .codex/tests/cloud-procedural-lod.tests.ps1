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

$dayNight = Get-Content -Raw (
    Join-Path $projectRoot 'levels/components/Environment/DayNightCycle.gd'
)
foreach ($token in @(
    'cloud_billboard_material',
    '_apply_cloud_colors',
    'cloud_light_color.sample(sample_pos)',
    'cloud_shadow_color.sample(sample_pos)'
)) {
    if (-not $dayNight.Contains($token)) {
        throw "Day/night cloud integration is missing: $token"
    }
}

$graphics = Get-Content -Raw (
    Join-Path $projectRoot 'common/autoload/graphics_manager.gd'
)
foreach ($token in @(
    '"cloud_cheap_start"',
    '"cloud_transition_start"',
    '"cloud_transition_end"',
    '"cloud_full_steps"',
    '"cloud_cheap_steps"',
    '"cloud_billboard_steps"'
)) {
    if (-not $graphics.Contains($token)) {
        throw "Cloud quality preset is missing: $token"
    }
}
