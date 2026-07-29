$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

$inputPlugin = Get-Content -Raw (
    Join-Path $projectRoot (
        'addons\InputMapperPresetLoader\inputmapperpresetloader.gd'
    )
)
$inputScene = Get-Content -Raw (
    Join-Path $projectRoot (
        'addons\InputMapperPresetLoader\InputMapperPresets.tscn'
    )
)

foreach ($source in @($inputPlugin, $inputScene)) {
    if ($source.Contains('res://addons/inputmapperpresetloader/')) {
        throw 'InputMapperPresetLoader contains a case-unsafe resource path'
    }
}

$propertyListScripts = @(
    'addons\proton_scatter\src\scatter.gd',
    'addons\proton_scatter\src\scatter_item.gd',
    'addons\simplegrasstextured\grass.gd'
)
foreach ($relativePath in $propertyListScripts) {
    $script = Get-Content -Raw (Join-Path $projectRoot $relativePath)
    if (-not $script.Contains(
        'func _get_property_list() -> Array[Dictionary]:'
    )) {
        throw "_get_property_list is not typed as Array[Dictionary]: $relativePath"
    }
}

$testLevel = Get-Content -Raw (
    Join-Path $projectRoot 'levels\test_level\level.tscn'
)
$staleOverride = (
    '[node name="EndPoint" ' +
    'parent="NavigationRegion3D/MovingPlatformRoot2"'
)
if ($testLevel.Contains($staleOverride)) {
    throw 'Test level still overrides the removed moving-platform EndPoint'
}

$platformHeader = (
    '[node name="MovingPlatformRoot2" parent="NavigationRegion3D" ' +
    'instance=ExtResource("11_eonaa")]'
)
$platformStart = $testLevel.IndexOf($platformHeader)
if ($platformStart -lt 0) {
    throw 'MovingPlatformRoot2 instance is missing from the test level'
}
$nextNode = $testLevel.IndexOf(
    '[node ',
    $platformStart + $platformHeader.Length
)
if ($nextNode -lt 0) {
    $nextNode = $testLevel.Length
}
$platformBlock = $testLevel.Substring(
    $platformStart,
    $nextNode - $platformStart
)
if (-not $platformBlock.Contains(
    'move_offset = Vector3(-8, 0, -4.000001)'
)) {
    throw 'MovingPlatformRoot2 did not preserve the removed EndPoint offset'
}

Write-Output 'PASS: known Godot 4.7 compatibility warnings are resolved'
