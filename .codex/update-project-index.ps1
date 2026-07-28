$ErrorActionPreference = 'Stop'

$codexDir = $PSScriptRoot
$projectRoot = Split-Path -Parent $codexDir
$indexPath = Join-Path $codexDir 'project-index.txt'

Push-Location $projectRoot
try {
    $allFiles = & rg --files
    if ($LASTEXITCODE -ne 0) {
        throw "rg failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$files = $allFiles |
    ForEach-Object { $_ -replace '\\', '/' } |
    Where-Object {
        $_ -notmatch '^(?:\.git|\.godot|\.import|references)/' -and
        $_ -notmatch '\.(?:import|uid|tmp)$'
    } |
    Sort-Object -Unique

$config = $files | Where-Object {
    $_ -in @('.editorconfig', '.gitattributes', '.gitignore', 'project.godot')
}

$scripts = $files | Where-Object {
    $_ -notmatch '^addons/' -and $_ -match '\.(?:gd|cs)$'
}

$scenes = $files | Where-Object {
    $_ -notmatch '^addons/' -and $_ -match '\.tscn$'
}

$resources = $files | Where-Object {
    $_ -notmatch '^addons/' -and $_ -match '\.(?:tres|res)$'
}

$shaders = $files | Where-Object {
    $_ -notmatch '^addons/' -and $_ -match '\.(?:gdshader|gdshaderinc|material)$'
}

$addons = $files | Where-Object {
    $_ -match '^addons/' -and
    $_ -match '\.(?:cfg|gd|cs|tscn|tres|res|gdshader|gdshaderinc|material)$'
}

$output = @()
foreach ($section in @(
    @{ Name = 'CONFIG'; Files = $config },
    @{ Name = 'SCRIPTS'; Files = $scripts },
    @{ Name = 'SCENES'; Files = $scenes },
    @{ Name = 'RESOURCES'; Files = $resources },
    @{ Name = 'SHADERS'; Files = $shaders },
    @{ Name = 'ADDONS'; Files = $addons }
)) {
    $output += "[$($section.Name)]"
    $output += $section.Files
    $output += ''
}

$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($indexPath, $output, $utf8WithoutBom)
