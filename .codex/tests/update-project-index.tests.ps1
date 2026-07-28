$ErrorActionPreference = 'Stop'

$codexDir = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $codexDir 'update-project-index.ps1'
$index = Join-Path $codexDir 'project-index.txt'

& $generator

$content = (Get-Content -Raw -LiteralPath $index) -replace "`r`n", "`n"

if ($content -notmatch '(?m)^\[CONFIG\]$') {
    throw 'Missing CONFIG section'
}

if ($content -notmatch '(?m)^project\.godot$') {
    throw 'Missing project.godot'
}

if ($content -notmatch '(?m)^\[SCRIPTS\]$') {
    throw 'Missing SCRIPTS section'
}

if ($content -match '(?m)^\.godot[\\/]') {
    throw 'Cache directory leaked into index'
}

if ($content -match '(?m)^references[\\/].*\.mp4$') {
    throw 'Reference media leaked into index'
}
