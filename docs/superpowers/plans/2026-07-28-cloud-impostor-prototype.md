# Cloud Impostor Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Создать Godot 4.7-native прототип одного cloud archetype с octahedral atlas, стабильным dither-переходом LOD0 → LOD1 и ручным GPU bake из редактора.

**Architecture:** Чистый `CloudLodPolicy` рассчитывает режим и fade без зависимости от сцены. `CloudLodController` применяет результат к volume/impostor meshes. Editor-only baker рендерит 8×8 hemispherical views исходного volume cloud в один RGBA atlas; первый slice не запекает depth.

**Tech Stack:** Godot 4.7.1, GDScript, spatial shaders, SubViewport, PowerShell regression tests.

## Global Constraints

- Не изменять пользовательские правки в `BattleArena.tscn`, `cloud.tscn` и `cloud_volumetric.tres` без точечного объединения.
- LOW использует только sky noise; MEDIUM — impostor + sky noise; HIGH — volume + impostor + sky noise.
- Первый slice работает с одной формой облака и не добавляет сторонний Godot 3 plugin.
- GPU bake и визуальный переход подтверждает пользователь в GUI Godot.

---

### Task 1: Testable LOD Policy

**Files:**
- Create: `levels/components/CloudManager/cloud_lod_policy.gd`
- Create: `.codex/tests/cloud-lod-policy.tests.gd`
- Create: `.codex/tests/cloud-lod-policy.tests.ps1`

**Interfaces:**
- Produces: `CloudLodPolicy.evaluate(distance: float, policy: int, transition_start: float, transition_end: float) -> Dictionary`
- Result keys: `show_volume: bool`, `show_impostor: bool`, `lod_fade: float`.

- [ ] Write a failing Godot test with literal expectations for HIGH at 100/150/200 m, MEDIUM and LOW.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/cloud-lod-policy.tests.ps1`; expect failure because `cloud_lod_policy.gd` does not exist.
- [ ] Implement the minimal pure policy class and clamp invalid transition ranges.
- [ ] Re-run the focused test and existing compatibility test; expect PASS.
- [ ] Commit only Task 1 files.

### Task 2: Complementary Dither Runtime

**Files:**
- Create: `levels/components/CloudManager/cloud_lod_controller.gd`
- Create: `.codex/tests/cloud-lod-controller.tests.gd`
- Create: `.codex/tests/cloud-lod-controller.tests.ps1`
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader`
- Create: `assets/shaders/Cloud_impostor/cloud_impostor.gdshader`

**Interfaces:**
- Consumes: `CloudLodPolicy.evaluate(...)`.
- Produces: `CloudLodController.apply_distance(distance: float) -> void`.
- Shader contract: `instance uniform float lod_fade`, complementary `instance uniform bool lod_is_impostor`.

- [ ] Write a failing scene test that supplies two real `MeshInstance3D` nodes and verifies visibility and per-instance fade at 100/150/200 m.
- [ ] Run the focused controller test; expect failure because controller is missing.
- [ ] Implement controller with exported paths and no node recreation.
- [ ] Add the same static 4×4 Bayer function to both shaders. Volume discards the pixels transferred to impostor; impostor keeps only those pixels.
- [ ] Run focused tests and headless project load; expect PASS with no parse errors.
- [ ] Commit Task 2 without staging unrelated resource changes.

### Task 3: One-Archetype Editor Baker

**Files:**
- Create: `addons/cloud_impostor_baker/plugin.cfg`
- Create: `addons/cloud_impostor_baker/plugin.gd`
- Create: `addons/cloud_impostor_baker/cloud_impostor_baker.gd`
- Create: `assets/shaders/Cloud_impostor/cloud_impostor_bake.tscn`
- Create after GUI bake: `assets/shaders/Cloud_impostor/generated/cloud_01_albedo.png`
- Modify by careful merge: `assets/shaders/Cloud_volumetric/cloud.tscn`

**Interfaces:**
- Consumes: selected `Cloud` node containing `VolumetricMesh`.
- Produces: 8×8, 2048×2048 RGBA atlas and an `ImpostorMesh` child using `cloud_impostor.gdshader`.

- [ ] Write failing pure tests for hemispherical grid directions at atlas corners and center.
- [ ] Run the direction tests; expect failure because baker math is missing.
- [ ] Port only `octa_hemisphere_enc()` and atlas layout from the MIT reference to Godot 4.7.
- [ ] Implement editor button `Bake Cloud Impostor`; render 64 duplicated volume meshes through an orthographic `SubViewport`, wait for `RenderingServer.frame_post_draw`, save PNG, then stop viewport updates.
- [ ] Run headless parse checks; expect PASS.
- [ ] Ask the user to select one cloud and press `Bake Cloud Impostor`.
- [ ] After the generated atlas exists, merge `ImpostorMesh` into `cloud.tscn` while preserving the user's local resource tuning.
- [ ] Ask the user to move the camera through 100–200 m and report silhouette mismatch, flicker and brightness jump.
- [ ] Commit only after the visual checkpoint passes.

## Deferred Until Prototype Approval

- Depth atlas and parallax frame blending.
- Multiple cloud archetypes.
- `MultiMesh` buckets for thousands of impostors.
- GraphicsManager LOW/MEDIUM/HIGH integration.
- WorldEnvironment LOD2 and full day/night synchronization.
