# World-Space Cloud Cluster Streaming Design

## Goal

Make `EnvironmentSystem/CloudManager` the only cloud system. Preserve the attractive editor distribution, extend it to unlimited 3D flight, and prevent visible cloud teleporting or whole-sphere replacement.

## Current root cause

The editor and runtime currently use different distribution paths:

- editor preview calls `CloudManager.spawn_clouds()` and places saved children on a clustered spherical shell;
- runtime calls `apply_tuning_profile()`, hides those children, and relocates them through `CloudCellLayout`;
- the mostly empty `cloud_tuning_profile.tres` supplies defaults that differ strongly from the values saved on `CloudManager`;
- the F10 panel edits this second runtime layout.

The scene file is not overwritten during play. Its saved children are hidden and repositioned in memory.

## Single-system architecture

### CloudManager

`EnvironmentSystem/CloudManager` owns preview generation, runtime streaming, pooling, LOD configuration, exclusion checks, and weather selection. No second cloud node or background sky-cloud layer is added.

The automatic F10 panel is disabled by default. It remains available only through an explicit `enable_runtime_tuning` debug property.

### CloudClusterLayout

A pure deterministic layout helper replaces the two incompatible distribution algorithms.

It receives a world sector key, seed, and tuning profile and returns cluster data:

- stable world-space cluster center;
- 3–6 overlapping member transforms;
- varied scale, aspect, rotation, and shape seed;
- deterministic priority used for streaming;
- approximate cluster radius for exclusion checks.

Both editor preview and runtime call this helper. Editor preview displays a spherical sample around the origin; runtime requests world sectors around the player. The sphere is therefore only a preview boundary, not an object that is moved or replaced during play.

## Runtime streaming

The world is divided into invisible, large 3D sectors. Sector keys and generated cloud transforms are anchored in world space.

CloudManager maintains three concentric ranges around the player:

1. **Visible range** — normal LOD processing.
2. **Prewarm range** — distant sectors are prepared as billboards before the player can notice them.
3. **Retention range** — sectors behind the player remain alive longer than the visible range, preventing immediate disappearance when the camera turns.

Sector creation is independent of the camera view direction, so turning the camera does not cut clouds off. Work is limited by a per-frame budget to avoid frame-time spikes.

When a sector enters the prewarm range, its clusters start at zero opacity in billboard LOD and fade in slowly. A cluster is recycled only after it leaves the retention range and completes its fade. Individual far clusters are recycled; an entire spherical shell is never swapped.

The saved preview children in `environment_system.tscn` remain visible at startup. They become the initial pool and fade/recycle individually only when their world positions leave the retention range. Runtime initialization must not hide or relocate all children on the first frame.

## LOD

Every cloud member continues to use `cloud_lod_controller.gd`:

- near: full volumetric raymarch;
- medium: reduced-step volumetric;
- transition: shader dither crossfade;
- far: billboard/impostor;
- recycle: independent pool fade.

All saved editor children and newly streamed children receive the same LOD configuration. Billboard and volumetric shaders retain matched day/night lighting and lower-shadow treatment.

Cluster-level optimization may later replace several far member billboards with one baked cluster impostor. It is not required for the first implementation.

## Configuration

The assigned `CloudTuningProfile` is the single source for distribution and LOD. Duplicate legacy distribution values on CloudManager are removed or shown read-only.

The project profile is populated with the current attractive EnvironmentSystem values instead of relying on class defaults:

- cloud count/density based on the current 50-cloud preview;
- scale range `Vector3(40, 20, 80)` to `Vector3(100, 80, 150)`;
- clustering equivalent to the current `cluster_count = 40` and `cluster_spread = 1.0`;
- existing LOD distances remain the starting point and stay editable.

Changing a profile value affects editor regeneration and runtime identically.

## Weather and wind

CloudManager exposes a `WeatherProfile` resource in its inspector and applies it through the existing WeatherManager autoload. This keeps one global wind source for clouds, grass, trees, and water while making cloud controls discoverable from EnvironmentSystem.

The first implementation controls:

- wind direction and speed;
- cloud noise advection;
- slow shared formation drift;
- transition duration when weather changes.

Noise coordinates remain independent from player movement. Formation drift is a shared world offset, not a per-cloud random movement.

## Exclusion volumes

Existing `CloudExclusionVolume` nodes continue to reject generated clusters around terrain. The test uses the cluster bounding radius so overlapping members do not intersect the protected land volume.

## Failure handling

- Missing cloud scene or profile: keep saved preview children visible and emit one warning.
- Missing player: keep current sectors unchanged until a player becomes available.
- Pool exhaustion: defer far-sector creation; never steal or teleport a visible near cloud.
- Invalid range ordering: sanitize to `visible < prewarm < retention`.

## Verification

Automated contract tests verify:

1. runtime initialization does not hide or relocate every saved child;
2. editor and runtime reference the same `CloudClusterLayout`;
3. layout output is deterministic for key and seed;
4. requested sectors cover full 3D space around the player;
5. retention range exceeds prewarm and visible ranges;
6. LOD and pool fades remain independent;
7. automatic F10 creation is disabled by default;
8. WeatherProfile is exposed through CloudManager;
9. obsolete `CloudCellLayout` runtime distribution is no longer referenced.

Manual Godot verification:

1. compare EnvironmentSystem preview and `Level_01` immediately after launch;
2. fly toward a visible cloud and confirm it remains in place;
3. fly continuously in horizontal and vertical directions;
4. rotate the camera and confirm clouds do not disappear at screen edges;
5. inspect far billboard-to-volume transitions during day and night;
6. change wind from CloudManager and check clouds, grass, trees, and water;
7. watch FPS and 1% low while crossing sector boundaries.

## Deferred work

- baked full-sphere cluster impostor atlases;
- cloud formation and dissolution lifecycle;
- mobile-quality presets;
- automatic weather changes.

These are separate tasks after the unified distribution is visually accepted.
