$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$fieldPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_weather_field.gd'

if (-not (Test-Path -LiteralPath $fieldPath)) {
    throw "Cloud weather field is missing: $fieldPath"
}

$field = Get-Content -Raw $fieldPath

foreach ($token in @(
    'class_name CloudWeatherField',
    'func candidate_chunks(',
    'func candidate_members(',
    'func member_data(',
    'smooth_value_noise',
    'formation_phase',
    'formation_lifetime',
    'formation_fade_duration',
    'shape_offset',
    'cloud_radius',
    'wind_direction'
)) {
    if (-not $field.Contains($token)) {
        throw "Cloud weather field contract is missing: $token"
    }
}

foreach ($forbidden in @(
    'coverage_radius / profile.cell_size',
    'coverage_height / profile.cell_size',
    'profile.coverage_radius /',
    'profile.coverage_height /'
)) {
    if ($field.Contains($forbidden)) {
        throw "Weather field still enumerates the legacy fine grid: $forbidden"
    }
}

if (($field | Select-String -Pattern 'for .* in range' -AllMatches).Matches.Count -gt 8) {
    throw 'Weather field contains unexpectedly deep/unbounded enumeration'
}

Write-Host 'Cloud weather field contract checks passed.'
