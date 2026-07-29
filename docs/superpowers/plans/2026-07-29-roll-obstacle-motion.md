# Roll Obstacle Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the visible physics pop when the player rolls through the low obstacle in `Level_01`.

**Architecture:** `Player` remains the only owner of `move_and_slide()`. The Roll state requests a controlled horizontal passage velocity, shrinks the gameplay capsule before forward motion, and restores the standing capsule only after a full-size clearance cast is free.

**Tech Stack:** Godot 4.7.1, GDScript, PowerShell contract tests.

## Global Constraints

- Work on `codex/fix-roll-obstacle-motion` without a worktree.
- Preserve the user's current `levels/Level_01.tscn` changes.
- Do not run Steam Godot headless; use `.codex/tests/*.tests.ps1`.
- Do not change Roll balance outside the low-passage behavior.

---

### Task 1: Lock the Roll passage physics contract

**Files:**
- Create: `.codex/tests/player-roll-obstacle.tests.ps1`
- Modify: `entities/player/player.gd`
- Modify: `entities/player/states/player_roll.gd`
- Modify: `entities/player/player.tscn`

**Interfaces:**
- Consumes: `Player.collision_shape`, `Player.shape_cast`, and the existing Roll state.
- Produces: `Player.set_roll_passage_motion(direction: Vector3, speed: float)`,
  `Player.clear_roll_passage_motion()`, and `Player.can_restore_collider() -> bool`.

- [x] **Step 1: Write the failing contract test**

The test must require:

```powershell
if ($rollState.Contains('player.move_and_slide()')) {
    throw 'Roll state must not move the CharacterBody independently'
}
```

It must also require the passage-motion API, immediate collider shrink, a
full-size `CapsuleShape3D` clearance cast, and obstacle layer mask `256`.

- [x] **Step 2: Run the test and verify RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .codex/tests/player-roll-obstacle.tests.ps1
```

Expected: FAIL because the Roll state still calls `move_and_slide()`.

- [x] **Step 3: Implement the minimal physics fix**

In `player.gd`, add one horizontal passage-motion override which is applied
before the existing single `move_and_slide()` call. Configure
`RollSafetyCast` as a standing-size capsule and expose
`can_restore_collider()`.

In `player_roll.gd`, shrink the collider in `enter()`, request passage motion
at `5.0` units/second while standing clearance is blocked, clear the request
on exit, and never call `move_and_slide()`.

Remove the obsolete `dive_entry_margin` override from `player.tscn`.

- [x] **Step 4: Run the focused test and verify GREEN**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .codex/tests/player-roll-obstacle.tests.ps1
```

Expected: `PASS: Roll obstacle passage uses one physics move and safe clearance`.

### Task 2: Verify regressions and update project handoff

**Files:**
- Modify: `.codex/HANDOFF.md`
- Modify: `.codex/ROADMAP.md`

**Interfaces:**
- Consumes: the completed Roll passage fix.
- Produces: a concise record of the implementation and manual GUI check.

- [x] **Step 1: Run all relevant PowerShell tests**

Run the new Roll test plus player progress, debug flight, save system, F10
panel, and project-index tests.

- [x] **Step 2: Update handoff and roadmap**

Mark the code fix complete and leave one manual GUI check: roll through the
rectangle collider in both directions with visible collision shapes enabled.

- [x] **Step 3: Commit only Codex-authored files**

Stage the test, player code/scene, plan, handoff, and roadmap. Do not stage
`levels/Level_01.tscn`.
