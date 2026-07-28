# Cloud World Pool and Debug Flight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add F7 no-clip player flight and replace the moving cloud shell with a stable, quality-scaled 3D cloud pool around the player.

**Architecture:** Existing cloud scenes, materials, LOD, and day/night code remain authoritative. `CloudManager` maps deterministic world cells to a fixed pool of clouds; released distant cells fade out, move, and fade into new cells without moving the manager root. Player debug flight bypasses normal physics through an early, isolated branch.

**Tech Stack:** Godot 4.7.1, GDScript, Godot spatial shaders, PowerShell static regression tests.

## Global Constraints

- Do not launch Godot from the terminal because the current Steam tools executable has produced native access violations.
- Do not overwrite user-edited `cloud.tscn`, cloud noise/material resources, `environment_system.tscn`, or unrelated dirty files.
- Preserve F1-F3 quality controls and F4 camera switching.
- Reuse the existing `cloud_scene`, `CloudLodController`, day/night integration, and LOD shaders.
- The cloud manager must provide 360-degree coverage and must not follow camera direction.

---

### Task 1: F7 Debug Flight

**Files:**
- Create: `.codex/tests/player-debug-flight.tests.ps1`
- Modify: `project.godot`
- Modify: `common/autoload/game_constants.gd`
- Modify: `entities/player/player.gd`

**Interfaces:**
- Produces: input action `debug_flight_toggle`; player methods `_toggle_debug_flight()` and `_debug_flight_physics(delta: float)`.

- [ ] **Step 1: Write the failing static regression test**

Check that F7 is assigned only to `debug_flight_toggle`, F4 remains assigned to
`toggle_camera`, and `Player` contains the isolated early physics branch,
camera-relative movement, vertical controls, boost, and collision restoration.

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/player-debug-flight.tests.ps1
```

Expected: FAIL because `debug_flight_toggle` is absent.

- [ ] **Step 3: Add the input and constant**

Add `debug_flight_toggle` with physical keycode `4194338` (`F7`) to
`project.godot`. Add:

```gdscript
const INPUT_DEBUG_FLIGHT_TOGGLE = "debug_flight_toggle"
```

to `game_constants.gd`.

- [ ] **Step 4: Implement isolated no-clip flight**

Add exported settings under `Debug & Unlocks`:

```gdscript
@export var debug_flight_available := true
@export_range(1.0, 200.0, 1.0) var debug_flight_speed := 30.0
@export_range(1.0, 10.0, 0.5) var debug_flight_boost := 3.0
```

Handle F7 in `_unhandled_input`. At the beginning of `_physics_process`, call
`_debug_flight_physics(delta)` and return when active. Build movement from the
active camera basis, `WASD`, `jump`, `crouch`, and `run`. Move by
`global_position += direction * speed * delta`, bypassing collision and gravity.
Restore the collision shape and zero velocity when flight is disabled.

- [ ] **Step 5: Run the regression test**

Expected: PASS.

- [ ] **Step 6: Commit only Task 1 files**

```powershell
git add -- .codex/tests/player-debug-flight.tests.ps1 project.godot common/autoload/game_constants.gd entities/player/player.gd
git commit -m "feat: add debug player flight"
```

### Task 2: Deterministic Cloud Cell Layout

**Files:**
- Create: `levels/components/CloudManager/cloud_cell_layout.gd`
- Create: `.codex/tests/cloud-world-pool.tests.ps1`
- Modify: `levels/components/CloudManager/CloudManager.gd`

**Interfaces:**
- Produces: `CloudCellLayout.world_to_cell(position: Vector3, cell_size: float) -> Vector3i`.
- Produces: `CloudCellLayout.desired_cells(center: Vector3i, horizontal_radius: int, vertical_radius: int, density: float, world_seed: int, limit: int) -> Array[Vector3i]`.
- Produces: `CloudCellLayout.cell_transform(cell: Vector3i, cell_size: float, world_seed: int, scale_min: Vector3, scale_max: Vector3) -> Transform3D`.

- [ ] **Step 1: Write the failing static pool test**

Verify the helper exists, uses deterministic cell hashing, clamps invalid
settings, returns no more than `limit`, and that `CloudManager` references the
helper without assigning its own runtime global position or rotation.

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-world-pool.tests.ps1
```

Expected: FAIL because `cloud_cell_layout.gd` is absent.

- [ ] **Step 3: Implement the layout helper**

Enumerate cells inside an ellipsoid centered on the player cell. Use a stable
hash of `x:y:z:world_seed` to select cells by `density`, create a stable offset
inside each cell, yaw, and scale, then sort candidates by squared cell distance
and truncate to `limit`.

- [ ] **Step 4: Add runtime pool configuration to CloudManager**

Add exports:

```gdscript
@export var world_seed := 1337
@export_range(10.0, 500.0, 1.0) var cell_size := 90.0
@export_range(1, 12, 1) var horizontal_cell_radius := 4
@export_range(0, 6, 1) var vertical_cell_radius := 1
@export_range(0.05, 1.0, 0.05) var cell_density := 0.65
@export_range(1, 16, 1) var pool_updates_per_frame := 2
```

At runtime, reuse existing child cloud instances first, instantiate only the
missing amount up to `cloud_count`, and keep extra instances inactive. Do not
delete or regenerate editor-authored children in editor mode.

- [ ] **Step 5: Replace root following with cell reconciliation**

Resolve the player, calculate its current cell, and rebuild the desired-cell set
only when that cell or quality settings change. Keep clouds assigned to cells
that remain desired. Queue released clouds for new cells, processing at most
`pool_updates_per_frame` relocations per frame. Never call `rotate_y()` or
assign the manager runtime `global_position`.

- [ ] **Step 6: Run the pool test**

Expected: PASS.

- [ ] **Step 7: Commit only Task 2 files**

```powershell
git add -- .codex/tests/cloud-world-pool.tests.ps1 levels/components/CloudManager/cloud_cell_layout.gd levels/components/CloudManager/CloudManager.gd
git commit -m "feat: anchor clouds to world cell pool"
```

### Task 3: Pool Fade and Quality Scaling

**Files:**
- Modify: `.codex/tests/cloud-world-pool.tests.ps1`
- Modify: `levels/components/CloudManager/cloud_lod_controller.gd`
- Modify: `levels/components/CloudManager/CloudManager.gd`
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader`
- Modify: `assets/shaders/Cloud_impostor/cloud_impostor.gdshader`
- Modify: `common/autoload/graphics_manager.gd`

**Interfaces:**
- Produces: `CloudLodController.set_pool_fade(value: float) -> void`.
- Consumes: `GraphicsManager.quality_changed(settings: Dictionary)`.

- [ ] **Step 1: Extend the failing pool test**

Require `instance uniform float pool_fade`, `set_pool_fade`, fade-out/move/fade-in
states, and pool radius/density values in all three graphics presets.

- [ ] **Step 2: Run the test and verify it fails**

Expected: FAIL because pool fade and pool quality settings are absent.

- [ ] **Step 3: Add per-instance pool fade**

Add `pool_fade` to both cloud shaders and combine it with their final opacity
and discard threshold. Add `set_pool_fade(value)` to `CloudLodController`,
setting the instance shader parameter on every volume mesh and the impostor.
Do not mutate shared materials.

- [ ] **Step 4: Add relocation phases**

Track relocation jobs per cloud:

```gdscript
enum RecyclePhase { FADING_OUT, FADING_IN }
```

Fade from `1.0` to `0.0`, apply the deterministic target transform only at zero,
then fade back to `1.0`. New work is limited by `pool_updates_per_frame`, and a
new player cell request supersedes stale queued target cells.

- [ ] **Step 5: Add quality preset values**

Add settings to each preset:

```gdscript
"cloud_pool_horizontal_radius": 3 / 4 / 5,
"cloud_pool_vertical_radius": 1 / 1 / 2,
"cloud_pool_density": 0.45 / 0.65 / 0.8,
"cloud_pool_updates_per_frame": 1 / 2 / 3,
```

Connect `CloudManager` once to `GraphicsManager.quality_changed`, apply the
current preset at startup, and request reconciliation after changes.

- [ ] **Step 6: Run cloud tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-world-pool.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-procedural-lod.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-lod-shaders.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-editor-regression.tests.ps1
```

Expected: all PASS.

- [ ] **Step 7: Commit only Task 3 files**

```powershell
git add -- .codex/tests/cloud-world-pool.tests.ps1 levels/components/CloudManager/cloud_lod_controller.gd levels/components/CloudManager/CloudManager.gd assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader assets/shaders/Cloud_impostor/cloud_impostor.gdshader common/autoload/graphics_manager.gd
git commit -m "feat: fade and scale recycled cloud cells"
```

### Task 4: Verification and Manual Handoff

**Files:**
- Modify only if a regression is found in files already owned by Tasks 1-3.

**Interfaces:**
- Consumes: all Task 1-3 outputs.

- [ ] **Step 1: Run whitespace and static checks**

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .codex/tests/player-debug-flight.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-world-pool.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-procedural-lod.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-lod-shaders.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-editor-regression.tests.ps1
```

- [ ] **Step 2: Confirm change isolation**

Use `git status --short` and `git diff --name-only HEAD^` to confirm unrelated
dirty files and user-edited cloud scene/resources remain untouched.

- [ ] **Step 3: Ask for manual Godot verification**

The user verifies F7 toggle, WASD/Space/Ctrl/Shift flight, stationary cloud
shapes, 360-degree coverage, recycling during long travel, transitions, and
F1/F2/F3 presets. Do not run the Godot executable from the terminal.

- [ ] **Step 4: Fix only confirmed regressions and rerun checks**

Keep adjustments limited to Tasks 1-3 files and repeat Step 1 after each fix.
