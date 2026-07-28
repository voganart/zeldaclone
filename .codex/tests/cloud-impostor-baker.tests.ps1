$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$requiredFiles = @(
    'addons/cloud_impostor_baker/plugin.cfg',
    'addons/cloud_impostor_baker/plugin.gd',
    'addons/cloud_impostor_baker/cloud_impostor_baker.gd'
)

foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $relativePath))) {
        throw "Cloud impostor baker file is missing: $relativePath"
    }
}

$bakerSource = Get-Content -LiteralPath (Join-Path $projectRoot $requiredFiles[2]) -Raw
foreach ($requiredToken in @(
    'FRAME_COUNT := 8',
    'ATLAS_RESOLUTION := 2048',
    'RenderingServer.frame_post_draw',
    'save_png',
    'UPDATE_ONCE',
    '_collect_volume_meshes',
    '_combined_aabb'
)) {
    if (-not $bakerSource.Contains($requiredToken)) {
        throw "Cloud impostor baker is missing token: $requiredToken"
    }
}
