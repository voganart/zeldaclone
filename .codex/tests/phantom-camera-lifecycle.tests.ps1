$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pluginPath = Join-Path $projectRoot 'addons\phantom_camera\plugin.gd'
$plugin = Get-Content -Raw $pluginPath

function Get-GdFunctionBlock {
    param(
        [string]$Source,
        [string]$FunctionName
    )

    $escapedName = [Regex]::Escape($FunctionName)
    $pattern = "(?ms)^func $escapedName\([^\r\n]*\).*?(?=^func |\z)"
    $match = [Regex]::Match($Source, $pattern)
    if (-not $match.Success) {
        throw "Function not found: $FunctionName"
    }
    return $match.Value
}

$enable = Get-GdFunctionBlock $plugin '_enable_plugin'
$disable = Get-GdFunctionBlock $plugin '_disable_plugin'
$enter = Get-GdFunctionBlock $plugin '_enter_tree'
$exit = Get-GdFunctionBlock $plugin '_exit_tree'

if (-not $enable.Contains(
    'add_autoload_singleton(PHANTOM_CAMERA_MANAGER'
)) {
    throw '_enable_plugin no longer owns autoload creation'
}
if (-not $disable.Contains(
    'remove_autoload_singleton(PHANTOM_CAMERA_MANAGER)'
)) {
    throw '_disable_plugin no longer owns autoload removal'
}
if ($enter.Contains('add_autoload_singleton(PHANTOM_CAMERA_MANAGER')) {
    throw '_enter_tree must not add the Phantom Camera autoload'
}
if ($exit.Contains('remove_autoload_singleton(PHANTOM_CAMERA_MANAGER)')) {
    throw '_exit_tree must not remove the Phantom Camera autoload'
}

Write-Output 'PASS: Phantom Camera autoload lifecycle is stable'
