$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$layoutPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_cell_layout.gd'
$managerPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/CloudManager.gd'
$controllerPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_lod_controller.gd'
$volumeShaderPath = Join-Path (
    $projectRoot
) 'assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader'
$impostorShaderPath = Join-Path (
    $projectRoot
) 'assets/shaders/Cloud_impostor/cloud_impostor.gdshader'
$graphicsPath = Join-Path (
    $projectRoot
) 'common/autoload/graphics_manager.gd'

if (-not (Test-Path -LiteralPath $layoutPath)) {
    throw 'Cloud cell layout helper is missing'
}

$layout = Get-Content -Raw $layoutPath
$manager = Get-Content -Raw $managerPath
$controller = Get-Content -Raw $controllerPath
$volumeShader = Get-Content -Raw $volumeShaderPath
$impostorShader = Get-Content -Raw $impostorShaderPath
$graphics = Get-Content -Raw $graphicsPath

foreach ($token in @(
    'static func world_to_cell(',
    'static func desired_cells(',
    'static func cell_transform(',
    'horizontal_radius = maxi(horizontal_radius, 1)',
    'vertical_radius = maxi(vertical_radius, 0)',
    'density = clampf(density, 0.0, 1.0)',
    'candidates.resize(limit)'
)) {
    if (-not $layout.Contains($token)) {
        throw "Cloud cell layout contract is missing: $token"
    }
}

foreach ($token in @(
    'const CloudCellLayout = preload(',
    'world_seed',
    'cell_size',
    'horizontal_cell_radius',
    'vertical_cell_radius',
    'cell_density',
    'pool_updates_per_frame',
    '_active_cells',
    '_free_clouds',
    '_requested_cells',
    'CloudCellLayout.world_to_cell(',
    'CloudCellLayout.desired_cells(',
    'CloudCellLayout.cell_transform('
)) {
    if (-not $manager.Contains($token)) {
        throw "Cloud manager pool contract is missing: $token"
    }
}

$runtimeProcessStart = $manager.IndexOf('func _process(')
if ($runtimeProcessStart -lt 0) {
    throw 'Cloud manager runtime process is missing'
}
$runtimeProcessEnd = $manager.IndexOf(
    'func _initialize_runtime_pool',
    $runtimeProcessStart
)
if ($runtimeProcessEnd -lt 0) {
    throw 'Cloud manager pool initialization is missing'
}
$runtimeProcess = $manager.Substring(
    $runtimeProcessStart,
    $runtimeProcessEnd - $runtimeProcessStart
)
if ($runtimeProcess.Contains('rotate_y(')) {
    throw 'Cloud manager still rotates the cloud root at runtime'
}
if ($runtimeProcess.Contains('global_position.x = player_pos.x')) {
    throw 'Cloud manager still follows the player at runtime'
}
foreach ($unsafeInference in @(
    'var target_cell := _requested_cells.pop_front()',
    'var released := _released_clouds.pop_back()',
    'var center := cluster_centers.pick_random()'
)) {
    if ($manager.Contains($unsafeInference)) {
        throw "Variant inference warning remains: $unsafeInference"
    }
}

foreach ($shader in @($volumeShader, $impostorShader)) {
    if (-not $shader.Contains('instance uniform float pool_fade')) {
        throw 'Cloud shader is missing per-instance pool fade'
    }
    if (-not $shader.Contains('physical_alpha *= pool_fade')) {
        throw 'Cloud shader does not apply pool fade to final opacity'
    }
}
if (-not $controller.Contains('func set_pool_fade(value: float)')) {
    throw 'Cloud LOD controller cannot apply pool fade'
}
foreach ($token in @(
    'enum RecyclePhase',
    'recycle_fade_duration',
    'RecyclePhase.FADING_OUT',
    'RecyclePhase.FADING_IN',
    'set_pool_fade'
)) {
    if (-not $manager.Contains($token)) {
        throw "Cloud recycling fade contract is missing: $token"
    }
}

foreach ($token in @(
    '"cloud_pool_horizontal_radius"',
    '"cloud_pool_vertical_radius"',
    '"cloud_pool_density"',
    '"cloud_pool_updates_per_frame"'
)) {
    $matches = [regex]::Matches($graphics, [regex]::Escape($token)).Count
    if ($matches -ne 3) {
        throw "Cloud pool quality setting must exist in 3 presets: $token"
    }
}

function Get-CloudPresetValue {
    param(
        [string]$PresetName,
        [string]$SettingName
    )
    $start = $graphics.IndexOf("Quality.${PresetName}: {")
    if ($start -lt 0) {
        throw "Graphics preset is missing: $PresetName"
    }
    $nextPreset = $graphics.IndexOf("`n`tQuality.", $start + 10)
    $length = if ($nextPreset -gt $start) {
        $nextPreset - $start
    } else {
        $graphics.Length - $start
    }
    $block = $graphics.Substring($start, $length)
    $match = [regex]::Match(
        $block,
        '"' + [regex]::Escape($SettingName) + '"\s*:\s*([0-9.]+)'
    )
    if (-not $match.Success) {
        throw "Preset setting is missing: $PresetName/$SettingName"
    }
    return [double]$match.Groups[1].Value
}

$presetRequirements = @{
    LOW = @{ MinimumRadius = 4; MaximumExpectedClouds = 50 }
    MEDIUM = @{ MinimumRadius = 5; MaximumExpectedClouds = 50 }
    HIGH = @{ MinimumRadius = 7; MaximumExpectedClouds = 50 }
}
foreach ($presetName in $presetRequirements.Keys) {
    $radius = [int](Get-CloudPresetValue `
        $presetName 'cloud_pool_horizontal_radius')
    $vertical = [int](Get-CloudPresetValue `
        $presetName 'cloud_pool_vertical_radius')
    $density = Get-CloudPresetValue $presetName 'cloud_pool_density'
    if ($radius -lt $presetRequirements[$presetName].MinimumRadius) {
        throw "Cloud pool radius is too short: $presetName/$radius"
    }

    $candidateCount = 0
    for ($y = -$vertical; $y -le $vertical; $y++) {
        for ($z = -$radius; $z -le $radius; $z++) {
            for ($x = -$radius; $x -le $radius; $x++) {
                $nx = $x / $radius
                $nz = $z / $radius
                $ny = if ($vertical -gt 0) { $y / $vertical } else { 0 }
                if (($nx * $nx + $ny * $ny + $nz * $nz) -le 1.000001) {
                    $candidateCount++
                }
            }
        }
    }
    $expectedClouds = $candidateCount * $density
    if ($expectedClouds -gt $presetRequirements[$presetName].MaximumExpectedClouds) {
        throw "Cloud preset overfills the 50-cloud pool: $presetName/$expectedClouds"
    }
}

$fadeMatch = [regex]::Match(
    $manager,
    'recycle_fade_duration:\s*float\s*=\s*([0-9.]+)'
)
if (-not $fadeMatch.Success -or [double]$fadeMatch.Groups[1].Value -lt 0.8) {
    throw 'Cloud recycle fade duration must be at least 0.8 seconds'
}
