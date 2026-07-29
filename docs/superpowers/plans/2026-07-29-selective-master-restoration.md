# Selective Master Restoration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the Phantom Camera lifecycle fix, enhanced F7 debug flight, and player-independent animated cloud noise to `master` without restoring the discarded cloud streaming stack.

**Architecture:** Port the Phantom Camera and flight changes surgically instead of cherry-picking aggregate commits. Keep the current simple cloud shader and remove only its dependency on the moving CloudManager transform while retaining time-based noise motion.

**Tech Stack:** Godot 4.7.1, GDScript, Godot spatial shader language, PowerShell static regression tests.

## Global Constraints

- Do not restore cloud streaming, distant cloud spawning, impostor LOD, weather management, or cloud tuning files.
- Revert only the uncommitted alpha override in `assets/_master/x-ray_mat.tres`; keep the resource itself.
- Keep F4 camera switching unchanged.
- Debug flight uses F7, WASD, Space/Ctrl, Shift, and mouse wheel.
- Mouse-wheel speed control works only while debug flight is active.
- Base flight speed is clamped to `5..200` and changes in steps of `5`.
- Preserve the current simple volumetric cloud scene and material.

---

### Task 1: Remove Accidental X-Ray Override

**Files:**
- Modify: `assets/_master/x-ray_mat.tres`

**Interfaces:**
- Produces: the exact `master` version of the x-ray material with no local alpha override.

- [ ] **Step 1: Inspect the isolated diff**

Run:

```powershell
git diff -- assets/_master/x-ray_mat.tres
```

Expected: exactly one added `albedo_color` line.

- [ ] **Step 2: Remove only the accidental line**

Delete:

```text
albedo_color = Color(1, 1, 1, 0.5375001)
```

Do not delete or otherwise modify the material.

- [ ] **Step 3: Verify the file matches HEAD**

Run:

```powershell
git diff --exit-code -- assets/_master/x-ray_mat.tres
```

Expected: PASS with no output.

---

### Task 2: Restore Phantom Camera Autoload Lifecycle

**Files:**
- Create: `.codex/tests/phantom-camera-lifecycle.tests.ps1`
- Modify: `addons/phantom_camera/plugin.gd`

**Interfaces:**
- Produces: `PhantomCameraManager` ownership only in `_enable_plugin()` and `_disable_plugin()`.

- [ ] **Step 1: Write the failing lifecycle regression**

Create a PowerShell test that extracts the four plugin lifecycle functions and
asserts:

```powershell
$enable.Contains('add_autoload_singleton(PHANTOM_CAMERA_MANAGER')
$disable.Contains('remove_autoload_singleton(PHANTOM_CAMERA_MANAGER)')
-not $enter.Contains('add_autoload_singleton(PHANTOM_CAMERA_MANAGER')
-not $exit.Contains('remove_autoload_singleton(PHANTOM_CAMERA_MANAGER)')
```

The helper must slice each function from its declaration to the next top-level
`func` declaration so assertions cannot pass because of calls in another
function.

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/phantom-camera-lifecycle.tests.ps1
```

Expected: FAIL because `_enter_tree()` adds and `_exit_tree()` removes the
autoload.

- [ ] **Step 3: Apply the minimal lifecycle fix**

Remove this line from `_enter_tree()`:

```gdscript
add_autoload_singleton(PHANTOM_CAMERA_MANAGER, "res://addons/phantom_camera/scripts/managers/phantom_camera_manager.gd")
```

Remove the active and commented `remove_autoload_singleton` lines from
`_exit_tree()` and add:

```gdscript
# Autoload lifetime belongs to _enable_plugin() / _disable_plugin().
# Removing it here breaks running scenes when the editor/plugin tree reloads.
```

- [ ] **Step 4: Run the lifecycle regression**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/phantom-camera-lifecycle.tests.ps1
```

Expected: PASS.

- [ ] **Step 5: Commit the isolated Phantom Camera fix**

```powershell
git add -- .codex/tests/phantom-camera-lifecycle.tests.ps1 addons/phantom_camera/plugin.gd
git commit -m "fix: preserve phantom camera autoload on editor reload"
```

---

### Task 3: Restore F7 Flight with Active-Only Wheel Speed

**Files:**
- Create: `.codex/tests/player-debug-flight.tests.ps1`
- Modify: `common/autoload/game_constants.gd`
- Modify: `entities/player/player.gd`
- Modify: `project.godot`

**Interfaces:**
- Produces: `GameConstants.INPUT_DEBUG_FLIGHT_TOGGLE`.
- Produces: `Player._toggle_debug_flight() -> void`.
- Produces: `Player._adjust_debug_flight_speed(direction: float) -> void`.
- Produces: `Player._debug_flight_physics(delta: float) -> void`.

- [ ] **Step 1: Restore and extend the failing flight regression**

Start from `.codex/tests/player-debug-flight.tests.ps1` in commit `15be692`.
Retain its F4/F7 and flight-contract assertions, then additionally require:

```powershell
'debug_flight_active'
'event is InputEventMouseButton'
'event.button_index == MOUSE_BUTTON_WHEEL_UP'
'event.button_index == MOUSE_BUTTON_WHEEL_DOWN'
'func _adjust_debug_flight_speed(direction: float)'
'debug_flight_speed_step'
'clampf(debug_flight_speed + direction * debug_flight_speed_step, 5.0, 200.0)'
'get_viewport().set_input_as_handled()'
```

The test must also verify that the mouse-wheel branch is guarded by
`debug_flight_active`.

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/player-debug-flight.tests.ps1
```

Expected: FAIL because F7 flight and wheel speed control are absent.

- [ ] **Step 3: Add the input action and constants**

Add `debug_flight_toggle` on physical keycode `4194338` (`F7`) to
`project.godot`.

Add to `common/autoload/game_constants.gd`:

```gdscript
const INPUT_CROUCH = "crouch"
const INPUT_DEBUG_FLIGHT_TOGGLE = "debug_flight_toggle"
```

- [ ] **Step 4: Add flight state and exported tuning**

Add under the player's debug exports:

```gdscript
@export var debug_flight_available: bool = true
@export_range(5.0, 200.0, 5.0) var debug_flight_speed: float = 30.0
@export_range(1.0, 10.0, 0.5) var debug_flight_boost: float = 3.0
@export_range(1.0, 25.0, 1.0) var debug_flight_speed_step: float = 5.0
```

Add:

```gdscript
var debug_flight_active: bool = false
```

- [ ] **Step 5: Add F7 and wheel input handling**

Implement `_unhandled_input(event)` so it:

1. Checks pressed wheel events only inside `if debug_flight_active`.
2. Calls `_adjust_debug_flight_speed(1.0)` for wheel up and `-1.0` for wheel
   down.
3. Marks handled wheel events and returns.
4. Toggles flight on F7 when `debug_flight_available` is true.

Implement:

```gdscript
func _adjust_debug_flight_speed(direction: float) -> void:
	debug_flight_speed = clampf(
		debug_flight_speed + direction * debug_flight_speed_step,
		5.0,
		200.0
	)
	print("Debug flight speed: ", debug_flight_speed)
```

- [ ] **Step 6: Restore isolated no-clip physics**

At the beginning of `_physics_process(delta)`, call
`_debug_flight_physics(delta)` and return when active.

Restore `_toggle_debug_flight()` and `_debug_flight_physics(delta)` from commit
`15be692`. The movement must remain camera-relative, use Space/Ctrl vertically,
multiply speed while Shift/run is held, bypass collision, and update the player
global shader parameter.

- [ ] **Step 7: Run the flight regression**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/player-debug-flight.tests.ps1
```

Expected: PASS.

- [ ] **Step 8: Commit the isolated flight feature**

```powershell
git add -- .codex/tests/player-debug-flight.tests.ps1 common/autoload/game_constants.gd entities/player/player.gd project.godot
git commit -m "feat: restore debug flight with wheel speed"
```

---

### Task 4: Stabilize and Animate Simple Cloud Noise

**Files:**
- Create: `.codex/tests/cloud-stable-noise.tests.ps1`
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader`

**Interfaces:**
- Consumes: existing shader uniforms `move_speed` and `erosion_offset_speed`.
- Produces: time-animated erosion and detail noise with no CloudManager/world-center coordinate dependency.

- [ ] **Step 1: Write the failing shader regression**

Read the shader as raw text and require:

```powershell
-not $shader.Contains('v_world_pos_center')
$shader.Contains('TIME * move_speed * erosion_offset_speed')
$shader.Contains('TIME * move_speed')
```

Also reject tokens for discarded systems:

```powershell
'weather_cloud_offset'
'weather_cloud_evolution'
'lod_is_impostor'
'pool_fade'
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-stable-noise.tests.ps1
```

Expected: FAIL because the erosion coordinates still include
`v_world_pos_center`.

- [ ] **Step 3: Remove the moving-root dependency**

Remove:

```gdshader
varying vec3 v_world_pos_center;
v_world_pos_center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
```

Change erosion coordinates to:

```gdshader
vec3 erosion_uv = (p * v_obj_scale * erosion_scale)
	+ (TIME * move_speed * erosion_offset_speed);
```

Keep detail coordinates time-driven:

```gdshader
vec3 detail_uv = p * v_obj_scale * cloud_scale * current_scale_mod
	+ (TIME * move_speed);
```

- [ ] **Step 4: Run the shader regression**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-stable-noise.tests.ps1
```

Expected: PASS.

- [ ] **Step 5: Commit the isolated shader fix**

```powershell
git add -- .codex/tests/cloud-stable-noise.tests.ps1 assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader
git commit -m "fix: decouple cloud noise from player movement"
```

---

### Task 5: Full Verification and Scope Audit

**Files:**
- Modify only files already owned by Tasks 2-4 if a regression is found.

**Interfaces:**
- Consumes: all restored features.
- Produces: verified clean worktree on `master`.

- [ ] **Step 1: Run all focused regressions**

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/phantom-camera-lifecycle.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/player-debug-flight.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-stable-noise.tests.ps1
```

Expected: all PASS.

- [ ] **Step 2: Run repository whitespace validation**

```powershell
git diff --check
```

Expected: PASS with no output.

- [ ] **Step 3: Load the project headlessly**

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path 'C:\GodotProjects\zeldaclone' --editor --quit-after 2
```

Expected: exit code `0`. Report pre-existing certificate, `user://`, editor
settings, or missing-UID warnings separately; remove only `.uid` files created
by this verification run.

- [ ] **Step 4: Audit final scope**

Run:

```powershell
git status --short --branch
git diff --name-status c95d191..HEAD
git log --oneline --max-count=6
```

Expected functional paths are limited to:

```text
.codex/tests/phantom-camera-lifecycle.tests.ps1
.codex/tests/player-debug-flight.tests.ps1
.codex/tests/cloud-stable-noise.tests.ps1
addons/phantom_camera/plugin.gd
common/autoload/game_constants.gd
entities/player/player.gd
project.godot
assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader
```

No discarded cloud streaming, weather, impostor, or tuning subsystem file may
appear.

- [ ] **Step 5: Request manual Godot verification**

The user verifies:

1. Phantom Camera works after editor plugin/tree reload.
2. F7 enables flight; F7 disables it and restores collision.
3. WASD, Space/Ctrl, Shift work in flight.
4. Wheel changes speed only in flight and does not zoom the camera then.
5. Clouds keep animating like wind and do not reshape in response to player
   movement.
