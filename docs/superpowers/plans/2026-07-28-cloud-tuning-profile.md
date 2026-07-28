# Cloud Tuning Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build stable long-range cloud streaming with live project-persistent tuning and island exclusion volumes.

**Architecture:** A `CloudTuningProfile` resource becomes the single source of cloud distribution, shape, LOD, fade, and performance values. `CloudManager` streams deterministic world cells without evicting nearby clouds, `CloudExclusionVolume` nodes reject terrain intersections, and a debug-only F10 panel edits and saves the same project resource.

**Tech Stack:** Godot 4.7.1, typed GDScript, spatial shaders, Godot Resources/UI, PowerShell regression checks.

## Global Constraints

- Do not launch Godot from the terminal; the Steam tools executable previously produced native access violations.
- Preserve F1-F4 graphics/camera controls and F7 debug flight.
- Do not overwrite user-edited `Level_01.tscn`, cloud scene settings, or unrelated dirty resources.
- Existing cloud shaders, day/night integration, procedural billboard, and LOD policy remain in use.
- Runtime project saving is development-only; release/mobile builds load the saved `.tres` but do not show the panel.
- Nearby active clouds cannot be evicted to make room for newly entered distant cells.

---

### Task 1: Project Cloud Tuning Resource

**Files:**
- Create: `levels/components/CloudManager/cloud_tuning_profile.gd`
- Create: `levels/components/CloudManager/cloud_tuning_profile.tres`
- Create: `.codex/tests/cloud-tuning-profile.tests.ps1`
- Modify: `levels/components/CloudManager/CloudManager.gd`
- Modify: `common/autoload/graphics_manager.gd`

**Interfaces:**
- Produces: `class_name CloudTuningProfile extends Resource`.
- Produces: `func sanitize() -> void`.
- Produces: `func copy_values_from(source: CloudTuningProfile) -> void`.
- Produces: `CloudManager.apply_tuning_profile(profile: CloudTuningProfile) -> void`.

- [ ] **Step 1: Write the failing profile regression test**

The test verifies that the resource exposes every approved field, `sanitize()`
clamps counts/ranges and LOD ordering, the default `.tres` uses 1400 m coverage,
80 target clouds, 96 capacity, and `CloudManager` consumes a profile instead of
GraphicsManager pool-density keys.

- [ ] **Step 2: Run the test and verify RED**

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-tuning-profile.tests.ps1
```

Expected: FAIL because `cloud_tuning_profile.gd` is missing.

- [ ] **Step 3: Implement the typed resource**

Use exported groups and explicit types:

```gdscript
class_name CloudTuningProfile
extends Resource

@export_group("Distribution")
@export_range(100.0, 5000.0, 10.0) var coverage_radius: float = 1400.0
@export_range(50.0, 2000.0, 10.0) var coverage_height: float = 350.0
@export_range(1, 500, 1) var target_cloud_count: int = 80
@export_range(1, 500, 1) var pool_capacity: int = 96
@export_range(25.0, 500.0, 5.0) var cell_size: float = 120.0
@export var world_seed: int = 1337

@export_group("Size & Shape")
@export var scale_min := Vector3(40.0, 20.0, 70.0)
@export var scale_max := Vector3(120.0, 90.0, 180.0)
@export_range(0.0, 1.0, 0.01) var aspect_variation: float = 0.35
@export_range(0.0, 1.0, 0.01) var large_cloud_chance: float = 0.2
@export_range(1.0, 3.0, 0.05) var large_cloud_multiplier: float = 1.5
@export_range(0.0, 10.0, 0.05) var shape_variation: float = 2.0

@export_group("LOD & Recycling")
@export_range(0.0, 1000.0, 5.0) var full_volume_distance: float = 120.0
@export_range(0.0, 2000.0, 5.0) var cheap_volume_distance: float = 250.0
@export_range(0.0, 3000.0, 5.0) var billboard_transition_start: float = 280.0
@export_range(0.0, 4000.0, 5.0) var billboard_transition_end: float = 420.0
@export_range(0.05, 3.0, 0.05) var recycle_fade_duration: float = 1.0
@export_range(1, 16, 1) var updates_per_frame: int = 3
```

`sanitize()` enforces `pool_capacity >= target_cloud_count`, positive sizes,
component-wise `scale_max >= scale_min`, and ordered LOD distances.

- [ ] **Step 4: Create and assign the default `.tres`**

Assign the project resource by default through:

```gdscript
@export var tuning_profile: CloudTuningProfile = preload(
    "res://levels/components/CloudManager/cloud_tuning_profile.tres"
)
```

in `CloudManager`. `apply_tuning_profile()` sanitizes it, updates LOD on every
pooled cloud, and requests reconciliation without directly deleting clouds.

- [ ] **Step 5: Stop GraphicsManager from overwriting tuned pool values**

Remove only `cloud_pool_horizontal_radius`, `cloud_pool_vertical_radius`,
`cloud_pool_density`, and `cloud_pool_updates_per_frame`. Keep renderer and
raymarch-quality settings. Cloud LOD distances come from the active profile.

- [ ] **Step 6: Run the profile test and existing cloud tests**

Expected: all PASS.

- [ ] **Step 7: Commit Task 1 files only**

```powershell
git add -- .codex/tests/cloud-tuning-profile.tests.ps1 levels/components/CloudManager/cloud_tuning_profile.gd levels/components/CloudManager/cloud_tuning_profile.tres levels/components/CloudManager/CloudManager.gd common/autoload/graphics_manager.gd
git commit -m "feat: add project cloud tuning profile"
```

### Task 2: Stable Long-Range Streaming and Shape Variation

**Files:**
- Modify: `levels/components/CloudManager/cloud_cell_layout.gd`
- Modify: `levels/components/CloudManager/CloudManager.gd`
- Modify: `levels/components/CloudManager/cloud_lod_controller.gd`
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader`
- Modify: `assets/shaders/Cloud_impostor/cloud_impostor.gdshader`
- Modify: `.codex/tests/cloud-world-pool.tests.ps1`

**Interfaces:**
- Produces: `CloudCellLayout.candidate_cells(center, profile) -> Array[Vector3i]`.
- Produces: `CloudCellLayout.occupancy_threshold(profile) -> float`.
- Produces: `CloudCellLayout.cell_data(cell, profile) -> Dictionary` containing `transform`, `shape_offset`, and `priority`.
- Produces: `CloudLodController.configure_from_profile(profile) -> void`.
- Produces: `CloudLodController.set_shape_offset(offset: Vector3) -> void`.

- [ ] **Step 1: Extend the failing pool test**

Require stable occupancy derived from target count, retention of active eligible
cells, no nearest-cell truncation, pending outer cells when capacity is full,
and matching per-instance `shape_offset` in both shaders.

- [ ] **Step 2: Run the test and verify RED**

Expected: FAIL because current `desired_cells()` truncates nearest candidates.

- [ ] **Step 3: Implement profile-based deterministic cell data**

Calculate horizontal/vertical cell radii from meters. Hash each world cell to:

- decide occupancy using a threshold derived once per profile;
- interpolate `scale_min` to `scale_max`;
- apply `aspect_variation`;
- apply `large_cloud_chance` and `large_cloud_multiplier`;
- generate a stable `shape_offset`.

Do not include player position in the hash.

- [ ] **Step 4: Reconcile without near eviction**

Keep `_active_cells` and `_reserved_cells` while their cells remain inside the
outer ellipsoid. Release only cells outside coverage. Sort newly entered cells
outermost-first and enqueue them. When capacity is full, leave them pending;
never replace an active eligible cloud.

Initial population selects deterministic cells across near/mid/far bands so
the starting frame has volumetric and billboard coverage.

- [ ] **Step 5: Apply stable shape variation**

Add:

```glsl
instance uniform vec3 shape_offset = vec3(0.0);
```

to both shaders and include it in procedural sampling coordinates.
`CloudLodController.set_shape_offset()` writes only instance shader parameters.

- [ ] **Step 6: Apply profile LOD**

Map:

- `full_volume_distance` -> full-to-cheap start;
- `cheap_volume_distance` -> cheap-volume region;
- `billboard_transition_start/end` -> crossfade.

Keep surface-distance correction and quality-specific raymarch steps.

- [ ] **Step 7: Run all cloud regressions**

Expected: all PASS.

- [ ] **Step 8: Commit Task 2 files only**

```powershell
git add -- .codex/tests/cloud-world-pool.tests.ps1 levels/components/CloudManager/cloud_cell_layout.gd levels/components/CloudManager/CloudManager.gd levels/components/CloudManager/cloud_lod_controller.gd assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader assets/shaders/Cloud_impostor/cloud_impostor.gdshader
git commit -m "feat: stream varied clouds across long range"
```

### Task 3: Island Cloud Exclusion Volumes

**Files:**
- Create: `levels/components/CloudManager/cloud_exclusion_math.gd`
- Create: `levels/components/CloudManager/cloud_exclusion_volume.gd`
- Create: `levels/components/CloudManager/cloud_exclusion_volume.tscn`
- Create: `.codex/tests/cloud-exclusion.tests.ps1`
- Modify: `levels/components/CloudManager/CloudManager.gd`

**Interfaces:**
- Produces: `class_name CloudExclusionVolume extends Area3D`.
- Produces: `get_exclusion_shape() -> Shape3D`.
- Produces: `get_clearance() -> float`.
- Produces: `CloudExclusionMath.intersects_cloud(volume, cloud_center, cloud_radius) -> bool`.

- [ ] **Step 1: Write the failing exclusion test**

Cover literal cases for:

- point outside box plus clearance -> false;
- sphere overlapping box edge by cloud radius -> true;
- point above box and padded cloud radius -> false;
- sphere exclusion overlap and non-overlap;
- scaled global transforms.

Also require automatic membership in `cloud_exclusion`.

- [ ] **Step 2: Run the test and verify RED**

Expected: FAIL because exclusion files are missing.

- [ ] **Step 3: Implement pure box/sphere overlap math**

Transform the cloud center into exclusion local space. For boxes, clamp to local
half-extents expanded by `clearance`, then compare the closest-point distance to
the transformed cloud radius. For spheres, compare center distance with scaled
shape radius + clearance + cloud radius.

- [ ] **Step 4: Implement the reusable exclusion scene**

Use `Area3D` + `CollisionShape3D`, export `clearance`, add the group in `_enter_tree`,
and show the collision volume in editor. Reject unsupported shapes once with a
warning rather than querying terrain meshes.

- [ ] **Step 5: Filter candidate cells in CloudManager**

Cache group nodes on initialization/regeneration. Before reserving a cell,
estimate cloud radius from its generated transform and reject it when any valid
volume intersects. Rejected cells remain empty and do not consume pool slots.

- [ ] **Step 6: Run exclusion and cloud regressions**

Expected: all PASS.

- [ ] **Step 7: Commit Task 3 files only**

```powershell
git add -- .codex/tests/cloud-exclusion.tests.ps1 levels/components/CloudManager/cloud_exclusion_math.gd levels/components/CloudManager/cloud_exclusion_volume.gd levels/components/CloudManager/cloud_exclusion_volume.tscn levels/components/CloudManager/CloudManager.gd
git commit -m "feat: add cloud exclusion volumes"
```

### Task 4: Live F10 Tuning Panel and Project Save

**Files:**
- Create: `levels/components/CloudManager/cloud_tuning_panel.gd`
- Create: `levels/components/CloudManager/cloud_tuning_panel.tscn`
- Create: `.codex/tests/cloud-tuning-panel.tests.ps1`
- Modify: `levels/components/CloudManager/CloudManager.gd`
- Modify: `levels/components/CloudManager/cloud_lod_controller.gd`
- Modify: `common/autoload/game_constants.gd`
- Modify: `project.godot`

**Interfaces:**
- Produces: input action `cloud_tuning_toggle` on F10.
- Produces: `CloudManager.get_cloud_stats() -> Dictionary`.
- Produces: `CloudManager.regenerate_from_profile() -> void`.
- Produces: `CloudManager.save_tuning_profile() -> Error`.
- Produces: `CloudManager.reload_tuning_profile() -> Error`.
- Consumes: exported property metadata returned by `CloudTuningProfile.get_property_list()`.

- [ ] **Step 1: Write the failing panel regression test**

Verify F10 is unique, F1-F4/F7 remain intact, the panel is debug-only, property
rows are generated from resource metadata, every edit calls
`apply_tuning_profile()`, and save/reload return explicit `Error` values.

- [ ] **Step 2: Run the test and verify RED**

Expected: FAIL because `cloud_tuning_toggle` and panel files are missing.

- [ ] **Step 3: Add F10 without changing existing bindings**

Add:

```gdscript
const INPUT_CLOUD_TUNING_TOGGLE = "cloud_tuning_toggle"
```

and bind physical keycode `4194341`.

- [ ] **Step 4: Build the debug panel**

The scene contains a `CanvasLayer`, dark `PanelContainer`, `ScrollContainer`,
generated fields container, stats labels, status label, and buttons:
`Regenerate`, `Save Project`, `Reload Saved`, `Reset`.

Generate controls from the resource property list:

- integer/float range -> `SpinBox` plus slider;
- `Vector3` -> X/Y/Z `SpinBox` controls;
- category entries -> section headers.

Changing a value updates the active resource and immediately calls
`CloudManager.apply_tuning_profile()`.

- [ ] **Step 5: Implement input and mouse behavior**

F10 toggles visibility, stores/restores the previous mouse mode, consumes input,
and never pauses the tree. Instantiate the panel only when
`OS.is_debug_build()` is true; do not include active UI behavior in
production/mobile.

- [ ] **Step 6: Implement project save/reload/reset**

Save with:

```gdscript
ResourceSaver.save(tuning_profile, tuning_profile.resource_path)
```

Return and display the exact `Error`. Reload with an uncached load from the same
path, replace the manager profile, and rebuild fields. Reset copies values from
`CloudTuningProfile.new()` but does not save automatically.

- [ ] **Step 7: Implement live statistics**

`CloudLodController` exposes its last evaluated mode. Manager returns Active,
Full, Cheap, Billboard, Pending, and Capacity counts. Refresh labels at 4 Hz,
not every frame.

- [ ] **Step 8: Run panel, profile, and cloud regressions**

Expected: all PASS.

- [ ] **Step 9: Commit Task 4 files only**

```powershell
git add -- .codex/tests/cloud-tuning-panel.tests.ps1 levels/components/CloudManager/cloud_tuning_panel.gd levels/components/CloudManager/cloud_tuning_panel.tscn levels/components/CloudManager/CloudManager.gd levels/components/CloudManager/cloud_lod_controller.gd common/autoload/game_constants.gd project.godot
git commit -m "feat: add live cloud tuning panel"
```

### Task 5: Integration Verification and User Scene Setup

**Files:**
- Modify only Task 1-4 files if verification exposes a regression.
- User action: instance `cloud_exclusion_volume.tscn` around islands in `Level_01`.

**Interfaces:**
- Consumes: all Task 1-4 outputs.

- [ ] **Step 1: Run the complete safe regression suite**

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .codex/tests/player-debug-flight.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-tuning-profile.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-world-pool.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-exclusion.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-tuning-panel.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-procedural-lod.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-lod-shaders.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-editor-regression.tests.ps1
```

- [ ] **Step 2: Confirm commit isolation**

Check `git status --short` and ensure pre-existing user scene/material changes
were not overwritten by Tasks 1-4.

- [ ] **Step 3: Give the user a manual Godot checklist**

The user:

1. opens F10 during F7 flight;
2. changes radius/count/scale/aspect/LOD live;
3. flies beyond 1400 m and approaches the same distant billboard;
4. verifies it becomes volumetric without identity/scale change;
5. saves, restarts, and checks persisted project values;
6. places Box and Sphere exclusion volumes around island terrain;
7. verifies padded terrain stays clear while clouds remain possible above it;
8. switches F1/F2/F3 and verifies the saved profile values are not overwritten.

- [ ] **Step 4: Fix only reproduced regressions and rerun Step 1**

Do not launch Godot from the terminal. Use user-reported console lines and
screenshots for runtime-only failures.
