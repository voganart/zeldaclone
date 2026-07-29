# Cloud Rollback and Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the attractive `741627c` cloud system without losing Git history, keep WeatherManager, and make cloud noise stable under player movement.

**Architecture:** Revert only the six experimental commits after WeatherManager, newest first, including the saved editor state. Keep `57fa695` for shared wind. Add one focused shader contract test, then change both LOD shaders so erosion/detail noise uses per-cloud seed plus WeatherManager's global offset instead of cloud world position.

**Tech Stack:** Godot 4.7.1, GDScript, Godot spatial shaders, PowerShell contract tests, Git.

## Global Constraints

- Preserve backup commit `db93641` in pushed history.
- Do not launch the Steam Godot editor from automation.
- Do not change unrelated game files.
- Keep shader dither LOD and matched billboard reference lighting from `741627c`.
- Keep WeatherManager from `57fa695`; remove far-sky, CloudWeatherField, DriftRoot, and lifecycle experiments.

---

### Task 1: Revert experimental cloud architecture

**Files:**
- Restore through Git: files changed by `db93641`, `a2b81a3`, `df0bd2c`, `12e6e7b`, `c3b590e`, and `028b1c3`
- Preserve: `common/weather/weather_manager.gd`
- Preserve: `common/weather/weather_profile.gd`
- Preserve: `assets/shaders/TreeWindShader.gdshader`
- Preserve: WeatherManager entries in `project.godot`

**Interfaces:**
- Consumes: known-good cloud implementation at `741627c`
- Produces: the `741627c` cloud layout/streaming code plus the independent WeatherManager commit

- [ ] **Step 1: Verify the worktree is clean**

Run: `git status --short`

Expected: no output.

- [ ] **Step 2: Revert only the visual experiments without rewriting history**

Run:

```powershell
git revert --no-edit db93641
git revert --no-edit a2b81a3
git revert --no-edit df0bd2c
git revert --no-edit 12e6e7b
git revert --no-edit c3b590e
git revert --no-edit 028b1c3
```

Expected: six new revert commits, no reset, and `57fa695` remains reachable and active.

- [ ] **Step 3: Confirm the resulting file set**

Run:

```powershell
git diff --name-status 741627c..HEAD
rg -n "CloudWeatherField|FarCloud|CloudDriftRoot" levels common assets project.godot
```

Expected: WeatherManager, its profile, tree-wind integration, docs, and rollback history differ from `741627c`; no live references to removed experimental cloud layers.

### Task 2: Specify stable cloud-noise behavior

**Files:**
- Create: `.codex/tests/cloud-stable-noise.tests.ps1`
- Test: `.codex/tests/cloud-stable-noise.tests.ps1`

**Interfaces:**
- Consumes: `weather_cloud_offset`, `shape_offset`, both cloud shaders
- Produces: a regression contract forbidding cloud world position in shape-noise coordinates

- [ ] **Step 1: Write the failing shader contract test**

The test reads both shaders and requires:

```powershell
'global uniform vec3 weather_cloud_offset'
'shape_offset'
```

It rejects these expressions in noise-coordinate construction:

```powershell
'v_world_pos_center * 0.1'
'v_world_center * 0.1'
```

- [ ] **Step 2: Run the test and verify RED**

Run: `powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-stable-noise.tests.ps1`

Expected: FAIL because the restored shaders still include world-center offsets.

### Task 3: Decouple cloud noise from player-relative movement

**Files:**
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader`
- Modify: `assets/shaders/Cloud_impostor/cloud_impostor.gdshader`
- Test: `.codex/tests/cloud-stable-noise.tests.ps1`

**Interfaces:**
- Consumes: global `weather_cloud_offset`, instance `shape_offset`
- Produces: identical stable noise motion for volumetric and billboard LODs

- [ ] **Step 1: Add the shared global wind offset**

In both shaders declare:

```glsl
global uniform vec3 weather_cloud_offset;
```

- [ ] **Step 2: Replace world-position noise input**

Use:

```glsl
vec3 runtime_erosion_offset = shape_offset + weather_cloud_offset;
vec3 runtime_detail_offset = shape_offset * 1.7 + weather_cloud_offset;
```

Keep world-center varyings only where they are needed for camera distance and LOD.

- [ ] **Step 3: Run the focused test and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-stable-noise.tests.ps1`

Expected: PASS.

### Task 4: Regression verification and publication

**Files:**
- Test: `.codex/tests/cloud-*.tests.ps1`
- Test: `.codex/tests/weather-manager.tests.ps1`

**Interfaces:**
- Consumes: restored cloud system and stable-noise shaders
- Produces: pushed, manually testable branch

- [ ] **Step 1: Run all safe cloud and weather contract tests**

Run:

```powershell
Get-ChildItem .codex/tests/cloud-*.tests.ps1, .codex/tests/weather-manager.tests.ps1 |
    ForEach-Object { & $_.FullName }
```

Expected: all retained tests pass; obsolete experimental tests no longer exist.

- [ ] **Step 2: Check resource references and patch formatting**

Run:

```powershell
git diff --check
git status --short
rg -n "far_cloud_noise|cloud_weather_field|FarCloud|CloudDriftRoot" levels common assets project.godot
```

Expected: no whitespace errors and no removed-runtime references.

- [ ] **Step 3: Commit and push**

```powershell
git add .codex/tests/cloud-stable-noise.tests.ps1 assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader assets/shaders/Cloud_impostor/cloud_impostor.gdshader docs/superpowers/plans/2026-07-29-cloud-rollback-stabilization.md
git commit -m "fix: restore stable clustered cloud system"
git push origin codex/cloud-lod
```

- [ ] **Step 4: Hand off manual Godot verification**

Ask the user to open `level_01`, test flight, LOD transitions, and day/night lighting, then send only new console errors or a screenshot.
