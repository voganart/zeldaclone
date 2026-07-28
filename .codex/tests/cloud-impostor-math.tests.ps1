$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$mathPath = Join-Path $projectRoot 'addons\cloud_impostor_baker\cloud_impostor_math.gd'

if (-not (Test-Path -LiteralPath $mathPath)) {
    throw "Cloud impostor math is missing: $mathPath"
}

$source = Get-Content -LiteralPath $mathPath -Raw
foreach ($requiredToken in @('grid_to_lower_hemisphere', 'coord.x - coord.y', '-1.0 + coord.x + coord.y')) {
    if (-not $source.Contains($requiredToken)) {
        throw "Cloud impostor math is missing token: $requiredToken"
    }
}
