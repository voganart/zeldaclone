# Selective Restoration to Master

## Goal

Restore three proven changes from `codex/cloud-lod` to `master` without
restoring cloud streaming, distant cloud spawning, impostor LOD, weather
management, or cloud tuning systems:

- Phantom Camera autoload lifecycle fix;
- F7 debug flight with mouse-wheel speed control;
- cloud noise animation that does not react to player-driven CloudManager
  movement.

The unrelated uncommitted alpha edit in `assets/_master/x-ray_mat.tres` will be
reverted to the current `master` version.

## Selected Approach

Port only the required lines and the existing debug-flight test contract.
Do not cherry-pick the original aggregate commits because they include unrelated
cloud scenes, editor compatibility changes, and streaming dependencies.

## Phantom Camera

`PhantomCameraManager` is created and removed only by `_enable_plugin()` and
`_disable_plugin()`.

`_enter_tree()` must not add the autoload again, and `_exit_tree()` must not
remove it. This prevents editor/plugin tree reloads from deleting the manager
while a scene is running.

## Debug Flight

Restore the isolated flight branch in `entities/player/player.gd`:

- `F7`: toggle flight;
- `WASD`: camera-relative movement;
- `Space` / `Ctrl`: world up/down;
- `Shift`: temporary speed boost;
- mouse wheel up/down: increase/decrease the base flight speed.

Flight bypasses gravity, collision, combat movement, and fall/respawn logic.
Disabling flight restores collision and clears velocity.

Mouse-wheel speed changes are processed only while flight is active. The event
is marked handled so camera zoom or other gameplay controls do not react at the
same time. Base speed is clamped to `5..200`, changes in steps of `5`, and the
new value is printed to the output.

## Stable Animated Cloud Noise

Keep the current simple volumetric cloud system and its existing
`TIME * move_speed` animation.

Remove the CloudManager/world-position contribution from the erosion noise
coordinates. The erosion and detail layers continue scrolling through time, but
player-driven movement of the CloudManager no longer changes the sampled noise
field or makes cloud shapes swim with the player.

No global weather uniforms, weather manager, distant cloud pool, procedural
impostor, or new LOD controller will be restored.

## Validation

- A static Phantom Camera regression verifies autoload ownership.
- The restored flight regression verifies F7 and all flight controls.
- The flight regression additionally verifies wheel-only-while-active speed
  control, clamping, and event handling.
- A shader regression verifies that erosion coordinates do not contain the
  cloud world position and that both noise layers retain time-based motion.
- `git diff --check` passes.
- Godot headless loads the project; environment-only warnings are reported
  separately.
- The final diff contains no cloud streaming, weather, impostor, or tuning
  subsystem files.
