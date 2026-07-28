$ErrorActionPreference = 'Stop'

$codexDir = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $codexDir
$godot = 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$scene = Join-Path $projectRoot 'levels\components\BattleArena\BattleArena.tscn'
$logPath = 'C:\tmp\zeldaclone-battlearena-regression.log'

if (Test-Path -LiteralPath $logPath) {
    Remove-Item -LiteralPath $logPath -Force
}

$arguments = "--editor `"$scene`" --quit-after 600 --verbose --log-file `"$logPath`""
$process = Start-Process `
    -FilePath $godot `
    -ArgumentList $arguments `
    -WorkingDirectory $projectRoot `
    -WindowStyle Hidden `
    -Wait `
    -PassThru

$log = Get-Content -Raw -LiteralPath $logPath

if ($log -notmatch "Completed load for: 'res://levels/components/BattleArena/BattleArena\.tscn'") {
    throw "BattleArena scene was not opened by the editor. Log: $logPath"
}

if ($log -match 'CrashHandlerException') {
    throw "Godot crashed while opening BattleArena. Log: $logPath"
}

if ($log -match "Nonexistent function 'get_phantom_camera_hosts' in base 'null instance'" -or
    $log -match "Invalid access to property or key 'pcam_host_added_to_scene' on a base object of type 'null instance'") {
    throw "Phantom Camera used a freed manager while opening BattleArena. Log: $logPath"
}

if ($process.ExitCode -ne 0) {
    throw "Godot exited with code $($process.ExitCode). Log: $logPath"
}
