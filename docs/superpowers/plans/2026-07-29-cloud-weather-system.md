# Cloud Weather System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manual WeatherManager, an always-present far sky layer, and coarse drifting physical cloud formations without coverage spikes.

**Architecture:** WeatherManager owns one smoothed WeatherProfile and mirrors it to canonical shader globals plus existing grass/water adapters. Far clouds render in the active sky shader. Physical clouds keep their current scenes and LOD but receive transforms from a deterministic coarse weather field and drift under one shared root.

**Tech Stack:** Godot 4.7 GDScript, spatial and sky shaders, Resource profiles, FastNoiseLite/NoiseTexture2D, PowerShell regression checks.

## Global Constraints

- Do not launch the Steam Godot executable from the terminal.
- Preserve existing user overrides in `cloud_tuning_profile.tres`.
- Keep the existing Cloud scene, LOD shaders, pool, exclusion volumes, and F10 workflow.
- Weather remains manually controlled; no automatic presets, rain, or lightning.
- No runtime Viewports, captures, baked atlases, material duplication, or unbounded pools.
- New physical cloud enumeration must use coarse chunks and stay independent of the old 120 m cell volume.

---

### Task 1: Manual WeatherManager and Wind Adapters

**Files:**
- Create: `common/weather/weather_profile.gd`
- Create: `common/weather/weather_profile.tres`
- Create: `common/weather/weather_manager.gd`
- Modify: `project.godot`
- Modify: `assets/shaders/TreeWindShader.gdshader`
- Create: `.codex/tests/weather-manager.tests.ps1`

**Interfaces:**
- Produces: `class_name WeatherProfile`
- Produces: `WeatherManager.apply_profile(profile: WeatherProfile, blend_duration: float = -1.0) -> void`
- Produces: `WeatherManager.get_cloud_offset() -> Vector3`
- Produces signal: `weather_changed(profile: WeatherProfile)`

- [ ] **Step 1: Write the failing weather contract test**

Require profile fields:

```gdscript
wind_direction
wind_speed
wind_strength
wind_turbulence
manual_blend_duration
cloud_drift_multiplier
cloud_noise_advection
cloud_evolution_speed
formation_lifetime_min
formation_lifetime_max
formation_fade_duration
```

Require one WeatherManager autoload and canonical globals
`weather_wind_direction`, `weather_wind_speed`, `weather_wind_strength`,
`weather_wind_turbulence`, `weather_cloud_offset`, and
`weather_cloud_evolution`.

- [ ] **Step 2: Run the new test and verify RED**

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/weather-manager.tests.ps1
```

Expected: FAIL because weather files and autoload do not exist.

- [ ] **Step 3: Implement WeatherProfile sanitization**

Normalize horizontal direction while preserving the last valid non-zero
direction. Clamp strength/turbulence/speeds non-negative and enforce:

```gdscript
formation_lifetime_max = maxf(
    formation_lifetime_max,
    formation_lifetime_min
)
formation_fade_duration = minf(
    formation_fade_duration,
    formation_lifetime_min * 0.45
)
```

- [ ] **Step 4: Implement manual smoothing and global output**

WeatherManager loads `weather_profile.tres`, maintains target/current values,
integrates cloud offset once per frame, and writes only canonical globals.
When values change, call `/root/SimpleGrass` setters if available and mirror
direction/strength to existing water globals.

- [ ] **Step 5: Convert TreeWindShader to canonical globals**

Replace local wind direction/strength/speed inputs with:

```glsl
global uniform vec3 weather_wind_direction;
global uniform float weather_wind_speed;
global uniform float weather_wind_strength;
global uniform float weather_wind_turbulence;
```

Retain material-level response multipliers so different foliage types may bend
by different amounts.

- [ ] **Step 6: Run test GREEN and commit**

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/weather-manager.tests.ps1
git diff --check
git add -- common/weather project.godot assets/shaders/TreeWindShader.gdshader .codex/tests/weather-manager.tests.ps1
git commit -m "feat: add unified manual weather manager"
```

---

### Task 2: Always-Present Far Sky Clouds

**Files:**
- Create: `common/weather/far_cloud_noise_base.tres`
- Create: `common/weather/far_cloud_noise_detail.tres`
- Modify: `assets/shaders/sky_gradient.gdshader`
- Modify: `levels/components/Environment/environment_system.tscn`
- Modify: `levels/components/Environment/DayNightCycle.gd`
- Create: `.codex/tests/far-sky-clouds.tests.ps1`

**Interfaces:**
- Consumes canonical weather globals from Task 1.
- Consumes existing `cloud_light_color` and `cloud_shadow_color` gradients.
- Produces shader uniforms `far_cloud_light_color`, `far_cloud_shadow_color`,
  `far_cloud_horizon_coverage`, `far_cloud_upper_coverage`, and
  `far_cloud_lower_coverage`.

- [ ] **Step 1: Write failing far-layer tests**

Require `render_mode use_half_res_pass`, `AT_CUBEMAP_PASS`, two noise textures,
canonical weather offset/evolution, separate upper/lower masks, and
DayNightCycle writes for both far-cloud colors.

- [ ] **Step 2: Run test RED**

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/far-sky-clouds.tests.ps1
```

Expected: FAIL on missing sky-cloud contract.

- [ ] **Step 3: Add reusable noise resources**

Create two seamless `NoiseTexture2D` resources with different FastNoiseLite
frequencies and seeds. Reference them from the EnvironmentSystem sky material.

- [ ] **Step 4: Merge far clouds into sky_gradient**

Calculate clouds only in `AT_HALF_RES_PASS`. During `AT_CUBEMAP_PASS`, output
the normal sky gradient without cloud texture sampling. In the full pass,
combine `HALF_RES_COLOR` over the existing gradient and stars.

Advect UVs with `weather_cloud_offset.xz` and evolve the detail layer with
`weather_cloud_evolution`. Apply independent horizon, upper, and lower masks.

- [ ] **Step 5: Synchronize day/night colors**

Extend DayNightCycle so the same cloud light/shadow gradients update physical,
billboard, and far sky materials.

- [ ] **Step 6: Run tests GREEN and commit**

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/far-sky-clouds.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-procedural-lod.tests.ps1
git diff --check
git add -- common/weather/far_cloud_noise_base.tres common/weather/far_cloud_noise_detail.tres assets/shaders/sky_gradient.gdshader levels/components/Environment/environment_system.tscn levels/components/Environment/DayNightCycle.gd .codex/tests/far-sky-clouds.tests.ps1
git commit -m "feat: add far sky cloud layer"
```

---

### Task 3: Coarse Correlated Weather Field

**Files:**
- Create: `levels/components/CloudManager/cloud_weather_field.gd`
- Modify: `levels/components/CloudManager/cloud_tuning_profile.gd`
- Modify: `levels/components/CloudManager/cloud_cell_layout.gd`
- Create: `.codex/tests/cloud-weather-field.tests.ps1`
- Modify: `.codex/tests/cloud-tuning-profile.tests.ps1`

**Interfaces:**
- Produces: `CloudWeatherField.candidate_chunks(center: Vector3i, profile: CloudTuningProfile) -> Array[Vector3i]`
- Produces: `CloudWeatherField.candidate_members(center: Vector3i, profile: CloudTuningProfile, wind_direction: Vector3) -> Array[Vector4i]`
- Produces: `CloudWeatherField.member_data(key: Vector4i, profile: CloudTuningProfile, wind_direction: Vector3) -> Dictionary`
- Dictionary output includes `transform`, `shape_offset`, `cloud_radius`,
  `formation_phase`, `formation_lifetime`, and `formation_fade_duration`.

- [ ] **Step 1: Write failing weather-field tests**

Require new profile properties:

```gdscript
chunk_size = 1000.0
horizontal_chunk_radius = 2
vertical_chunk_radius = 1
horizontal_prewarm_chunks = 1
vertical_prewarm_chunks = 1
weather_scale
weather_threshold
formation_min_members
formation_max_members
formation_spread
formation_thickness
```

Reject nested iteration based on
`coverage_radius / cell_size` and `coverage_height / cell_size` in the new
weather-field helper.

- [ ] **Step 2: Run tests RED**

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-weather-field.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-tuning-profile.tests.ps1
```

Expected: FAIL on missing field and chunk properties.

- [ ] **Step 3: Implement spatially correlated density**

Use deterministic smooth 3D value noise from eight hashed lattice corners.
Sample chunk centers at `weather_scale`; adjacent chunks must share lattice
corners and therefore form continuous high/low density regions.

- [ ] **Step 4: Generate asymmetric formations**

Density controls formation/member count and scale. Generate member offsets from
an ellipse whose major axis is captured from wind direction at formation
creation. Add independent asymmetry, height, thickness, scale, and shape hashes.

- [ ] **Step 5: Add deterministic lifecycle data**

Formation phase and lifetime derive from chunk and formation index. Member
phase offsets remain small enough that banks dissolve progressively.

- [ ] **Step 6: Run tests GREEN and commit**

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-weather-field.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-tuning-profile.tests.ps1
git diff --check
git add -- levels/components/CloudManager/cloud_weather_field.gd levels/components/CloudManager/cloud_tuning_profile.gd levels/components/CloudManager/cloud_cell_layout.gd .codex/tests/cloud-weather-field.tests.ps1 .codex/tests/cloud-tuning-profile.tests.ps1
git commit -m "feat: add coarse cloud weather field"
```

---

### Task 4: Drift Root, Vertical Hysteresis, and Lifecycle

**Files:**
- Modify: `levels/components/CloudManager/CloudManager.gd`
- Modify: `levels/components/CloudManager/cloud_lod_controller.gd`
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader`
- Modify: `assets/shaders/Cloud_impostor/cloud_impostor.gdshader`
- Modify: `.codex/tests/cloud-world-pool.tests.ps1`
- Modify: `.codex/tests/cloud-lod-controller.tests.ps1`
- Modify: `.codex/tests/cloud-lod-shaders.tests.ps1`

**Interfaces:**
- Consumes CloudWeatherField from Task 3 and
  `WeatherManager.get_cloud_offset()`.
- Produces `CloudLodController.set_lifecycle_fade(value: float) -> void`.
- Combined shader fade becomes recycle × boundary × lifecycle.

- [ ] **Step 1: Write failing drift/lifecycle tests**

Require `CloudDriftRoot`, virtual player coordinates, chunk-based request keys,
horizontal and vertical boundary fades, vertical hysteresis, lifecycle update
interval, root rebasing, and early shader discard before raymarch.

- [ ] **Step 2: Run tests RED**

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-world-pool.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-lod-controller.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-lod-shaders.tests.ps1
```

Expected: FAIL on missing drift-root/lifecycle contracts.

- [ ] **Step 3: Reparent the pool under CloudDriftRoot**

At runtime create one root, reparent existing scene clouds preserving their
global transforms, and instantiate all new pooled clouds beneath it.

- [ ] **Step 4: Stream in virtual weather coordinates**

Calculate:

```gdscript
virtual_player_position = (
    player.global_position - WeatherManager.get_cloud_offset()
)
```

Request coarse chunk members. Move the drift root by the current weather offset
and rebase by whole chunk increments while preserving global cloud positions.

- [ ] **Step 5: Add independent vertical fade and hysteresis**

Boundary visibility is the minimum of horizontal and vertical smooth fades.
Keep the previous center chunk until the player crosses the configured
hysteresis band. Never release one complete vertical layer on a single small
height step.

- [ ] **Step 6: Add lifecycle fade**

Evaluate lifecycle at 1 Hz. Multiply lifecycle fade in the LOD controller.
Add this before raymarch in both shaders:

```glsl
if (pool_fade <= 0.001) {
    discard;
}
```

- [ ] **Step 7: Run tests GREEN and commit**

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-world-pool.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-lod-controller.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-lod-shaders.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-exclusion.tests.ps1
git diff --check
git add -- levels/components/CloudManager/CloudManager.gd levels/components/CloudManager/cloud_lod_controller.gd assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader assets/shaders/Cloud_impostor/cloud_impostor.gdshader .codex/tests/cloud-world-pool.tests.ps1 .codex/tests/cloud-lod-controller.tests.ps1 .codex/tests/cloud-lod-shaders.tests.ps1
git commit -m "feat: drift and evolve physical cloud formations"
```

---

### Task 5: F10 Weather Controls and Final Verification

**Files:**
- Modify: `levels/components/CloudManager/cloud_tuning_panel.gd`
- Modify: `levels/components/CloudManager/cloud_tuning_panel.tscn`
- Modify: `levels/components/CloudManager/CloudManager.gd`
- Modify: `.codex/tests/cloud-tuning-panel.tests.ps1`

**Interfaces:**
- Consumes `/root/WeatherManager.profile`.
- CloudManager produces `save_weather_profile() -> Error` and
  `reload_weather_profile() -> Error`.

- [ ] **Step 1: Write failing panel tests**

Require separate Cloud and Weather categories, resource-aware field callbacks,
and Save/Reload/Reset actions covering both resources without duplicating UI.

- [ ] **Step 2: Run test RED**

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-tuning-panel.tests.ps1
```

Expected: FAIL on missing Weather section.

- [ ] **Step 3: Generalize resource fields**

Build fields from `(resource, allowed_categories, apply_callback)` descriptors.
Cloud edits call `apply_tuning_profile`; weather edits call
`WeatherManager.apply_profile`.

- [ ] **Step 4: Save and reload both profiles**

Preserve current runtime values if either save fails and report the exact failed
resource. Reset creates fresh `CloudTuningProfile` and `WeatherProfile` values
without saving automatically.

- [ ] **Step 5: Run safe full suite**

Run every `.codex/tests/*.tests.ps1` except tests that launch Steam Godot or
rewrite the project index. Run `git diff --check` and verify `git status`.

- [ ] **Step 6: Commit, push, and manual handoff**

```powershell
git add -- levels/components/CloudManager/cloud_tuning_panel.gd levels/components/CloudManager/cloud_tuning_panel.tscn levels/components/CloudManager/CloudManager.gd .codex/tests/cloud-tuning-panel.tests.ps1
git commit -m "feat: tune cloud weather from debug panel"
git push origin codex/cloud-lod
```

Manual test in the already-open editor:

1. Reload project scripts, run, open F10, and regenerate clouds.
2. Look 360 degrees and vertically before moving.
3. Fly through several chunk boundaries and compare 1% Low.
4. Change manual wind direction and strength.
5. Confirm grass, trees, water, physical clouds, and far clouds transition
   together.
6. Observe slow formation drift and lifecycle for several minutes.
