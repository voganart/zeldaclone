# Cloud Panel and Multi-Lobe Shape Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make live cloud tuning usable and replace tiny identical oval silhouettes with larger varied multi-lobe clouds.

**Architecture:** `CloudTuningPanel` owns a shared open-state contract that camera input respects. Both cloud shaders evaluate the same deterministic multi-lobe mask driven by per-instance seed values from `CloudTuningProfile`.

**Tech Stack:** Godot 4.7.1, typed GDScript, spatial shaders, PowerShell regression tests.

## Global Constraints

- Do not launch Godot from the terminal.
- Preserve F1-F4, F7, and F10 bindings.
- Volume and Billboard must use matching silhouette math.
- Project defaults remain saved in `cloud_tuning_profile.tres`.

---

### Task 1: Usable Compact Tuning Panel

**Files:**
- Modify: `.codex/tests/cloud-tuning-panel.tests.ps1`
- Modify: `levels/components/CloudManager/cloud_tuning_panel.gd`
- Modify: `levels/components/CloudManager/cloud_tuning_panel.tscn`
- Modify: `common/components/camera_input.gd`

**Interfaces:**
- Produces: `CloudTuningPanel.is_open() -> bool`.
- Consumes: group `cloud_tuning_panel`.

- [ ] Write a failing regression requiring camera suppression, category filtering, range-only sliders, and a panel width no greater than 650 px.
- [ ] Run the panel regression and confirm it fails on missing `is_open`.
- [ ] Add the panel to `cloud_tuning_panel`, expose `is_open`, and make `camera_input.gd` return before mouse capture/rotation while any open panel exists.
- [ ] Display only Distribution, Size & Shape, and LOD & Recycling category names.
- [ ] Create sliders only when property hint is `PROPERTY_HINT_RANGE`; keep `world_seed` as a SpinBox.
- [ ] Reduce label/input widths and panel bounds to approximately 620 x 760.
- [ ] Run panel and compatibility regressions.
- [ ] Commit with `fix: make cloud tuning panel usable`.

### Task 2: Shared Multi-Lobe Cloud Silhouette

**Files:**
- Modify: `.codex/tests/cloud-tuning-profile.tests.ps1`
- Modify: `.codex/tests/cloud-lod-shaders.tests.ps1`
- Modify: `levels/components/CloudManager/cloud_tuning_profile.gd`
- Modify: `levels/components/CloudManager/cloud_tuning_profile.tres`
- Modify: `levels/components/CloudManager/cloud_lod_controller.gd`
- Modify: `assets/shaders/Cloud_volumetric/cloud_volumetric.gdshader`
- Modify: `assets/shaders/Cloud_impostor/cloud_impostor.gdshader`

**Interfaces:**
- Produces: profile values `lobe_spread: float` and `lobe_variation: float`.
- Produces: `CloudLodController.set_lobe_shape(spread: float, variation: float)`.
- Both shaders consume instance uniforms `lobe_spread` and `lobe_variation`.

- [ ] Write failing regressions requiring new profile defaults and the same `multi_lobe_mask()` function signature in both shaders.
- [ ] Run profile/shader tests and confirm failure.
- [ ] Add and sanitize `lobe_spread` and `lobe_variation`.
- [ ] Change defaults to radius 1800, target 100, capacity 120, scale min `(100, 50, 140)`, scale max `(320, 180, 480)`, large chance 0.3, multiplier 2.0.
- [ ] Implement identical fixed-cost four-lobe mask functions in both shaders using `shape_offset` as deterministic seed.
- [ ] Replace the single sphere mask with the multi-lobe result without changing density/noise/day-night logic.
- [ ] Pass lobe values as instance shader parameters through `CloudLodController`.
- [ ] Run the full cloud regression suite.
- [ ] Commit with `feat: add varied multi-lobe cloud shapes`.

### Task 3: Verification and Push

**Files:**
- No new production files.

- [ ] Run all safe project/cloud tests and `git diff --check`.
- [ ] Commit every remaining user/generated change as requested.
- [ ] Push `codex/cloud-lod`.
- [ ] Ask the user to verify F10 dragging, default radius reset, and Volume/Billboard silhouette continuity in Godot.
