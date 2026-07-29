# Cloud Cluster Streaming and LOD Lighting

## Goal

Remove two visible artifacts without replacing the existing cloud scene,
procedural shaders, LOD controller, tuning profile, pool, or exclusion volumes:

- clouds must already exist in the distance instead of appearing near the player;
- clouds must form varied overlapping clusters instead of isolated repeated ovals;
- Billboard -> Volume transitions must not flash when lighting or time of day changes.

The result must support unlimited flight in every direction and keep a fixed,
mobile-tunable pool budget.

## Deterministic Cluster Layout

The world grid stores deterministic cluster anchors rather than independent
single-cloud cells. Each accepted anchor produces a deterministic number of
members between `cluster_min_members` and `cluster_max_members`.

Every member derives from the anchor coordinate, member index, and world seed:

- local horizontal and vertical offset;
- scale multiplier and per-axis aspect;
- yaw;
- procedural shape offset.

Offsets are limited by `cluster_spread`. Members overlap deliberately, producing
larger compound silhouettes while remaining normal pooled `Cloud` instances.
`target_cloud_count` and `pool_capacity` continue to count individual cloud
instances, not anchors, so performance remains predictable.

Cluster membership is stable in world coordinates. Moving away and returning
reconstructs the same cluster. Exclusion volumes test every member separately;
rejected members do not cause the rest of their cluster to disappear.

## Prewarm and Boundary Fade

`coverage_radius` remains the radius at which clouds are fully eligible to be
visible. `prewarm_margin` extends the streaming region beyond it. New pooled
instances are positioned while they are inside this outer prewarm band.

`edge_fade_width` controls a radial visibility factor:

- alpha is zero at the outer prewarm boundary;
- alpha increases smoothly while approaching the fully visible region;
- clouds are fully visible before entering `coverage_radius`;
- the reverse fade happens when leaving the region.

The radial factor multiplies the existing recycle fade. Pool relocation still
uses the existing fade-out -> move -> fade-in sequence, but relocation completes
outside the fully visible region whenever a prewarmed slot is available.

Candidate ordering prioritizes the currently empty distance bands while initial
population is in progress, then preserves active nearby clusters. No camera
direction offset is used, because the player may turn or fly in any direction.

Recommended High starting values:

- `coverage_radius`: 2200 m;
- `prewarm_margin`: 800 m;
- `edge_fade_width`: 650 m;
- `target_cloud_count`: 120;
- `pool_capacity`: 144;
- `cluster_min_members`: 3;
- `cluster_max_members`: 6;
- `cluster_spread`: 220 m;
- `cluster_scale_variation`: 0.45.

These values remain live-editable through F10 and can later be reduced by a
separate mobile profile.

## Matched LOD Lighting

Both shaders continue receiving `color_light` and `color_shadow` from
`DayNightCycle`. The transition does not duplicate or replace the existing
day/night gradients.

Both shaders add the same cheap reference-lighting function based on normalized
local height. It provides a stable lower shadow and upper highlight independent
of raymarch step count.

- Billboard uses reference lighting.
- Full Volume keeps its current density-based volumetric lighting.
- Cheap Volume blends gradually from volumetric lighting toward reference
  lighting using `volume_lod_factor`.
- At the start of the dither transition, Volume and Billboard therefore use the
  same reference-lighting model and matching day/night colors.

The current pool-fade normalization bug is corrected in both shaders: raw
physical alpha normalizes accumulated color, while `pool_fade` affects final
alpha only. Fade-in and fade-out must never increase RGB brightness.

Complementary Bayer dithering remains responsible only for coverage switching.
It must not switch between visibly different lighting models.

## Tuning Profile

Add the following fields to `CloudTuningProfile` and the existing F10 panel:

- `cluster_min_members`;
- `cluster_max_members`;
- `cluster_spread`;
- `cluster_scale_variation`;
- `prewarm_margin`;
- `edge_fade_width`.

Sanitization enforces:

- minimum members >= 1;
- maximum members >= minimum members;
- non-negative spread, prewarm margin, and fade width;
- fade width <= prewarm margin;
- pool capacity >= target cloud count.

The existing Save Project, Reload Saved, Reset, and Regenerate actions continue
to operate on the same resource.

## Performance

- No extra cloud nodes beyond `pool_capacity`.
- No runtime textures, captures, Viewports, or baked impostor atlases.
- Cluster layout uses deterministic hashes and is recalculated only when the
  player crosses a streaming cell or tuning changes.
- Edge fade is one scalar instance parameter per cloud.
- Billboard keeps its existing raymarch step count.
- Full volumetric lighting is retained only at close range.
- Low/mobile quality can later use fewer members, smaller capacity, earlier
  Cheap Volume, and a wider billboard region without changing architecture.

## Validation

Automated/static tests verify:

- identical world seed and anchor produce identical cluster members;
- member count stays inside configured bounds;
- total active/reserved/free clouds never exceeds pool capacity;
- prewarm candidates extend beyond the fully visible radius;
- boundary visibility is zero outside the outer radius and one inside the fully
  visible radius;
- excluded cluster members are rejected independently;
- both shaders normalize color with raw alpha before applying `pool_fade`;
- both shaders contain the same reference-lighting contract;
- Volume reaches reference lighting before complementary dither begins;
- all existing LOD, panel, flight, and Godot 4.7 compatibility tests pass.

Manual verification:

1. Fly toward distant clusters and rotate the camera 360 degrees.
2. Confirm clouds are visible ahead before movement and never pop at close range.
3. Confirm clusters contain varied overlapping members and remain stable after
   leaving and returning.
4. Approach the same cloud by day and night and confirm Billboard -> Volume has
   no white flash or sudden lower-shadow change.
5. Tune cluster and prewarm settings in F10 without camera capture.
6. Verify exclusion volumes still keep cloud members out of island terrain.
7. Compare High and reduced mobile settings using FPS, draw calls, and memory.
