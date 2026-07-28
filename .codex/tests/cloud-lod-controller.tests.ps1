$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$godot = 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$controllerPath = Join-Path $projectRoot 'levels\components\CloudManager\cloud_lod_controller.gd'

if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot executable not found: $godot"
}

if (-not (Test-Path -LiteralPath $controllerPath)) {
    throw "Cloud LOD controller is missing: $controllerPath"
}

$source = Get-Content -LiteralPath $controllerPath -Raw
foreach ($requiredToken in @(
    'apply_distance',
    'set_instance_shader_parameter',
    'show_volume',
    'show_impostor',
    '_volume_meshes',
    'configure_lod',
    'lod_local_radius',
    'preview_lod_in_editor'
)) {
    if (-not $source.Contains($requiredToken)) {
        throw "Cloud LOD controller is missing contract token: $requiredToken"
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
    throw "Cloud LOD controller parse check failed with exit code $exitCode.`n$output"
}
