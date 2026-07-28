# World-Anchored Cloud Pool and Debug Flight

## Goal

Make the existing procedural clouds suitable for unlimited flight:

- cloud noise must not slide or reshape when the player moves;
- clouds must remain available in every viewing direction;
- distant clouds must be reused without obvious popping;
- existing cloud scenes, shaders, day/night integration, and LOD controller stay in use;
- the player gets an isolated debug no-clip flight mode for testing.

## Root Cause

`CloudManager` currently moves and rotates its whole root around the player in
`Skybox` mode. The cloud shaders derive procedural coordinates partly from each
cloud's world position. Moving the root therefore moves the noise field too,
which makes cloud shapes appear to swim with the player.

The existing `Fly Through` mode leaves clouds in world space, but teleports them
immediately after a radius check. This can create holes and visible popping.

## Selected Design

### Stable 3D pool

`CloudManager` owns a fixed-size pool of the existing `cloud_scene` instances.
Cloud transforms stay in world space. The manager root no longer follows or
rotates with the player at runtime.

The space around the player is divided into coarse 3D cells. A deterministic
hash of a cell coordinate decides:

- whether the cell contains a cloud;
- the cloud offset within the cell;
- rotation and scale.

When the player crosses into another cell, only cells that left the outer
radius are released and reused for newly entered cells. Existing nearby cells
do not move or change, so their procedural noise remains stable.

Coverage is spherical/ellipsoidal and includes a buffer outside the visible
camera region. It is not tied to camera direction, so rotating the camera cannot
cause a sudden empty edge.

### Recycling transition

Recycled clouds use two short phases:

1. fade out while still at the old distant cell;
2. move to the new cell and fade in.

The transition happens beyond the normal LOD transition, where the procedural
billboard is active. Pool updates are spread across frames to avoid a CPU/GPU
spike when crossing a cell boundary.

If the existing cloud material does not expose a safe per-instance fade, the
first implementation hides only fully distant impostors during relocation and
uses distance dithering already provided by the LOD shader. No shared material
resource is mutated.

### Quality integration

The manager exposes pool parameters, while `GraphicsManager` applies presets:

- Low: fewer active cells/clouds and shorter coverage;
- Medium: balanced pool;
- High: larger buffer and farther coverage.

Existing LOD distances and shader raymarch step presets remain authoritative.

### Debug flight

The player receives a debug-only mode:

- `F7`: toggle;
- `WASD`: camera-relative horizontal/free movement;
- `Space` / `Ctrl`: world up/down;
- `Shift`: speed boost.

While enabled:

- gravity, combat movement, fall/respawn checks, and collision are bypassed;
- the normal player state machine is not modified;
- the camera continues following the real player node.

When disabled, collision and normal physics resume with zero velocity. The
feature is exported under the existing `Debug & Unlocks` section and can be
disabled for release builds without touching gameplay controls.

## Preserved Work

The implementation reuses:

- `cloud.tscn`;
- current volumetric and procedural billboard shaders;
- `CloudLodController`;
- day/night color updates;
- current hand-tuned noise and environment resources.

Generated scene instances and user-edited cloud resources are not overwritten.

## Validation

Static checks:

- Input Map contains `debug_flight_toggle` on F7 and keeps F1-F4 unchanged;
- manager root does not follow or rotate with the player;
- deterministic cell generation returns stable transforms;
- pool never grows above its configured maximum;
- current cloud LOD regression tests remain green.

Manual Godot check:

1. Enable flight with F7.
2. Fly through and around the cloud layer in all directions.
3. Stop moving and confirm nearby cloud shapes remain still.
4. Rotate the camera 360 degrees and confirm there are no hard screen-edge gaps.
5. Fly far enough to recycle several cell layers and watch for popping/stutter.
6. Compare F1/F2/F3 quality presets and LOD transitions.
