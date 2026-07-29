# World-Space Cloud Cluster Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `EnvironmentSystem/CloudManager` preserve its attractive saved clouds at startup and stream matching deterministic world-space clusters for unlimited 3D flight.

**Architecture:** Replace the runtime-only `CloudCellLayout` path with a shared deterministic `CloudClusterLayout` used by editor generation and runtime streaming. Keep saved scene children as the initial visible set, stream additional sectors outside them, retain sectors behind the player, and recycle only fully faded distant members. CloudManager exposes the shared WeatherProfile and keeps runtime F10 tuning opt-in.

**Tech Stack:** Godot 4.7.1, typed GDScript, spatial shaders, Resource profiles, PowerShell contract tests.

## Global Constraints

- `EnvironmentSystem/CloudManager` is the only cloud owner.
- No whole-sphere switching or camera-frustum-dependent generation.
- Existing children in `environment_system.tscn` remain visible and unmoved on runtime initialization.
- World-space cluster positions are deterministic for sector key and seed.
- LOD and pool fade continue through `cloud_lod_controller.gd`.
- Steam Godot is not launched by automation.
- All work stays on `codex/cloud-lod` and is pushed after safe verification.

---

### Task 1: Protect saved EnvironmentSystem clouds

**Files:**
- Modify: `.codex/tests/cloud-world-pool.tests.ps1`
- Modify: `levels/components/CloudManager/CloudManager.gd`

**Interfaces:**
- Produces: `_preview_clouds: Array[Node3D]`, `enable_runtime_tuning: bool`
- Preserves: saved child transform, visibility, and `pool_fade = 1.0`

- [ ] **Step 1: Add failing contracts**

Require CloudManager to:

```gdscript
@export var enable_runtime_tuning: bool = false
var _preview_clouds: Array[Node3D] = []
```

Reject unconditional startup calls that set every existing child invisible or move it through `_move_cloud_to_member`.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/cloud-world-pool.tests.ps1
```

Expected: FAIL because runtime initialization currently hides all existing clouds and creates F10 automatically.

- [ ] **Step 3: Preserve saved children**

During `_initialize_runtime_pool()`:

- collect saved cloud children into `_preview_clouds`;
- configure their LOD;
- keep current transforms and visibility;
- set pool fade to `1.0`;
- instantiate only the remaining pool capacity as hidden free members;
- create the tuning panel only when `enable_runtime_tuning` is true.

- [ ] **Step 4: Run GREEN**

Run the focused contract and confirm PASS.

### Task 2: Add the shared deterministic cluster layout

**Files:**
- Create: `levels/components/CloudManager/cloud_cluster_layout.gd`
- Create: `.codex/tests/cloud-cluster-layout.tests.ps1`
- Modify: `levels/components/CloudManager/cloud_tuning_profile.gd`
- Modify: `levels/components/CloudManager/cloud_tuning_profile.tres`

**Interfaces:**
- Produces: `CloudClusterLayout.world_to_sector(position, sector_size) -> Vector3i`
- Produces: `CloudClusterLayout.candidate_members(center, profile, margin) -> Array[Vector4i]`
- Produces: `CloudClusterLayout.member_data(key, profile) -> Dictionary`
- Produces: `CloudClusterLayout.preview_members(profile) -> Array[Vector4i]`

- [ ] **Step 1: Add failing layout contracts**

Require a typed, pure layout helper with deterministic hash inputs:

```gdscript
hash("%d:%d:%d:%d:%d:%d" % [
    sector.x, sector.y, sector.z, member_index, world_seed, salt
])
```

Require candidate generation to iterate X, Y, and Z around the player, accept a range margin, and sort far members first for prewarming.

- [ ] **Step 2: Run RED**

Run the new test and confirm it fails because the helper does not exist.

- [ ] **Step 3: Implement the helper**

Reuse the proven hashing/member-transform code from `cloud_cell_layout.gd`, but expose sector terminology and an explicit margin. Generate 1–3 overlapping members per occupied sector with stable scale, rotation, shape seed, and cluster radius.

- [ ] **Step 4: Align the project profile with the attractive preview**

Set explicit resource values:

```gdscript
coverage_radius = 1200.0
coverage_height = 1200.0
target_cloud_count = 80
pool_capacity = 120
cell_size = 300.0
scale_min = Vector3(40.0, 20.0, 80.0)
scale_max = Vector3(100.0, 80.0, 150.0)
cluster_min_members = 1
cluster_max_members = 3
cluster_spread = 70.0
prewarm_margin = 500.0
retention_margin = 800.0
```

Add `retention_margin` and sanitize ordering.

- [ ] **Step 5: Run GREEN**

Run cluster-layout and tuning-profile tests and confirm PASS.

### Task 3: Use one layout for editor preview and runtime streaming

**Files:**
- Modify: `levels/components/CloudManager/CloudManager.gd`
- Modify: `.codex/tests/cloud-procedural-lod.tests.ps1`
- Modify: `.codex/tests/cloud-world-pool.tests.ps1`
- Delete: `levels/components/CloudManager/cloud_cell_layout.gd`

**Interfaces:**
- Consumes: `CloudClusterLayout`
- Produces: `_active_members`, `_reserved_members`, `_preview_clouds`
- Produces: prewarm and retention member sets

- [ ] **Step 1: Add failing shared-layout contracts**

Require both `spawn_clouds()` and `_request_members()` to call `CloudClusterLayout`. Reject runtime references to `CloudCellLayout`.

- [ ] **Step 2: Run RED**

Run procedural and world-pool tests and confirm failure on the old layout path.

- [ ] **Step 3: Refactor runtime requests**

For each player-sector change:

```gdscript
var desired := CloudClusterLayout.candidate_members(
    center_sector,
    tuning_profile,
    tuning_profile.prewarm_margin
)
var retained := CloudClusterLayout.candidate_members(
    center_sector,
    tuning_profile,
    tuning_profile.retention_margin
)
```

Create missing desired members farthest-first. Release active members only when absent from `retained`. Never steal a visible member when the free pool is empty.

- [ ] **Step 4: Integrate saved preview members**

Keep saved preview members outside the generated-key dictionaries. Fade them individually only after their world position exceeds `coverage_radius + retention_margin` from the player. Once faded, return them to the normal free pool.

- [ ] **Step 5: Refactor editor generation**

Make `spawn_clouds()` obtain deterministic transforms from `CloudClusterLayout.preview_members()`. Continue assigning `owner` so generated preview children save into `environment_system.tscn`.

- [ ] **Step 6: Run GREEN**

Run world-pool, procedural, exclusion, and LOD tests.

### Task 4: Expose weather and apply shared formation drift

**Files:**
- Modify: `levels/components/CloudManager/CloudManager.gd`
- Modify: `common/weather/weather_profile.gd`
- Modify: `common/weather/weather_profile.tres`
- Modify: `.codex/tests/weather-manager.tests.ps1`

**Interfaces:**
- Produces: `@export var weather_profile: WeatherProfile`
- Consumes: `WeatherManager.apply_profile(profile, duration)`
- Consumes: `WeatherManager.get_cloud_offset() -> Vector3`

- [ ] **Step 1: Add failing weather contracts**

Require CloudManager to expose and apply WeatherProfile. Require active transform placement to add one shared weather offset and sector lookup to subtract the same offset from player position.

- [ ] **Step 2: Run RED**

Run weather-manager tests and confirm failure.

- [ ] **Step 3: Apply the profile from CloudManager**

On runtime startup, call WeatherManager only when the autoload and profile are valid. Missing weather must not stop cloud initialization.

- [ ] **Step 4: Add stable shared drift**

Store base transforms for generated and preview clouds. Render each at:

```gdscript
base_transform.translated(weather_offset)
```

Request sectors using:

```gdscript
player.global_position - weather_offset
```

This moves the cloud field slowly with wind without coupling it to player motion.

- [ ] **Step 5: Run GREEN**

Run weather, stable-noise, world-pool, and LOD tests.

### Task 5: Verify and publish

**Files:**
- Test: `.codex/tests/cloud-*.tests.ps1`
- Test: `.codex/tests/weather-manager.tests.ps1`

**Interfaces:**
- Produces: pushed branch ready for manual Godot flight testing

- [ ] **Step 1: Run all safe tests**

Run every cloud test except `cloud-lod-policy.tests.ps1`, which launches Steam Godot, plus weather-manager tests in separate PowerShell processes.

- [ ] **Step 2: Verify resources and diffs**

Run:

```powershell
git diff --check
rg -n "CloudCellLayout|cloud_cell_layout" levels common assets project.godot
git status --short
```

Expected: no live old-layout references, no whitespace errors, only planned files changed.

- [ ] **Step 3: Commit and push**

Commit focused implementation changes and push `codex/cloud-lod`.

- [ ] **Step 4: Manual handoff**

Ask the user to open `Level_01`, compare startup against EnvironmentSystem preview, fly horizontally and vertically, rotate the camera, inspect LOD transitions, and report screenshots plus new console errors.
