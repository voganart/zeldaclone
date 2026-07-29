$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$layoutPath = Join-Path (
    $projectRoot
) 'levels/components/CloudManager/cloud_cluster_layout.gd'
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
    '@export var enable_runtime_tuning: bool = false',
    '@export_storage var cloud_count',
    '@export_storage var spawn_radius',
    '@export_storage var cell_size',
    '@export_storage var lod_transition_start',
    'var _preview_clouds: Array[Node3D] = []',
    '_preview_clouds.append(cloud)',
    'CloudClusterLayout.preview_shape_offset(',
    'cloud.call("set_pool_fade", 1.0)',
    'if enable_runtime_tuning and OS.is_debug_build():'
)) {
    if (-not $manager.Contains($token)) {
        throw "Saved EnvironmentSystem cloud contract is missing: $token"
    }
}
if ($manager.Contains('existing_clouds[index].visible = false')) {
    throw 'Runtime initialization still hides saved EnvironmentSystem clouds'
}
if ($manager.Contains('@export_category("Legacy Settings")')) {
    throw 'Legacy cloud distribution is still exposed as a second settings source'
}

foreach ($token in @(
    'static func world_to_sector(',
    'static func candidate_sectors(',
    'static func occupancy_threshold(',
    'static func cell_data(',
    'static func candidate_members(',
    'static func preview_members(',
    'static func member_data(',
    'Array[Vector4i]',
    'Vector4i(',
    'member_index',
    'profile.coverage_radius + safe_margin',
    'profile.cluster_spread',
    'profile.cluster_scale_variation',
    '"shape_offset"',
    '"cloud_radius"'
)) {
    if (-not $layout.Contains($token)) {
        throw "Cloud cluster layout contract is missing: $token"
    }
}

foreach ($token in @(
    'const CloudClusterLayout = preload(',
    'world_seed',
    'cell_size',
    'horizontal_cell_radius',
    'vertical_cell_radius',
    'cell_density',
    'pool_updates_per_frame',
    '_active_cells',
    '_free_clouds',
    '_requested_cells',
    'CloudClusterLayout.world_to_sector(',
    'CloudClusterLayout.candidate_members(',
    'CloudClusterLayout.member_data(',
    'tuning_profile.prewarm_margin',
    'tuning_profile.retention_margin',
    'visible_members.reverse()',
    'tuning_profile.pool_capacity - _preview_clouds.size()',
    'desired.resize(request_limit)',
    'var target_key: Vector4i = _requested_cells.front()',
    'var visible_lookup: Dictionary = {}',
    'func _release_for_visible_members(',
    'var available_capacity := _free_clouds.size() + _released_clouds.size()',
    'missing_visible = maxi(missing_visible - available_capacity, 0)',
    'if not _requested_cells.is_empty():',
    '_pool_settings_dirty = true',
    'var local_player_position := to_local(',
    'player.global_position - weather_offset',
    'func _preserve_preview_without_streaming() -> void',
    '_requested_cells',
    'set_shape_offset'
)) {
    if (-not $manager.Contains($token)) {
        throw "Cloud manager pool contract is missing: $token"
    }
}
if ($layout.Contains('candidates.resize(limit)')) {
    throw 'Cloud layout still truncates the nearest sectors'
}

$peekIndex = $manager.IndexOf(
    'var target_key: Vector4i = _requested_cells.front()'
)
$capacityIndex = $manager.IndexOf(
    'elif not _free_clouds.is_empty():',
    $peekIndex
)
$popIndex = $manager.IndexOf(
    '_requested_cells.pop_front()',
    $capacityIndex
)
if (
    $peekIndex -lt 0 -or
    $capacityIndex -lt 0 -or
    $popIndex -lt $capacityIndex
) {
    throw 'Requested member is removed before pool capacity is secured'
}

$previewStart = $manager.IndexOf('func _process_preview_clouds()')
$previewEnd = $manager.IndexOf('func _request_cells(', $previewStart)
$previewProcess = $manager.Substring(
    $previewStart,
    $previewEnd - $previewStart
)
if (-not $previewProcess.Contains('_pool_settings_dirty = true')) {
    throw 'Preview retirement does not request newly available capacity'
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
    if (-not $shader.Contains('raw_alpha * pool_fade')) {
        throw 'Cloud shader does not apply pool fade to final opacity'
    }
    if (-not $shader.Contains('instance uniform vec3 shape_offset')) {
        throw 'Cloud shader is missing stable per-instance shape variation'
    }
}
if (-not $controller.Contains('func set_pool_fade(value: float)')) {
    throw 'Cloud LOD controller cannot apply pool fade'
}
foreach ($token in @(
    'func configure_from_profile(profile: CloudTuningProfile)',
    'func set_shape_offset(offset: Vector3)'
)) {
    if (-not $controller.Contains($token)) {
        throw "Cloud LOD profile contract is missing: $token"
    }
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

$fadeMatch = [regex]::Match(
    $manager,
    'recycle_fade_duration:\s*float\s*=\s*([0-9.]+)'
)
if (-not $fadeMatch.Success -or [double]$fadeMatch.Groups[1].Value -lt 0.8) {
    throw 'Cloud recycle fade duration must be at least 0.8 seconds'
}
