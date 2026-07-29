$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$profilePath = Join-Path $projectRoot 'common/weather/weather_profile.gd'
$resourcePath = Join-Path $projectRoot 'common/weather/weather_profile.tres'
$managerPath = Join-Path $projectRoot 'common/weather/weather_manager.gd'
$projectPath = Join-Path $projectRoot 'project.godot'
$treeShaderPath = Join-Path $projectRoot 'assets/shaders/TreeWindShader.gdshader'
$cloudManagerPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/CloudManager.gd'

foreach ($path in @($profilePath, $resourcePath, $managerPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Weather system file is missing: $path"
    }
}

$profile = Get-Content -Raw $profilePath
$manager = Get-Content -Raw $managerPath
$project = Get-Content -Raw $projectPath
$treeShader = Get-Content -Raw $treeShaderPath
$cloudManager = Get-Content -Raw $cloudManagerPath

foreach ($token in @(
    '@export var weather_profile: WeatherProfile',
    'var _base_transforms: Dictionary = {}',
    'func _apply_weather_profile() -> void',
    'weather_manager.call("apply_profile", weather_profile, 0.0)',
    'func _get_weather_offset() -> Vector3',
    'player.global_position - weather_offset',
    'base_transform.translated(weather_offset)'
)) {
    if (-not $cloudManager.Contains($token)) {
        throw "CloudManager weather integration is missing: $token"
    }
}

foreach ($token in @(
    'class_name WeatherProfile',
    'wind_direction',
    'wind_speed',
    'wind_strength',
    'wind_turbulence',
    'manual_blend_duration',
    'cloud_drift_multiplier',
    'cloud_noise_advection',
    'cloud_evolution_speed',
    'formation_lifetime_min',
    'formation_lifetime_max',
    'formation_fade_duration',
    'func sanitize() -> void',
    'func copy_values_from(source: WeatherProfile) -> void'
)) {
    if (-not $profile.Contains($token)) {
        throw "WeatherProfile contract is missing: $token"
    }
}

foreach ($token in @(
    'signal weather_changed(profile: WeatherProfile)',
    'func apply_profile(',
    'new_profile: WeatherProfile',
    'blend_duration: float = -1.0',
    'func get_cloud_offset() -> Vector3',
    'RenderingServer.global_shader_parameter_set',
    'set_wind_direction',
    'set_wind_strength',
    'set_wind_turbulence',
    '&"wind_direction"',
    '&"wind_intensity"'
)) {
    if (-not $manager.Contains($token)) {
        throw "WeatherManager contract is missing: $token"
    }
}

if (-not $project.Contains(
    'WeatherManager="*res://common/weather/weather_manager.gd"'
)) {
    throw 'WeatherManager autoload is missing'
}

foreach ($globalName in @(
    'weather_wind_direction',
    'weather_wind_speed',
    'weather_wind_strength',
    'weather_wind_turbulence',
    'weather_cloud_offset',
    'weather_cloud_evolution'
)) {
    if (-not $project.Contains($globalName)) {
        throw "Canonical weather shader global is missing: $globalName"
    }
    if (-not $manager.Contains($globalName)) {
        throw "WeatherManager does not publish: $globalName"
    }
}

foreach ($token in @(
    'global uniform vec3 weather_wind_direction',
    'global uniform float weather_wind_speed',
    'global uniform float weather_wind_strength',
    'global uniform float weather_wind_turbulence',
    'wind_response',
    'turbulence_response'
)) {
    if (-not $treeShader.Contains($token)) {
        throw "Tree wind shader contract is missing: $token"
    }
}

foreach ($legacyUniform in @(
    'uniform float wind_speed',
    'uniform float wind_strength',
    'uniform vec3 wind_direction'
)) {
    if ($treeShader.Contains($legacyUniform)) {
        throw "Tree shader still owns legacy wind input: $legacyUniform"
    }
}

Write-Host 'Weather manager contract checks passed.'
