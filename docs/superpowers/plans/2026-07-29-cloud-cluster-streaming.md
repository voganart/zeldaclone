# Cloud Cluster Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stream stable overlapping cloud clusters through a prewarm band and remove Billboard/Volume lighting flashes.

**Architecture:** `CloudCellLayout` remains the deterministic pure-data layer but returns cluster-member keys and transforms. `CloudManager` pools the same individual `Cloud` scenes using those keys. `CloudLodController` combines recycle and boundary fades, while both shaders share reference lighting at the dither transition.

**Tech Stack:** Godot 4.7 GDScript, Godot spatial shaders, PowerShell static/regression tests.

## Global Constraints

- Reuse the existing cloud scene, pool, LOD controller, tuning panel, day/night gradients, and exclusion volumes.
- `pool_capacity` counts individual cloud instances and remains the hard node limit.
- No runtime Viewports, texture captures, baked atlases, or extra dependencies.
- Do not launch the Steam Godot executable from the terminal because it has produced native memory crashes.
- Preserve the Godot-authored compact `.tres` serialization; validate defaults from the profile script when properties equal script defaults.

---

### Task 1: Deterministic Cluster Members and Profile

**Files:**
- Modify: `levels/components/CloudManager/cloud_tuning_profile.gd`
- Modify: `levels/components/CloudManager/cloud_tuning_profile.tres`
- Modify: `levels/components/CloudManager/cloud_cell_layout.gd`
- Modify: `.codex/tests/cloud-tuning-profile.tests.ps1`
- Modify: `.codex/tests/cloud-world-pool.tests.ps1`

**Interfaces:**
- Produces: `CloudCellLayout.candidate_members(center: Vector3i, profile: CloudTuningProfile) -> Array[Vector4i]`
- Produces: `CloudCellLayout.member_data(key: Vector4i, profile: CloudTuningProfile) -> Dictionary`
- Produces profile properties `cluster_min_members`, `cluster_max_members`, `cluster_spread`, `cluster_scale_variation`, `prewarm_margin`, and `edge_fade_width`.

- [ ] **Step 1: Write failing profile and layout tests**

Require the six exported fields, clamps, and these defaults in the profile
script:

```gdscript
prewarm_margin = 800.0
edge_fade_width = 650.0
cluster_min_members = 3
cluster_max_members = 6
cluster_spread = 220.0
cluster_scale_variation = 0.45
```

Require `candidate_members`, `member_data`, `Vector4i`, member-index hashing,
and outer radius use:

```gdscript
profile.coverage_radius + profile.prewarm_margin
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-tuning-profile.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-world-pool.tests.ps1
```

Expected: FAIL on missing cluster/prewarm fields and member APIs.

- [ ] **Step 3: Implement profile sanitization**

Add exports and enforce:

```gdscript
cluster_min_members = maxi(cluster_min_members, 1)
cluster_max_members = maxi(cluster_max_members, cluster_min_members)
cluster_spread = maxf(cluster_spread, 0.0)
cluster_scale_variation = clampf(cluster_scale_variation, 0.0, 1.0)
prewarm_margin = maxf(prewarm_margin, 0.0)
edge_fade_width = clampf(edge_fade_width, 0.0, prewarm_margin)
```

Keep `.tres` compact when Godot has omitted values equal to script defaults.

- [ ] **Step 4: Implement deterministic cluster layout**

Use `Vector4i(anchor.x, anchor.y, anchor.z, member_index)` as the stable pool
key. Derive anchor occupancy from target member count divided by candidate
anchors and average configured members. Generate each member count, offset,
scale multiplier, yaw, and shape offset from anchor coordinates, member index,
and `world_seed`. Limit local offsets by `cluster_spread` so members overlap.

- [ ] **Step 5: Run tests and verify GREEN**

Run the two Task 1 tests plus:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-exclusion.tests.ps1
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add -- levels/components/CloudManager/cloud_tuning_profile.gd levels/components/CloudManager/cloud_tuning_profile.tres levels/components/CloudManager/cloud_cell_layout.gd .codex/tests/cloud-tuning-profile.tests.ps1 .codex/tests/cloud-world-pool.tests.ps1
git commit -m "feat: generate deterministic cloud clusters"
```

---

### Task 2: Prewarm Streaming and Boundary Fade

**Files:**
- Modify: `levels/components/CloudManager/CloudManager.gd`
- Modify: `levels/components/CloudManager/cloud_lod_controller.gd`
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader`
- Modify: `assets/shaders/Cloud_impostor/cloud_impostor.gdshader`
- Modify: `.codex/tests/cloud-procedural-lod.tests.ps1`
- Modify: `.codex/tests/cloud-lod-controller.tests.ps1`

**Interfaces:**
- Consumes: `candidate_members()` and `member_data()` from Task 1.
- Produces: `CloudLodController.configure_stream_fade(coverage_radius: float, prewarm_margin: float, edge_fade_width: float) -> void`
- Produces: `CloudLodController.set_edge_fade(value: float) -> void`

- [ ] **Step 1: Write failing streaming/fade tests**

Require manager dictionaries and request arrays to use `Vector4i`, use
`candidate_members()`/`member_data()`, and exclusion-test each member transform.
Require the controller to compute:

```gdscript
outer_radius = coverage_radius + prewarm_margin
fade_start = outer_radius - edge_fade_width
edge_fade = 1.0 - smoothstep(fade_start, outer_radius, distance)
```

Require the shader instance parameter to receive the product of recycle fade
and edge fade.

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-procedural-lod.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-lod-controller.tests.ps1
```

Expected: FAIL on missing member keys and stream fade contract.

- [ ] **Step 3: Convert manager reconciliation to member keys**

Replace cell requests with `Vector4i` member keys without changing pool
capacity. `_move_cloud_to_member()` applies `member_data()["transform"]` and
`shape_offset`. `_member_is_excluded()` checks each member independently.
Preserve active keys first; order only new requests from outer to inner so
prewarm slots are prepared before they become fully visible.

- [ ] **Step 4: Add independent boundary fade**

Store `_recycle_fade` and `_edge_fade` separately in `CloudLodController`.
`set_pool_fade()` updates recycle fade; `set_edge_fade()` updates boundary fade;
one helper writes their product to both mesh instance parameters. Recompute the
edge target during the existing staggered camera-distance update and smooth it
between updates.

- [ ] **Step 5: Run tests and verify GREEN**

Run the two Task 2 tests plus cloud exclusion and world-pool tests.

- [ ] **Step 6: Commit**

```powershell
git add -- levels/components/CloudManager/CloudManager.gd levels/components/CloudManager/cloud_lod_controller.gd assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader assets/shaders/Cloud_impostor/cloud_impostor.gdshader .codex/tests/cloud-procedural-lod.tests.ps1 .codex/tests/cloud-lod-controller.tests.ps1
git commit -m "feat: prewarm and fade streamed clouds"
```

---

### Task 3: Matched LOD Lighting and Final Verification

**Files:**
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader`
- Modify: `assets/shaders/Cloud_impostor/cloud_impostor.gdshader`
- Modify: `.codex/tests/cloud-lod-shaders.tests.ps1`
- Verify: `levels/components/Environment/DayNightCycle.gd`
- Verify: `levels/components/Environment/environment_system.tscn`

**Interfaces:**
- Consumes: existing `color_light`, `color_shadow`, `volume_lod_factor`, and complementary `lod_fade`.
- Produces the same shader function signature in both shaders: `vec3 reference_lighting(float local_height)`.

- [ ] **Step 1: Write failing lighting tests**

Require both shaders to contain:

```glsl
vec3 reference_lighting(float local_height)
```

Require Volume to blend accumulated volumetric color toward reference color
using `volume_lod_factor`, and Billboard to use reference color. Reject this
incorrect order:

```glsl
physical_alpha *= pool_fade;
accum_color / max(physical_alpha, 0.001)
```

- [ ] **Step 2: Run shader tests and verify RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/cloud-lod-shaders.tests.ps1
```

Expected: FAIL on missing reference-lighting and raw-alpha contracts.

- [ ] **Step 3: Implement matched transition lighting**

In both shaders calculate the same lower-shadow/upper-highlight reference color
from normalized local height and the shared day/night color uniforms.
Billboard outputs the reference color modulated by accumulated opacity. Volume
uses existing lighting at `volume_lod_factor == 0.0` and reaches the reference
color at `volume_lod_factor == 1.0`, before dither begins.

- [ ] **Step 4: Fix pool-fade normalization**

Normalize RGB with raw `1.0 - transmittance`, then apply `pool_fade` only to
final alpha:

```glsl
float raw_alpha = 1.0 - transmittance;
vec3 final_rgb = accum_color / max(raw_alpha, 0.001);
ALPHA = raw_alpha * pool_fade;
```

- [ ] **Step 5: Run complete static suite**

Run all `.codex/tests/*.tests.ps1` except
`battle-arena-editor.tests.ps1`, because it launches the unstable Steam editor.
Run `git diff --check`.

Expected: all selected tests PASS and no whitespace errors.

- [ ] **Step 6: Manual handoff and commit**

Ask the user to test F7 flight and F10 tuning in the already-open Godot editor:
look 360 degrees, fly through a cluster, and approach the same cluster during
day and night. Commit after static verification:

```powershell
git add -- assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader assets/shaders/Cloud_impostor/cloud_impostor.gdshader .codex/tests/cloud-lod-shaders.tests.ps1
git commit -m "fix: match cloud lighting across lods"
git push origin codex/cloud-lod
```
