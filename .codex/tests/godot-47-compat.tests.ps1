$ErrorActionPreference = 'Stop'

$codexDir = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $codexDir
$godot = 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'

if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot executable not found: $godot"
}

$ErrorActionPreference = 'Continue'
$output = & $godot --headless --editor --path $projectRoot --quit 2>&1 | Out-String
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'

if ($exitCode -ne 0) {
    throw "Godot editor parse failed with exit code $exitCode.`n$output"
}

if ($output -match 'Parse Error: Not all code paths return a value' -and
    $output -match 'res://addons/proton_scatter/src/scatter\.gd:241') {
    throw "Proton Scatter is incompatible with Godot 4.7.1.`n$output"
}
