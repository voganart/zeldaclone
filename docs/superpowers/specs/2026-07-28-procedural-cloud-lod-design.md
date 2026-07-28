# Procedural Cloud LOD Design

## Goal

Build an infinite, fully three-dimensional cloud field for free flight in any
direction. Clouds must remain visible around the camera, support flying through
near clouds, extend into the distance, follow the existing day/night palette,
and scale down to mobile hardware.

The final LOD system does not depend on baked impostor atlases.

## Rendering Architecture

Each logical cloud owns one stable seed, world-space position, scale, and noise
phase. Every LOD reads the same data so cloud motion, shape, and day/night color
remain consistent while switching representations.

### LOD 0: Full Volume

- Box-bounded raymarched volume.
- Used when the camera can enter or pass close to the cloud.
- Full shape erosion, detail noise, lighting, and the highest step count allowed
  by the selected graphics quality.

### LOD 1: Cheap Volume

- Uses the same mesh, seed, noise coordinates, and material model as LOD 0.
- Reduces raymarch steps and secondary detail.
- Reduces or disables expensive shadow samples.
- Step count changes before any representation switch, so the cloud silhouette
  stays stable.

### LOD 2: Procedural Volumetric Billboard

- Camera-facing quad with a short raymarch through the same procedural density
  field.
- Does not sample a baked color atlas.
- Uses the cloud seed, projected ellipsoid scale, noise phase, and shared
  day/night lighting.
- Intended for distant clouds where limited depth and parallax are not
  noticeable.

## Transitions

LOD distances are measured from the estimated cloud surface, not its origin.
This prevents large clouds from switching while the camera is still close to
their visible edge.

LOD ranges overlap. During an overlap, both representations use complementary
screen-space dither: pixels removed from one LOD are filled by the other. The
transition width, distances, and update interval are inspector settings.
Hysteresis prevents rapid switching near a boundary.

The built-in GeometryInstance3D alpha fade is not the primary transition
mechanism because it is not supported as a smooth fade by Godot's Mobile and
Compatibility renderers.

## Day/Night Integration

`DayNightCycle` remains the source of cloud lighting:

- light color;
- shadow color;
- active sun or moon direction;
- overall light intensity;
- shared animation time.

These values are supplied to both volume and billboard shaders through shared
shader parameters. The billboard computes its color at runtime, so dawn, day,
sunset, and night do not require separate textures or atlases.

## Infinite 3D Distribution

Clouds are pooled in world-space cells surrounding the player in all
directions. Camera rotation never spawns or deletes clouds. Normal frustum
culling handles nodes outside the view.

When the player crosses a cell boundary, only cells beyond the active radius
are recycled to the opposite side. A buffer of outer cells stays beyond the
visible distance so turning the camera does not reveal gaps. Recycling is
hidden with a distance fade and hysteresis; a cloud is never teleported while
visibly near the camera.

Near volume clouds remain individual pooled instances. Distant procedural
billboards can later be grouped into spatial MultiMesh chunks after the visual
transition is approved.

## Culling Safety

Volume and billboard bounds must contain their complete visible silhouette.
Billboards receive a conservative `custom_aabb` or `extra_cull_margin` so they
do not disappear at the edge of the screen. The cloud pool is independent of
the camera frustum and has a configurable off-screen cell buffer.

## Quality Profiles

All values are data-driven rather than hardcoded.

- High: full near volume, cheap middle volume, procedural billboard at distance.
- Medium: fewer steps and an earlier billboard transition.
- Low/mobile: very small near-volume radius, minimum stable step count, distant
  billboards, reduced cloud density and view radius.

The first implementation preserves the current cloud count and exposes tuning
controls. MultiMesh batching and density scaling are a later optimization
checkpoint based on profiler results.

## Editor and Debug Workflow

The cloud scene exposes a preview mode:

- Auto;
- Force Full Volume;
- Force Cheap Volume;
- Force Billboard;
- Force Transition.

Optional debug colors identify each active LOD. The manager exposes LOD
distances, transition widths, cell size, cell radius, off-screen buffer, and
quality-dependent step counts. The existing atlas baker remains available
during development but is not used by the final procedural LOD path.

## Validation

- Rotate the camera through 360 degrees without visible holes or edge popping.
- Fly forward, backward, vertically, and diagonally through multiple cell
  boundaries without visible teleporting.
- Pause inside each transition band and verify stable complementary dithering.
- Scrub the full day/night cycle and compare volume and billboard colors.
- Profile GPU frame time and transparent overdraw for High, Medium, and Mobile.
- Verify the same cloud seed does not visibly change shape during an LOD switch.

## Implementation Stages

1. Shared cloud data, adaptive volume quality, procedural billboard rendering,
   transitions, editor preview modes, day/night parameters, and safe bounds.
2. The cell-based infinite pool and off-screen buffer after the LOD transition
   is visually approved.
3. MultiMesh batching and quality-dependent cloud density after profiling the
   completed pool.

Each stage has a separate visual checkpoint so distribution or batching cannot
hide problems in the underlying LOD transition.
