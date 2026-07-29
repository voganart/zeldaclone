$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$controllerPath = Join-Path $projectRoot 'levels\components\CloudManager\cloud_lod_controller.gd'

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
    'func configure_stream_fade(',
    'func set_edge_fade(value: float) -> void',
    '_stream_coverage_radius + _stream_prewarm_margin',
    'outer_radius - _stream_edge_fade_width',
    '1.0 - smoothstep(',
    '_recycle_fade * _edge_fade',
    'lod_local_radius',
    'preview_lod_in_editor'
)) {
    if (-not $source.Contains($requiredToken)) {
        throw "Cloud LOD controller is missing contract token: $requiredToken"
    }
}
