# Cloud Tuning Profile and Exclusion Volumes

## Goal

Replace coarse cloud pool tuning with a stable, artist-friendly workflow:

- distant billboard clouds appear 1200–2000 meters away;
- the same world cloud transitions to volumetric rendering when approached;
- nearby clouds vary strongly in size, proportions, and procedural shape;
- parameters can be changed live in the running game;
- approved values save into a project resource tracked by Git;
- clouds do not intersect island terrain exclusion volumes.

## Core Architecture

### Project tuning resource

Create a `CloudTuningProfile` resource and store the active profile at:

`res://levels/components/CloudManager/cloud_tuning_profile.tres`

`CloudManager` consumes this resource as its single source of cloud distribution,
shape, LOD, recycling, and performance settings. `GraphicsManager` may select
different profiles for Low, Medium, and High later, but must not overwrite
individual profile values during the first implementation.

The resource exposes:

### Distribution

- `coverage_radius`: outer horizontal streaming radius in meters;
- `coverage_height`: vertical streaming half-height in meters;
- `target_cloud_count`: desired active cloud count;
- `pool_capacity`: hard upper bound for instantiated cloud nodes;
- `cell_size`: world grid spacing;
- `world_seed`: stable layout seed.

### Size and shape

- `scale_min`: minimum per-axis cloud scale;
- `scale_max`: maximum per-axis cloud scale;
- `aspect_variation`: extra deterministic per-axis variation;
- `large_cloud_chance`: deterministic probability of a large variant;
- `large_cloud_multiplier`: additional scale for large variants;
- `shape_variation`: deterministic per-instance procedural noise offset range.
- `lobe_spread`: distance between procedural silhouette lobes;
- `lobe_variation`: deterministic variation of lobe positions and radii.

Every world cell derives its transform and shape values from its coordinate and
`world_seed`. A cloud does not change scale, proportions, or noise offset while
the player moves.

Both the volumetric and billboard shaders use the same fixed-cost multi-lobe
shape function. Four to five overlapping ellipsoidal lobes replace the current
single sphere mask. Per-instance `shape_offset`, `lobe_spread`, and
`lobe_variation` change the silhouette while preserving the same identity
through Billboard -> Cheap Volume -> Full Volume transitions.

### LOD and recycling

- `full_volume_distance`;
- `cheap_volume_distance`;
- `billboard_transition_start`;
- `billboard_transition_end`;
- `recycle_fade_duration`;
- `updates_per_frame`.

Distances are evaluated from the cloud surface, preserving the existing
large-scale correction in `CloudLodController`.

## Stable Infinite Streaming

Cloud occupancy is deterministic in world coordinates. The manager evaluates
cells within the profile's ellipsoidal coverage region and keeps already active
cells until they leave the outer coverage boundary.

The occupancy threshold is derived from `target_cloud_count` and the number of
candidate cells in the configured coverage volume. It stays constant until the
profile changes, so crossing a player cell boundary cannot reclassify a nearby
world cell.

New clouds:

1. enter at the distant outer boundary;
2. fade in as procedural billboards;
3. retain their world transform while the player approaches;
4. transition Billboard -> Cheap Volume -> Full Volume through the existing LOD
   controller;
5. fade out only after leaving the outer coverage boundary.

When `pool_capacity` is reached, pending distant cells wait for a free slot.
The manager must never remove a nearby active cloud merely to display a newly
entered distant cell.

Initial population is stratified across distance bands so the first frame does
not contain only near or only far clouds. Runtime streaming remains based on
stable world occupancy, not camera direction.

Recommended initial High values:

- coverage radius: 1800 m;
- coverage height: 350 m;
- target count: 100;
- pool capacity: 120;
- scale minimum: `(100, 50, 140)`;
- scale maximum: `(320, 180, 480)`;
- full-volume region: approximately 250–350 m;
- recycle fade: 0.8–1.2 seconds.

These are starting values, not hard-coded limits.

## Runtime Tuning Panel

Create a debug-only `CloudTuningPanel`, toggled with `F10`.

Behavior:

- the game continues running;
- the mouse cursor is released while the panel is open;
- camera input ignores all mouse buttons and mouse motion while the panel is
  open;
- closing the panel restores the previous mouse mode;
- controls are grouped into Distribution, Size & Shape, LOD, and Performance;
- every control applies immediately to the active `CloudManager`;
- values show numeric entry as well as sliders where appropriate.

The panel width is approximately 620 pixels and uses scrolling for overflow.
Only the three profile export groups are displayed; inherited Resource,
RefCounted, script, and other engine properties are hidden. Numeric properties
without an explicit range, including `world_seed`, use a numeric field without
a slider.

The panel displays:

- Active;
- Full Volume;
- Cheap Volume;
- Billboard;
- Pending;
- Pool Capacity.

Actions:

- `Regenerate`: fade and rebuild the deterministic layout with current values;
- `Save Project`: save the live resource to its `res://` path;
- `Reload Saved`: discard unsaved runtime edits and reload the project resource;
- `Reset`: restore defined default values without saving automatically.

`Save Project` is available only in development/editor runs where `res://` is
writable. It uses `ResourceSaver.save()` and displays success or the exact
failure code. The panel is disabled in production/mobile exports, while the
saved `.tres` remains active in those builds.

## Inspector Workflow

All profile properties remain editable through the normal Godot Inspector.
The runtime panel edits the same resource interface rather than maintaining a
second dictionary of settings. This prevents Inspector, runtime, and exported
build values from diverging.

## Cloud Exclusion Volumes

Create a reusable `CloudExclusionVolume` scene:

- root: `Area3D`;
- child: `CollisionShape3D`;
- supported shapes: `BoxShape3D` and `SphereShape3D`;
- automatically joins group `cloud_exclusion`;
- exported `clearance` expands the effective exclusion region;
- editor-visible volume/gizmo identifies the protected area.

The user places one or more volumes around each island. Volumes approximate the
terrain with cheap shapes; island render meshes are never queried.

Before reserving a cloud cell, `CloudManager` tests the prospective cloud world
bounds against all nodes in `cloud_exclusion`. A rejected cell remains empty.
The test includes:

- the exclusion shape;
- its global transform and scale;
- its `clearance`;
- the prospective cloud's estimated world radius.

Only physical overlap with the padded terrain volume is forbidden. Clouds may
exist above an island when their bounds do not intersect the exclusion volume.

## Performance and Failure Handling

- Exclusion volumes are cached and refreshed only when the group changes or a
  tuning regeneration is requested.
- Cell reconciliation is distributed across frames using
  `updates_per_frame`.
- Shared materials are never duplicated or mutated for per-cloud values;
  instance shader parameters carry fade and shape offsets.
- Invalid profile values are clamped before use.
- A missing profile falls back to safe in-code defaults and emits one warning.
- A failed project save leaves the current runtime values active and reports
  the error without overwriting the last saved resource.

## Validation

Automated/static checks:

- profile fields exist and invalid ranges are clamped;
- deterministic cells return stable transform/shape values;
- active near cells survive player-cell changes;
- pool size never exceeds capacity;
- new cells cannot evict nearby active cells;
- exclusion box/sphere tests include cloud radius and clearance;
- F1-F4 and F7 bindings remain unchanged; F10 owns only the tuning panel;
- existing cloud LOD and shader regression tests remain green.

Manual Godot verification:

1. Open the panel with F10 during debug flight.
2. Change radius, count, size, aspect, seed, and LOD values live.
3. Click and drag multiple sliders; confirm the cursor stays visible and the
   camera does not rotate.
4. Fly more than one coverage radius and rotate the camera 360 degrees.
5. Confirm distant clouds appear as billboards and retain their identity while
   approaching.
6. Confirm nearby clouds vary in size, proportions, and multi-lobe silhouette.
7. Place box and sphere exclusion volumes around an island and confirm clouds
   avoid padded terrain but remain possible above it.
8. Save, restart the project, and confirm the saved values reload.
9. Confirm Low/Medium/High graphics switching does not overwrite the tuned
   profile during this implementation phase.
