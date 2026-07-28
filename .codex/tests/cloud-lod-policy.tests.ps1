$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$godot = 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'

if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot executable not found: $godot"
}

$policyPath = Join-Path $projectRoot 'levels\components\CloudManager\cloud_lod_policy.gd'
$source = Get-Content -LiteralPath $policyPath -Raw
foreach ($requiredKey in @('"show_volume"', '"show_impostor"', '"lod_fade"')) {
    if (-not $source.Contains($requiredKey)) {
        throw "Cloud LOD policy is missing result key $requiredKey"
    }
}

$ErrorActionPreference = 'Continue'
$output = & $godot `
    --headless `
    --editor `
    --rendering-method gl_compatibility `
    --path $projectRoot `
    --quit 2>&1 | Out-String
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'

if ($exitCode -ne 0 -or $output -match 'Parse Error') {
    throw "Cloud LOD policy parse check failed with exit code $exitCode.`n$output"
}
