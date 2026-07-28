# Procedural Cloud LOD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the existing cloud prototype into `Full Volume -> Cheap Volume -> Procedural Volumetric Billboard` without rebuilding the cloud system or using baked atlases at runtime.

**Architecture:** Keep the current cloud scene, volume shader, LOD controller, manager, complementary dither, graphics presets, and day/night gradients. Extend them in place: the existing volume mesh changes raymarch quality by distance, while the existing `ImpostorMesh` node switches from atlas sampling to a short procedural raymarch that shares the volume noise resource and lighting colors.

**Tech Stack:** Godot 4.7.1, GDScript, spatial shaders, `NoiseTexture3D`, existing PowerShell/static tests, manual editor verification.

## Global Constraints

- Do not rewrite the cloud system from scratch.
- Preserve the tuned values in `cloud_volumetric.tres`.
- Preserve node paths `VolumetricMesh` and `ImpostorMesh`.
- Preserve the current complementary 4x4 dither transition.
- Do not delete the baker during this phase; leave it available but unused by runtime LOD.
- Do not launch Godot from the terminal because the current 4.7.1 executable has produced native access violations.
- Stage and commit only cloud-related files; unrelated user edits remain untouched.
- Treat the Low preset as the initial mobile candidate; final mobile values require device profiling after the visual transition is approved.
- This plan covers implementation stage 1 only. Infinite cell pooling and MultiMesh batching get separate plans after visual approval.

---

### Task 1: Share the Existing 3D Noise Resource

**Files:**
- Create: `assets/shaders/Cloud_volumetric/cloud_noise.tres`
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.tres`
- Test: `.codex/tests/cloud-procedural-lod.tests.ps1`

**Interfaces:**
- Produces: `res://assets/shaders/Cloud_volumetric/cloud_noise.tres`, a single `NoiseTexture3D` used by both volume and billboard materials.
- Preserves: existing FastNoiseLite values `noise_type = 2`, `frequency = 0.0004`, `fractal_type = 2`, `fractal_lacunarity = 2.468`, `fractal_gain = -0.71`, `fractal_weighted_strength = 0.27`, `cellular_distance_function = 2`, `cellular_return_type = 2`, `seamless = true`, `seamless_blend_skirt = 0.691`.

- [ ] **Step 1: Write the failing resource-sharing test**

```powershell
$noisePath = Join-Path $projectRoot 'assets/shaders/Cloud_volumetric/cloud_noise.tres'
if (-not (Test-Path -LiteralPath $noisePath)) {
    throw 'Shared cloud NoiseTexture3D is missing'
}

$volumeMaterial = Get-Content -Raw (
    Join-Path $projectRoot 'assets/shaders/Cloud_volumetric/cloud_volumetric.tres'
)
if (-not $volumeMaterial.Contains('path="res://assets/shaders/Cloud_volumetric/cloud_noise.tres"')) {
    throw 'Volume material does not use the shared cloud noise'
}
```

- [ ] **Step 2: Run the test and verify the expected failure**

Run:

```powershell
& '.\.codex\tests\cloud-procedural-lod.tests.ps1'
```

Expected: FAIL with `Shared cloud NoiseTexture3D is missing`.

- [ ] **Step 3: Extract the existing noise without changing its values**

Create `cloud_noise.tres`:

```text
[gd_resource type="NoiseTexture3D" load_steps=2 format=3]

[sub_resource type="FastNoiseLite" id="FastNoiseLite_cloud"]
noise_type = 2
frequency = 0.0004
fractal_type = 2
fractal_lacunarity = 2.468
fractal_gain = -0.71
fractal_weighted_strength = 0.27
cellular_distance_function = 2
cellular_return_type = 2

[resource]
noise = SubResource("FastNoiseLite_cloud")
seamless = true
seamless_blend_skirt = 0.691
```

Replace the embedded `FastNoiseLite` and `NoiseTexture3D` subresources in
`cloud_volumetric.tres` with:

```text
[ext_resource type="Texture3D" path="res://assets/shaders/Cloud_volumetric/cloud_noise.tres" id="2_noise"]
```

and:

```text
shader_parameter/noise_texture = ExtResource("2_noise")
```

- [ ] **Step 4: Run the test**

Run:

```powershell
& '.\.codex\tests\cloud-procedural-lod.tests.ps1'
git diff --check
```

Expected: PASS and no whitespace errors.

- [ ] **Step 5: Commit**

```powershell
git add -- '.codex/tests/cloud-procedural-lod.tests.ps1' 'assets/shaders/Cloud_volumetric/cloud_noise.tres' 'assets/shaders/Cloud_volumetric/cloud_volumetric.tres'
git commit -m "share procedural cloud noise"
```

---

### Task 2: Extend the Existing LOD Policy and Controller

**Files:**
- Modify: `levels/components/CloudManager/cloud_lod_policy.gd`
- Modify: `levels/components/CloudManager/cloud_lod_controller.gd`
- Modify: `levels/components/CloudManager/CloudManager.gd`
- Modify: `.codex/tests/cloud-lod-policy.tests.gd`
- Modify: `.codex/tests/cloud-lod-controller.tests.gd`
- Modify: `.codex/tests/cloud-editor-regression.tests.ps1`

**Interfaces:**
- Changes `CloudLodPolicy.evaluate` to:
  `evaluate(distance: float, policy: int, cheap_start: float, transition_start: float, transition_end: float) -> Dictionary`.
- Result keys remain `show_volume`, `show_impostor`, and `lod_fade`; adds `volume_lod_factor: float`.
- Changes `CloudLodController.configure_lod` to:
  `configure_lod(cheap_start_distance: float, start_distance: float, end_distance: float, local_radius: float, editor_preview_enabled: bool = true) -> void`.
- Adds `PreviewMode { AUTO, FULL_VOLUME, CHEAP_VOLUME, BILLBOARD, TRANSITION }`.

- [ ] **Step 1: Write failing policy expectations**

Add:

```gdscript
var near := policy_script.evaluate(40.0, 2, 80.0, 150.0, 210.0)
_expect_extended(near, true, false, 0.0, 0.0, "HIGH full")

var middle := policy_script.evaluate(120.0, 2, 80.0, 150.0, 210.0)
_expect_extended(middle, true, false, 0.0, 1.0, "HIGH cheap")

var blend := policy_script.evaluate(180.0, 2, 80.0, 150.0, 210.0)
_expect_extended(blend, true, true, 0.5, 1.0, "HIGH transition")

var far := policy_script.evaluate(240.0, 2, 80.0, 150.0, 210.0)
_expect_extended(far, false, true, 1.0, 1.0, "HIGH billboard")
```

Add an assertion helper that independently checks the four result values:

```gdscript
func _expect_extended(
    result: Dictionary,
    show_volume: bool,
    show_impostor: bool,
    lod_fade: float,
    volume_lod_factor: float,
    label: String
) -> void:
    if result.get("show_volume") != show_volume:
        _fail("%s: wrong volume visibility" % label)
    if result.get("show_impostor") != show_impostor:
        _fail("%s: wrong billboard visibility" % label)
    if not is_equal_approx(float(result.get("lod_fade", -1.0)), lod_fade):
        _fail("%s: wrong representation fade" % label)
    if not is_equal_approx(float(result.get("volume_lod_factor", -1.0)), volume_lod_factor):
        _fail("%s: wrong volume quality" % label)
```

- [ ] **Step 2: Run the static controller contract and confirm failure**

Run:

```powershell
& '.\.codex\tests\cloud-editor-regression.tests.ps1'
```

Expected: FAIL after adding required tokens `volume_lod_factor` and `PreviewMode`.
Do not run the GDScript test wrapper from the terminal.

- [ ] **Step 3: Extend `CloudLodPolicy.evaluate` in place**

Keep the existing quality enum and visibility behavior. Compute:

```gdscript
var volume_lod_factor := smoothstep(cheap_start, transition_start, distance)
var lod_fade := clampf(
    (distance - transition_start) / maxf(transition_end - transition_start, 0.01),
    0.0,
    1.0
)
```

Return:

```gdscript
return {
    "show_volume": lod_fade < 1.0,
    "show_impostor": lod_fade > 0.0,
    "lod_fade": lod_fade,
    "volume_lod_factor": volume_lod_factor,
}
```

Quality behavior:

```gdscript
if policy <= QualityPolicy.LOW:
    volume_lod_factor = 1.0
    cheap_start = 0.0
if policy == QualityPolicy.MEDIUM:
    volume_lod_factor = maxf(volume_lod_factor, 0.65)
```

Low quality still shows a small cheap-volume range before the billboard; it
must not hide all clouds.

- [ ] **Step 4: Extend the existing controller without replacing it**

Add exports:

```gdscript
enum PreviewMode {
    AUTO,
    FULL_VOLUME,
    CHEAP_VOLUME,
    BILLBOARD,
    TRANSITION,
}

@export_range(0.0, 10000.0, 1.0, "or_greater")
var cheap_volume_start: float = 80.0
@export var preview_mode: PreviewMode = PreviewMode.AUTO
```

In `apply_distance`, keep the existing dither parameters and add:

```gdscript
var volume_lod_factor := float(state["volume_lod_factor"])
volume_mesh.set_instance_shader_parameter(
    &"volume_lod_factor",
    volume_lod_factor
)
```

Implement preview by converting the forced mode into a deterministic distance:

```gdscript
func _preview_distance() -> float:
    match preview_mode:
        PreviewMode.FULL_VOLUME:
            return 0.0
        PreviewMode.CHEAP_VOLUME:
            return lerpf(cheap_volume_start, transition_start, 0.75)
        PreviewMode.BILLBOARD:
            return transition_end + 1.0
        PreviewMode.TRANSITION:
            return lerpf(transition_start, transition_end, 0.5)
        _:
            return _editor_preview_distance()
```

Use `_preview_distance()` only in the editor. Preserve `_distance_to_camera()`,
surface-radius compensation, GraphicsManager connection, and standalone scene
eye behavior.

- [ ] **Step 5: Pass the extra distance through the existing manager**

Add:

```gdscript
@export_range(0.0, 1000.0, 1.0, "or_greater")
var lod_cheap_volume_start: float = 80.0
```

Pass it as the first argument to the existing `_configure_cloud_lod` call.
Do not alter spawning, scales, clustering, or player-follow logic in this task.

- [ ] **Step 6: Run safe checks**

Run:

```powershell
& '.\.codex\tests\cloud-editor-regression.tests.ps1'
& '.\.codex\tests\cloud-lod-shaders.tests.ps1'
git diff --check
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add -- 'levels/components/CloudManager' '.codex/tests/cloud-lod-policy.tests.gd' '.codex/tests/cloud-lod-controller.tests.gd' '.codex/tests/cloud-editor-regression.tests.ps1'
git commit -m "extend cloud LOD states"
```

---

### Task 3: Add Adaptive Raymarch Quality to the Existing Volume Shader

**Files:**
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader`
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.tres`
- Modify: `.codex/tests/cloud-lod-shaders.tests.ps1`

**Interfaces:**
- Consumes per-instance `volume_lod_factor` from Task 2.
- Preserves uniforms `steps`, `step_size`, density controls, movement controls, colors, collision fade, and complementary dither.
- Adds material uniform `cheap_steps`.

- [ ] **Step 1: Add failing shader checks**

```powershell
foreach ($requiredToken in @(
    'instance uniform float volume_lod_factor',
    'uniform int cheap_steps',
    'active_steps'
)) {
    if (-not $volumeSource.Contains($requiredToken)) {
        throw "Cloud volume shader is missing adaptive raymarch token: $requiredToken"
    }
}
```

- [ ] **Step 2: Run the test and confirm failure**

```powershell
& '.\.codex\tests\cloud-lod-shaders.tests.ps1'
```

Expected: FAIL for `volume_lod_factor`.

- [ ] **Step 3: Extend the existing rendering group**

Add:

```glsl
uniform int cheap_steps : hint_range(4, 64) = 16;
instance uniform float volume_lod_factor : hint_range(0.0, 1.0) = 0.0;
```

Before the existing loop:

```glsl
int active_steps = int(round(mix(
    float(steps),
    float(cheap_steps),
    clamp(volume_lod_factor, 0.0, 1.0)
)));
float active_step_size = (t_end - t_start) / max(float(active_steps), 1.0);
```

Keep the existing maximum loop bound and stop at the selected count:

```glsl
for (int i = 0; i < 128; i++) {
    if (i >= active_steps || dist >= t_end || transmittance < 0.01) {
        break;
    }
    vec3 pos = ray_origin + ray_dir * dist;
    float density = get_density(pos, v_world_dist);
    if (density > 0.001) {
        float step_dens = density * active_step_size;
        float alpha = 1.0 - exp(-step_dens);
        float height_projection = dot(pos, v_local_up_dir);
        float height_factor = clamp(height_projection + 0.5, 0.0, 1.0);
        float density_factor = exp(-density * density_shadow_power);
        float light_energy =
            (density_factor * 0.5)
            + (height_factor * top_highlight_strength);
        float light_mix = smoothstep(
            shadow_threshold - shadow_softness,
            shadow_threshold + shadow_softness,
            light_energy
        );
        vec3 step_color = mix(color_shadow, color_light, light_mix);
        accum_color += step_color * alpha * transmittance;
        transmittance *= 1.0 - alpha;
    }
    dist += active_step_size;
}
```

Use `active_step_size` for the density integration and initial jitter. Do not
change the tuned density function or day/night colors.

- [ ] **Step 4: Preserve the full setting and add the cheap setting**

Keep:

```text
shader_parameter/steps = 64
```

Add:

```text
shader_parameter/cheap_steps = 16
```

- [ ] **Step 5: Run safe checks**

```powershell
& '.\.codex\tests\cloud-lod-shaders.tests.ps1'
git diff --check
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add -- 'assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader' 'assets/shaders/Cloud_volumetric/cloud_volumetric.tres' '.codex/tests/cloud-lod-shaders.tests.ps1'
git commit -m "add adaptive cloud raymarch"
```

---

### Task 4: Convert the Existing Impostor Shader to a Procedural Billboard

**Files:**
- Modify: `assets/shaders/Cloud_impostor/cloud_impostor.gdshader`
- Create: `assets/shaders/Cloud_impostor/cloud_procedural_billboard.tres`
- Modify: `assets/shaders/Cloud_volumetric/cloud.tscn`
- Modify: `.codex/tests/cloud-lod-shaders.tests.ps1`
- Modify: `.codex/tests/cloud-procedural-lod.tests.ps1`

**Interfaces:**
- Keeps the existing shader path and `ImpostorMesh` node path.
- Consumes the shared `cloud_noise.tres`.
- Keeps `lod_fade`, `lod_is_impostor`, and `lod_bayer4x4`.
- Adds `billboard_steps`, `noise_texture`, density controls, shape controls,
  movement controls, `color_light`, and `color_shadow`.

- [ ] **Step 1: Replace atlas-oriented test expectations with procedural expectations**

Require:

```powershell
foreach ($requiredToken in @(
    'uniform sampler3D noise_texture',
    'uniform int billboard_steps',
    'ray_box_intersection',
    'get_density',
    'color_light',
    'color_shadow'
)) {
    if (-not $impostorSource.Contains($requiredToken)) {
        throw "Cloud billboard shader is missing procedural token: $requiredToken"
    }
}

foreach ($forbiddenToken in @('albedo_atlas', 'atlas_frames', 'sample_atlas_frame')) {
    if ($impostorSource.Contains($forbiddenToken)) {
        throw "Runtime cloud billboard still depends on baked atlas token: $forbiddenToken"
    }
}
```

- [ ] **Step 2: Run the test and confirm failure**

```powershell
& '.\.codex\tests\cloud-lod-shaders.tests.ps1'
```

Expected: FAIL because the current shader still requires `albedo_atlas`.

- [ ] **Step 3: Reuse the existing density and dither logic**

Keep the existing billboard vertex orientation and `lod_bayer4x4`. Replace only
the atlas frame selection/sampling with:

```glsl
uniform sampler3D noise_texture : source_color;
uniform int billboard_steps : hint_range(4, 16) = 8;
uniform float cloud_scale : hint_range(0.1, 4.0) = 1.0;
uniform float density_threshold : hint_range(0.0, 1.0) = 0.2;
uniform float density_multiplier : hint_range(0.0, 20.0) = 8.0;
uniform vec3 move_speed = vec3(0.05, 0.0, 0.05);
uniform float erosion_strength : hint_range(0.0, 1.0) = 0.5;
uniform float erosion_scale : hint_range(0.01, 2.0) = 0.3;
uniform float erosion_offset_speed : hint_range(0.0, 1.0) = 0.1;
uniform float sphere_radius : hint_range(0.1, 0.75) = 0.6;
uniform float softness : hint_range(0.01, 1.0) = 0.2;
uniform vec3 color_light : source_color = vec3(1.0);
uniform vec3 color_shadow : source_color = vec3(0.25, 0.35, 0.55);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_softness : hint_range(0.01, 1.0) = 0.2;
uniform float density_shadow_power : hint_range(0.0, 5.0) = 2.0;
uniform float top_highlight_strength : hint_range(0.0, 2.0) = 1.0;
```

Copy the existing `ray_box_intersection`, density mask, erosion sampling,
detail sampling, height lighting, front-to-back accumulation, and
transmittance equations from `cloud_volumetric.gdshader`. Limit its loop:

```glsl
for (int i = 0; i < 16; i++) {
    if (i >= billboard_steps || dist >= t_end || transmittance < 0.01) {
        break;
    }
    vec3 pos = ray_origin + ray_dir * dist;
    float density = get_density(pos, v_world_dist);
    if (density > 0.001) {
        float step_dens = density * active_step_size;
        float alpha = 1.0 - exp(-step_dens);
        float height_factor = clamp(pos.y + 0.5, 0.0, 1.0);
        float density_factor = exp(-density * density_shadow_power);
        float light_energy =
            (density_factor * 0.5)
            + (height_factor * top_highlight_strength);
        float light_mix = smoothstep(
            shadow_threshold - shadow_softness,
            shadow_threshold + shadow_softness,
            light_energy
        );
        vec3 step_color = mix(color_shadow, color_light, light_mix);
        accum_color += step_color * alpha * transmittance;
        transmittance *= 1.0 - alpha;
    }
    dist += active_step_size;
}
```

The billboard shader derives scale and world center from `MODEL_MATRIX` before
replacing `MODELVIEW_MATRIX`, so its world-space noise coordinates remain
stable while the quad faces the camera.

Before the loop, compute:

```glsl
float active_step_size =
    (t_end - t_start) / max(float(billboard_steps), 1.0);
```

- [ ] **Step 4: Create an external material from current tuned values**

Create `cloud_procedural_billboard.tres` referencing the existing impostor
shader and shared 3D noise. Set:

```text
shader_parameter/billboard_steps = 8
shader_parameter/cloud_scale = 0.06700000248398
shader_parameter/density_threshold = 0.0450000021375
shader_parameter/density_multiplier = 10.946000519935
shader_parameter/move_speed = Vector3(0.05, 0.01, 0.05)
shader_parameter/erosion_strength = 0.5890000279775
shader_parameter/erosion_scale = 0.03400000091648
shader_parameter/sphere_radius = 0.60000002384186
shader_parameter/softness = 0.6620000307464801
shader_parameter/color_light = Color(1, 1, 1, 1)
shader_parameter/color_shadow = Color(0.25, 0.35, 0.55, 1)
```

- [ ] **Step 5: Rewire only the existing `ImpostorMesh`**

In `cloud.tscn`:

- remove the atlas texture external resource;
- remove the embedded atlas `ShaderMaterial`;
- reference `cloud_procedural_billboard.tres`;
- keep `ImpostorMesh`, `QuadMesh_impostor`, visibility, dither instance
  parameters, and `CloudLodController`;
- set `extra_cull_margin = 25.0`;
- set the quad size from the current cloud bounds rather than introducing
  additional child meshes.

- [ ] **Step 6: Run safe checks**

```powershell
& '.\.codex\tests\cloud-procedural-lod.tests.ps1'
& '.\.codex\tests\cloud-lod-shaders.tests.ps1'
& '.\.codex\tests\cloud-editor-regression.tests.ps1'
git diff --check
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add -- 'assets/shaders/Cloud_impostor' 'assets/shaders/Cloud_volumetric/cloud.tscn' '.codex/tests/cloud-procedural-lod.tests.ps1' '.codex/tests/cloud-lod-shaders.tests.ps1' '.codex/tests/cloud-editor-regression.tests.ps1'
git commit -m "use procedural cloud billboard"
```

---

### Task 5: Reuse Day/Night Gradients and Graphics Presets

**Files:**
- Modify: `levels/components/Environment/DayNightCycle.gd`
- Modify: `levels/components/Environment/environment_system.tscn`
- Modify: `common/autoload/graphics_manager.gd`
- Modify: `levels/components/CloudManager/cloud_lod_controller.gd`
- Modify: `.codex/tests/cloud-procedural-lod.tests.ps1`

**Interfaces:**
- Preserves `cloud_material`, `cloud_light_color`, and `cloud_shadow_color`.
- Adds `cloud_billboard_material: ShaderMaterial`.
- Both materials receive identical `color_light` and `color_shadow`.
- Graphics preset dictionaries add cloud distances and step counts; existing
  `quality_changed(settings: Dictionary)` remains the delivery mechanism.

- [ ] **Step 1: Add failing day/night and quality contract checks**

```powershell
$dayNight = Get-Content -Raw (
    Join-Path $projectRoot 'levels/components/Environment/DayNightCycle.gd'
)
foreach ($token in @(
    'cloud_billboard_material',
    '_apply_cloud_colors',
    'cloud_light_color.sample(sample_pos)',
    'cloud_shadow_color.sample(sample_pos)'
)) {
    if (-not $dayNight.Contains($token)) {
        throw "Day/night cloud integration is missing: $token"
    }
}

$graphics = Get-Content -Raw (
    Join-Path $projectRoot 'common/autoload/graphics_manager.gd'
)
foreach ($token in @(
    '"cloud_cheap_start"',
    '"cloud_transition_start"',
    '"cloud_transition_end"',
    '"cloud_full_steps"',
    '"cloud_cheap_steps"',
    '"cloud_billboard_steps"'
)) {
    if (-not $graphics.Contains($token)) {
        throw "Cloud quality preset is missing: $token"
    }
}
```

- [ ] **Step 2: Run the test and confirm failure**

```powershell
& '.\.codex\tests\cloud-procedural-lod.tests.ps1'
```

Expected: FAIL for `cloud_billboard_material`.

- [ ] **Step 3: Apply existing gradients to both materials**

Add:

```gdscript
@export var cloud_billboard_material: ShaderMaterial
```

Extract the current cloud update without changing gradient sampling:

```gdscript
func _apply_cloud_colors(material: ShaderMaterial, sample_pos: float) -> void:
    if material == null:
        return
    if cloud_light_color:
        material.set_shader_parameter(
            "color_light",
            cloud_light_color.sample(sample_pos)
        )
    if cloud_shadow_color:
        material.set_shader_parameter(
            "color_shadow",
            cloud_shadow_color.sample(sample_pos)
        )
```

Replace the current single-material block with:

```gdscript
_apply_cloud_colors(cloud_material, sample_pos)
_apply_cloud_colors(cloud_billboard_material, sample_pos)
```

Assign the external billboard material in `environment_system.tscn`.

- [ ] **Step 4: Extend existing graphics presets**

Add exact initial values:

```gdscript
# LOW
"cloud_cheap_start": 0.0,
"cloud_transition_start": 45.0,
"cloud_transition_end": 75.0,
"cloud_full_steps": 20,
"cloud_cheap_steps": 8,
"cloud_billboard_steps": 5,

# MEDIUM
"cloud_cheap_start": 55.0,
"cloud_transition_start": 110.0,
"cloud_transition_end": 165.0,
"cloud_full_steps": 36,
"cloud_cheap_steps": 12,
"cloud_billboard_steps": 6,

# HIGH
"cloud_cheap_start": 80.0,
"cloud_transition_start": 150.0,
"cloud_transition_end": 210.0,
"cloud_full_steps": 64,
"cloud_cheap_steps": 16,
"cloud_billboard_steps": 8,
```

In `_on_graphics_quality_changed`, keep `cloud_quality` and read the new keys.
Update controller distances. Set `steps` and `cheap_steps` on the existing
volume material and `billboard_steps` on the existing billboard material.
Because the materials are shared resources, update only when quality changes,
not once per frame.

- [ ] **Step 5: Run safe checks**

```powershell
& '.\.codex\tests\cloud-procedural-lod.tests.ps1'
& '.\.codex\tests\cloud-lod-shaders.tests.ps1'
git diff --check
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add -- 'levels/components/Environment/DayNightCycle.gd' 'levels/components/Environment/environment_system.tscn' 'common/autoload/graphics_manager.gd' 'levels/components/CloudManager/cloud_lod_controller.gd' '.codex/tests/cloud-procedural-lod.tests.ps1'
git commit -m "sync cloud LOD lighting and quality"
```

---

### Task 6: Static Verification and Manual Visual Checkpoint

**Files:**
- Modify only if a check exposes a cloud-specific defect.

**Interfaces:**
- Produces the first reviewable LOD implementation.
- Does not implement the infinite cell pool or MultiMesh.

- [ ] **Step 1: Run all safe static cloud checks**

```powershell
& '.\.codex\tests\cloud-editor-regression.tests.ps1'
& '.\.codex\tests\cloud-impostor-baker.tests.ps1'
& '.\.codex\tests\cloud-impostor-math.tests.ps1'
& '.\.codex\tests\cloud-lod-shaders.tests.ps1'
& '.\.codex\tests\cloud-procedural-lod.tests.ps1'
git diff --check
```

Expected: all commands exit `0`.

- [ ] **Step 2: Verify staged scope before any final commit**

```powershell
git status -sb
git diff --name-only
git diff --cached --name-only
```

Expected: no unrelated files are staged.

- [ ] **Step 3: Ask the user to test in the Godot GUI**

Manual sequence:

1. Restart Godot or reload changed scripts.
2. Open `assets/shaders/Cloud_volumetric/cloud.tscn`.
3. Select root `Cloud`.
4. Test `Preview Mode`: `Full Volume`, `Cheap Volume`, `Transition`,
   `Billboard`.
5. Open `levels/Level_01.tscn` and run the game.
6. Press F1, F2, and F3 and compare cloud coverage and transition distances.
7. Scrub `EnvironmentSystem.time_of_day` through midnight, sunrise, noon, and
   sunset.
8. Rotate the camera at the transition range and record whether the billboard
   edge, scale, or color jumps.

- [ ] **Step 4: Apply only parameter corrections from the visual checkpoint**

Allowed without architecture change:

- `cloud_cheap_start`;
- `cloud_transition_start`;
- `cloud_transition_end`;
- full, cheap, and billboard step counts;
- billboard quad size;
- `extra_cull_margin`;
- shared density, erosion, softness, and color parameters.

Any shape mismatch that requires a new representation returns to design review
instead of adding another temporary mesh.

- [ ] **Step 5: Re-run safe checks and commit parameter corrections**

```powershell
& '.\.codex\tests\cloud-editor-regression.tests.ps1'
& '.\.codex\tests\cloud-lod-shaders.tests.ps1'
& '.\.codex\tests\cloud-procedural-lod.tests.ps1'
git diff --check
git add -- 'assets/shaders/Cloud_volumetric' 'assets/shaders/Cloud_impostor' 'levels/components/CloudManager' 'levels/components/Environment' 'common/autoload/graphics_manager.gd' '.codex/tests'
git commit -m "tune procedural cloud transitions"
```

- [ ] **Step 6: Push the checkpoint branch**

```powershell
git push origin codex/cloud-lod
```

Expected: `codex/cloud-lod` updated successfully.
