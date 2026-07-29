# Roll Low Passage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace forced Roll obstacle motion with an input-driven low-passage state that safely supports ceilings of any length.

**Architecture:** `PlayerRoll` remains a finite root-motion action and selects either `Move` or `LowPassage` when it ends. `PlayerLowPassage` is a non-root-motion state that keeps the reduced capsule, applies slow input movement, loops the existing crouched Roll animation, and returns to normal movement only when the full standing capsule fits.

**Tech Stack:** Godot 4.7, GDScript, CharacterBody3D, AnimationTree, PowerShell contract tests.

## Global Constraints

- Work directly in `codex/fix-roll-obstacle-motion`; do not create a worktree.
- Do not modify `levels/Level_01.tscn`.
- Preserve unrelated user changes already present in `entities/player/player.tscn`.
- Keep exactly one normal `move_and_slide()` call in the shared player physics path.
- Do not use forced ejection, teleportation, or collision tunneling.
- Update `.codex/HANDOFF.md` and `.codex/ROADMAP.md` after the implementation task.

---

### Task 1: Define the Low-Passage State Contract

**Files:**
- Modify: `.codex/tests/player-roll-obstacle.tests.ps1`
- Test: `.codex/tests/player-roll-obstacle.tests.ps1`

**Interfaces:**
- Consumes: current player state scripts and `entities/player/player.tscn`.
- Produces: a failing executable contract for the `LowPassage` state and the removal of forced passage motion.

- [ ] **Step 1: Replace the obsolete forced-motion assertions**

Add checks that load the real project files and require:

```powershell
$lowPassagePath = Join-Path $projectRoot "entities/player/states/player_low_passage.gd"
Assert-True (Test-Path $lowPassagePath) "PlayerLowPassage state script must exist"

$constants = Get-Content (Join-Path $projectRoot "common/autoload/game_constants.gd") -Raw
$roll = Get-Content (Join-Path $projectRoot "entities/player/states/player_roll.gd") -Raw
$player = Get-Content (Join-Path $projectRoot "entities/player/player.gd") -Raw
$scene = Get-Content (Join-Path $projectRoot "entities/player/player.tscn") -Raw

Assert-Match $constants 'const STATE_LOW_PASSAGE = "lowpassage"' "LowPassage constant"
Assert-Match $roll 'STATE_LOW_PASSAGE' "Roll routes blocked stand-up to LowPassage"
Assert-Match $scene '\[node name="LowPassage".*parent="StateMachine"' "LowPassage scene node"
Assert-NotMatch $player 'roll_passage_motion_active' "Forced passage motion is removed"
Assert-NotMatch $roll 'passage_speed' "Roll no longer owns an escape speed"
```

Once the file exists, also require the low-passage script to use
`get_movement_vector()`, `apply_movement_velocity()`, `can_restore_collider()`,
and `STATE_MOVE`, and verify it does not grant invulnerability.

- [ ] **Step 2: Run the contract and verify RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/player-roll-obstacle.tests.ps1
```

Expected: FAIL because `player_low_passage.gd`, `STATE_LOW_PASSAGE`, and the
`LowPassage` scene node do not exist and forced passage motion still exists.

- [ ] **Step 3: Do not commit the failing test alone**

Keep the failing test in the working tree for the implementation cycle.

---

### Task 2: Implement Physical Low-Passage Movement

**Files:**
- Create: `entities/player/states/player_low_passage.gd`
- Modify: `entities/player/states/player_roll.gd`
- Modify: `entities/player/player.gd`
- Modify: `common/autoload/game_constants.gd`
- Modify: `common/components/animation_controller.gd`
- Modify: `entities/player/player.tscn`
- Test: `.codex/tests/player-roll-obstacle.tests.ps1`

**Interfaces:**
- Consumes:
  - `Player.can_restore_collider() -> bool`
  - `Player.shrink_collider() -> void`
  - `Player.restore_collider() -> void`
  - `Player.apply_movement_velocity(delta: float, input_dir: Vector2, target_speed: float) -> void`
  - `AnimationController.set_crouch_state(is_crouching: bool) -> void`
- Produces:
  - `GameConstants.STATE_LOW_PASSAGE: String`
  - `AnimationController.set_playback_speed(speed: float) -> void`
  - a `StateMachine/LowPassage` node backed by `player_low_passage.gd`.

- [ ] **Step 1: Add the state constant and animation speed API**

Add:

```gdscript
const STATE_LOW_PASSAGE = "lowpassage"
```

In `AnimationController`, retain the default playback speed and expose:

```gdscript
func set_playback_speed(speed: float) -> void:
	if not anim_tree:
		return
	anim_tree.set(P_CROUCH_SPEED, maxf(speed, 0.0))
```

Add an `AnimationNodeTimeScale` named `CrouchSpeed` between
`Roll_crouch_loop` and the crouched input of `CrouchState`. This keeps the
speed change local to the low-passage loop instead of changing the linked
`AnimationPlayer` globally.

- [ ] **Step 2: Create `PlayerLowPassage`**

Implement:

```gdscript
extends State

var player: Player

@export var movement_speed: float = 1.5
@export_range(0.1, 1.0) var animation_speed: float = 0.55

func enter() -> void:
	player = entity as Player
	player.is_rolling = false
	player.is_invincible = false
	player.shrink_collider()
	player.anim_controller.set_crouch_state(true)
	player.anim_controller.set_playback_speed(animation_speed)
	if player.shape_cast:
		player.shape_cast.enabled = true

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	if player.can_restore_collider():
		player.restore_collider()
		transitioned.emit(
			self,
			GameConstants.STATE_MOVE if player.is_on_floor() else GameConstants.STATE_AIR
		)
		return

	var input_vec := player.get_movement_vector()
	player.apply_movement_velocity(delta, input_vec, movement_speed)
	player.rot_char(delta)
	player.tilt_character(delta)

func exit() -> void:
	player.anim_controller.set_playback_speed(1.0)
	if player.can_restore_collider():
		player.restore_collider()
		player.anim_controller.set_crouch_state(false)
	if player.shape_cast:
		player.shape_cast.enabled = false
```

Do not read jump, attack, or Roll actions in this state.

- [ ] **Step 3: Make Roll choose its exit state**

Remove `passage_speed`, `fixed_roll_direction`, `is_stuck_under_roof`, and all
calls to `set_roll_passage_motion()`/`clear_roll_passage_motion()`.

At normal Roll completion:

```gdscript
if player.can_restore_collider():
	player.restore_collider()
	is_collider_shrunk = false
	transitioned.emit(self, GameConstants.STATE_MOVE)
else:
	transitioned.emit(self, GameConstants.STATE_LOW_PASSAGE)
```

Permit jump and attack cancellation only when `player.can_restore_collider()`
is true. Keep Roll invulnerability and root motion unchanged before completion.

- [ ] **Step 4: Remove the rejected forced-motion path**

Delete from `Player`:

```gdscript
var roll_passage_motion_active: bool
var roll_passage_velocity: Vector3
func set_roll_passage_motion(...)
func clear_roll_passage_motion()
```

Delete the velocity override guarded by `roll_passage_motion_active`. Do not
change the shared `move_and_slide()` structure.

- [ ] **Step 5: Register the state in `player.tscn`**

Add an external script resource for
`res://entities/player/states/player_low_passage.gd`, then add:

```text
[node name="LowPassage" type="Node" parent="StateMachine"]
script = ExtResource("<new low-passage resource id>")
```

Do not alter any animated skeleton transforms or `Level_01`.

- [ ] **Step 6: Run the focused contract and verify GREEN**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/player-roll-obstacle.tests.ps1
```

Expected: PASS.

- [ ] **Step 7: Commit the gameplay change**

Stage only the test, scripts, constants, controller, and the intended
`player.tscn` hunks. Exclude unrelated scene transform changes.

Commit:

```powershell
git commit -m "fix: add controllable roll low passage"
```

---

### Task 3: Regression Checks and Handoff

**Files:**
- Modify: `.codex/HANDOFF.md`
- Modify: `.codex/ROADMAP.md`
- Test: `.codex/tests/player-roll-obstacle.tests.ps1`
- Test: `.codex/tests/godot-47-warning-regressions.tests.ps1`

**Interfaces:**
- Consumes: completed low-passage implementation.
- Produces: verified static contracts and concise GUI smoke-test instructions.

- [ ] **Step 1: Run relevant non-engine checks**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/player-roll-obstacle.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/godot-47-warning-regressions.tests.ps1
git diff --check
```

Expected: both focused checks pass and `git diff --check` reports no new
whitespace errors in implementation files.

- [ ] **Step 2: Update handoff and roadmap**

Record:

- the new `PlayerLowPassage` flow;
- tunables `movement_speed = 1.5` and `animation_speed = 0.55`;
- that the user must GUI-test both exit directions, idle under the ceiling,
  reversing direction, and a temporarily extended obstacle;
- that `Level_01.tscn` and unrelated `player.tscn` transforms were preserved.

- [ ] **Step 3: Commit documentation**

Stage only `.codex/HANDOFF.md` and `.codex/ROADMAP.md`.

Commit:

```powershell
git commit -m "docs: record roll low passage verification"
```

---

### Task 4: Phase-Gated Standing Exit

**Files:**
- Modify: `entities/player/states/player_low_passage.gd`
- Modify: `common/autoload/game_constants.gd`
- Modify: `.codex/tests/player-roll-obstacle.tests.ps1`

**Interfaces:**
- Consumes: `Boy_roll_crouch` animation length and standing clearance query.
- Produces: stable-clearance and safe-phase gating before standing.

- [x] Add a failing contract for clearance hold and safe loop phase.
- [x] Track loop time using the configured low-passage animation speed.
- [x] Require `0.1` seconds of continuous clearance.
- [x] Exit only within `0.12` normalized phase of the loop boundary.
- [x] Recheck standing clearance immediately before restoring the collider.
- [x] Run focused Roll and Godot 4.7 compatibility contracts.
