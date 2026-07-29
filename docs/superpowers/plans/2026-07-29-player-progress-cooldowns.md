# Player Progress Cooldowns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Place the Vabo counter below the hearts with an adjustable offset and make every unlocked ability indicator reflect its real runtime availability or cooldown.

**Architecture:** `PlayerData` continues to control whether an ability indicator exists. `PlayerHUD` reads live state from the current `Player` instance: jump count for Double Jump, float timers for Ground Slam and Air Dash, and the combat `Timer` for 3-hit combo. The HUD adds no gameplay timers and does not change ability balance.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` scenes, PNG UI assets, PowerShell contract tests, ImageGen.

## Global Constraints

- Work directly in `master`; do not create a branch or worktree.
- Preserve the user's committed changes in `entities/player/player.tscn`,
  `levels/Level_01.tscn`, and `UI/menus/main_menu.tscn`.
- Do not add, move, remove, or reconfigure ability chests.
- Do not change ability cooldown values or gameplay behavior.
- Do not launch Steam Godot headless from the Codex sandbox.
- Automated verification must use the sandbox-safe PowerShell contracts.
- Locked abilities must remain completely hidden with no empty layout slots.
- Vabo must appear below hearts and expose designer-controlled left/top margins.
- After implementation, update `.codex/HANDOFF.md`,
  `.codex/ROADMAP.md`, and `.codex/project-index.txt`.

---

## File Map

**Create**

- `assets/textures/ui/Vabo.png` — temporary white diamond currency marker.

**Modify**

- `.codex/tests/player-progress-feedback.tests.ps1` — follow-up layout and
  runtime-state contract.
- `UI/player_hud.tscn` — Vabo stack/offset and progress-bar node types.
- `UI/player_hud.gd` — Double Jump availability and Air Dash/combo cooldowns.
- `.codex/HANDOFF.md` — final behavior and designer adjustment points.
- `.codex/ROADMAP.md` — record cooldown feedback polish.
- `.codex/project-index.txt` — regenerate the compact project index.

**Do not modify**

- `entities/player/player.tscn`
- `levels/Level_01.tscn`
- `UI/menus/main_menu.tscn`
- `entities/player/abilities/air_dash_ability.gd`
- `entities/player/abilities/ground_slam_ability.gd`
- `common/components/combat_component.gd`
- `common/components/movement_component.gd`

---

### Task 1: Generate and Validate the Vabo Diamond Icon

**Files:**

- Create: `assets/textures/ui/Vabo.png`
- Reference: `assets/textures/ui/Roll.png`
- Reference: `assets/textures/ui/GroundSlam.png`
- Reference: `assets/textures/ui/DoubleJump.png`

**Interfaces:**

- Consumes: the current rough white-silhouette HUD style.
- Produces: one transparent `128x128` PNG loaded by `UI/player_hud.tscn`.

- [ ] **Step 1: Read the ImageGen skill and inspect the references**

Use the built-in ImageGen path. Inspect the three reference icons at original
resolution. Do not modify them.

- [ ] **Step 2: Generate the chroma-key source**

Use the reference images as style references and this prompt:

```text
Use case: stylized-concept.
Asset type: temporary game HUD currency icon.
Input images: supplied images are style references only.
Create one compact Vabo symbol: a single slightly irregular faceted diamond
silhouette, bold pure white, rough hand-cut edges matching the references,
centered with generous padding and readable at 28x28.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background.
No text, numeral, border, frame, gradient, shadow, glow, reflection, watermark,
or green inside the subject.
```

- [ ] **Step 3: Remove the chroma key and normalize the asset**

Use the installed ImageGen helper:

```powershell
& 'C:\Users\Vogan\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' `
  'C:\Users\Vogan\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py' `
  --input 'tmp\imagegen\Vabo-key.png' `
  --out 'tmp\imagegen\Vabo-alpha.png' `
  --auto-key border `
  --soft-matte `
  --transparent-threshold 12 `
  --opaque-threshold 220 `
  --despill `
  --force
```

Downscale the alpha result to exactly `128x128` RGBA with Lanczos resampling
and save it as `assets/textures/ui/Vabo.png`.

- [ ] **Step 4: Validate dimensions, alpha, and chroma fringe**

Run:

```powershell
Add-Type -AssemblyName System.Drawing
$path = 'C:\GodotProjects\zeldaclone\assets\textures\ui\Vabo.png'
$bitmap = [System.Drawing.Bitmap]::new($path)
try {
    if ($bitmap.Width -ne 128 -or $bitmap.Height -ne 128) {
        throw 'Vabo.png is not 128x128'
    }
    $transparent = 0
    $visible = 0
    $greenFringe = 0
    for ($y = 0; $y -lt 128; $y++) {
        for ($x = 0; $x -lt 128; $x++) {
            $pixel = $bitmap.GetPixel($x, $y)
            if ($pixel.A -eq 0) { $transparent++ }
            if ($pixel.A -gt 0) { $visible++ }
            if (
                $pixel.A -gt 24 -and
                $pixel.G -gt ($pixel.R + 24) -and
                $pixel.G -gt ($pixel.B + 24)
            ) {
                $greenFringe++
            }
        }
    }
    if ($transparent -eq 0 -or $visible -eq 0) {
        throw 'Vabo.png must contain transparent and visible pixels'
    }
    if ($greenFringe -ne 0) {
        throw "Vabo.png has $greenFringe visible green pixels"
    }
}
finally {
    $bitmap.Dispose()
}
Write-Output 'PASS: Vabo icon is a clean 128x128 RGBA asset'
```

Expected: `PASS: Vabo icon is a clean 128x128 RGBA asset`.

- [ ] **Step 5: Inspect at gameplay size**

View `Vabo.png` at original size and at approximately `28x28`. Confirm it is
recognizable as a diamond and does not visually overpower the ability strip.

- [ ] **Step 6: Commit the icon**

```powershell
git add -- assets/textures/ui/Vabo.png
git commit -m "art: add temporary Vabo HUD icon"
```

---

### Task 2: Extend the Player Progress Contract and Verify RED

**Files:**

- Modify: `.codex/tests/player-progress-feedback.tests.ps1`
- Test: `.codex/tests/player-progress-feedback.tests.ps1`

**Interfaces:**

- Consumes: the existing static Player Progress Feedback contract.
- Produces: regression coverage for the revised node paths, node types, and
  live-state update methods.

- [ ] **Step 1: Add the new asset requirement**

Add `assets\textures\ui\Vabo.png` to the existing icon-path loop.

- [ ] **Step 2: Replace outdated HUD script tokens**

Require these script tokens:

```powershell
foreach ($token in @(
    '@onready var vabo_value: Label',
    '$HealthContainer/HealthStack/VaboOffset/VaboContainer/VaboValue',
    '@onready var double_jump_icon: TextureRect',
    '@onready var air_dash_bar: TextureProgressBar',
    '@onready var combo_bar: TextureProgressBar',
    '@export var color_unavailable: Color',
    'func _update_double_jump_icon() -> void',
    'player.current_jump_count < 2',
    'func _update_air_dash_bar() -> void',
    'player.air_dash_ability.cooldown_timer',
    'player.air_dash_ability.air_dash_cooldown',
    'player.air_dash_ability.dash_used_in_air',
    'func _update_combo_bar() -> void',
    'player.combat_component.combo_cooldown_timer',
    'player.combat_component.combo_cooldown_after_combo',
    'func _update_cooldown_bar('
)) {
    if (-not $hudScript.Contains($token)) {
        throw "Player HUD live feedback contract is missing: $token"
    }
}
```

- [ ] **Step 3: Replace outdated scene tokens**

Require:

```powershell
foreach ($token in @(
    'path="res://assets/textures/ui/Vabo.png"',
    '[node name="HealthStack" type="VBoxContainer" parent="HealthContainer"]',
    '[node name="HeartsLayout" type="HBoxContainer" parent="HealthContainer/HealthStack"]',
    '[node name="VaboOffset" type="MarginContainer" parent="HealthContainer/HealthStack"]',
    'theme_override_constants/margin_left = 20',
    '[node name="VaboContainer" type="HBoxContainer" parent="HealthContainer/HealthStack/VaboOffset"]',
    '[node name="VaboIcon" type="TextureRect" parent="HealthContainer/HealthStack/VaboOffset/VaboContainer"]',
    '[node name="VaboValue" type="Label" parent="HealthContainer/HealthStack/VaboOffset/VaboContainer"]',
    '[node name="AirDashIcon" type="TextureProgressBar" parent="ActionsContainer/AbilityStrip"]',
    '[node name="ComboIcon" type="TextureProgressBar" parent="ActionsContainer/AbilityStrip"]'
)) {
    if (-not $hudScene.Contains($token)) {
        throw "Player HUD revised scene contract is missing: $token"
    }
}

if ($hudScene.Contains('[node name="VaboLabel"')) {
    throw 'Text Vabo label must be replaced by the diamond icon'
}
```

- [ ] **Step 4: Run the contract and verify the expected failure**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .codex/tests/player-progress-feedback.tests.ps1
```

Expected: FAIL with
`Player HUD live feedback contract is missing: $HealthContainer/HealthStack/VaboOffset/VaboContainer/VaboValue`.

- [ ] **Step 5: Commit the RED contract**

```powershell
git add -- .codex/tests/player-progress-feedback.tests.ps1
git commit -m "test: extend player ability feedback contract"
```

---

### Task 3: Implement the Revised HUD Layout and Live Feedback

**Files:**

- Modify: `UI/player_hud.tscn`
- Modify: `UI/player_hud.gd`
- Test: `.codex/tests/player-progress-feedback.tests.ps1`

**Interfaces:**

- Consumes:
  - `PlayerData.is_ability_unlocked(ability_name: StringName) -> bool`
  - `Player.current_jump_count: int`
  - `AirDashAbility.cooldown_timer: float`
  - `AirDashAbility.air_dash_cooldown: float`
  - `AirDashAbility.dash_used_in_air: bool`
  - `CombatComponent.combo_cooldown_timer: Timer`
  - `CombatComponent.combo_cooldown_after_combo: float`
- Produces:
  - `PlayerHUD._update_double_jump_icon() -> void`
  - `PlayerHUD._update_air_dash_bar() -> void`
  - `PlayerHUD._update_combo_bar() -> void`
  - `PlayerHUD._update_cooldown_bar(bar, time_left, max_time) -> void`

- [ ] **Step 1: Add the Vabo texture resource**

Add:

```ini
[ext_resource type="Texture2D" path="res://assets/textures/ui/Vabo.png" id="9_vabo"]
```

- [ ] **Step 2: Replace the health row with a vertical health stack**

Use this scene hierarchy:

```text
HealthContainer
└── HealthStack (VBoxContainer)
    ├── HeartsLayout (HBoxContainer)
    └── VaboOffset (MarginContainer)
        └── VaboContainer (HBoxContainer)
            ├── VaboIcon (TextureRect)
            └── VaboValue (Label)
```

Use these authored values as the initial designer adjustment point:

```ini
[node name="HealthStack" type="VBoxContainer" parent="HealthContainer"]
custom_minimum_size = Vector2(440, 144)
layout_mode = 2
theme_override_constants/separation = -20
alignment = 0

[node name="HeartsLayout" type="HBoxContainer" parent="HealthContainer/HealthStack"]
custom_minimum_size = Vector2(128, 96)
layout_mode = 2

[node name="VaboOffset" type="MarginContainer" parent="HealthContainer/HealthStack"]
layout_mode = 2
theme_override_constants/margin_left = 20
theme_override_constants/margin_top = 0

[node name="VaboContainer" type="HBoxContainer" parent="HealthContainer/HealthStack/VaboOffset"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="VaboIcon" type="TextureRect" parent="HealthContainer/HealthStack/VaboOffset/VaboContainer"]
custom_minimum_size = Vector2(28, 28)
layout_mode = 2
texture = ExtResource("9_vabo")
expand_mode = 1
stretch_mode = 5

[node name="VaboValue" type="Label" parent="HealthContainer/HealthStack/VaboOffset/VaboContainer"]
custom_minimum_size = Vector2(64, 28)
layout_mode = 2
theme_override_colors/font_outline_color = Color(0.02, 0.08, 0.12, 1)
theme_override_constants/outline_size = 4
theme_override_font_sizes/font_size = 24
text = "0"
vertical_alignment = 1
```

Remove `HealthRow` and `VaboLabel`. The tuning location for the designer is
`HealthContainer/HealthStack/VaboOffset`:

- `margin_left` moves Vabo horizontally;
- `margin_top` moves Vabo vertically relative to its row;
- `HealthStack.separation` changes the distance below hearts.

- [ ] **Step 3: Convert Air Dash and Combo to radial progress bars**

Keep the node names and textures but change both types:

```ini
[node name="AirDashIcon" type="TextureProgressBar" parent="ActionsContainer/AbilityStrip"]
visible = false
custom_minimum_size = Vector2(64, 64)
layout_mode = 2
max_value = 1.0
step = 0.0
value = 1.0
fill_mode = 4
nine_patch_stretch = true
texture_under = ExtResource("7_air_dash")
texture_progress = ExtResource("7_air_dash")

[node name="ComboIcon" type="TextureProgressBar" parent="ActionsContainer/AbilityStrip"]
visible = false
custom_minimum_size = Vector2(64, 64)
layout_mode = 2
max_value = 1.0
step = 0.0
value = 1.0
fill_mode = 4
nine_patch_stretch = true
texture_under = ExtResource("8_combo")
texture_progress = ExtResource("8_combo")
```

- [ ] **Step 4: Update node references and colors**

Use:

```gdscript
@onready var vabo_value: Label = \
	$HealthContainer/HealthStack/VaboOffset/VaboContainer/VaboValue
@onready var hearts_container: HBoxContainer = \
	$HealthContainer/HealthStack/HeartsLayout
@onready var air_dash_bar: TextureProgressBar = \
	$ActionsContainer/AbilityStrip/AirDashIcon
@onready var combo_bar: TextureProgressBar = \
	$ActionsContainer/AbilityStrip/ComboIcon

@export var color_unavailable: Color = Color("777777cc")
```

Replace `air_dash_icon` and `combo_icon` in the visibility map with
`air_dash_bar` and `combo_bar`.

- [ ] **Step 5: Initialize the new progress bars**

In `_ready()` after the Ground Slam setup:

```gdscript
if air_dash_bar.texture_progress:
	_setup_progress_bar(air_dash_bar, air_dash_bar.texture_progress)
if combo_bar.texture_progress:
	_setup_progress_bar(combo_bar, combo_bar.texture_progress)
```

- [ ] **Step 6: Update all live states from `_process()`**

Use:

```gdscript
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not player:
		return

	_update_roll_pips()
	_update_double_jump_icon()
	_update_slam_bar()
	_update_air_dash_bar()
	_update_combo_bar()
```

- [ ] **Step 7: Implement Double Jump ready/unavailable tint**

```gdscript
func _update_double_jump_icon() -> void:
	if not PlayerData.is_ability_unlocked(&"double_jump"):
		double_jump_icon.visible = false
		return
	double_jump_icon.visible = true
	double_jump_icon.modulate = (
		color_ready
		if player.current_jump_count < 2
		else color_unavailable
	)
```

This intentionally restores immediately when
`MovementComponent.current_jump_count` returns to `0` on landing.

- [ ] **Step 8: Add one shared radial cooldown helper**

```gdscript
func _update_cooldown_bar(
	bar: TextureProgressBar,
	time_left: float,
	max_time: float
) -> void:
	if max_time <= 0.0 or time_left <= 0.0:
		bar.value = 1.0
		bar.tint_progress = color_ready
		return
	bar.value = clampf(1.0 - (time_left / max_time), 0.0, 1.0)
	bar.tint_progress = color_recharging
```

- [ ] **Step 9: Reuse the helper for Ground Slam**

Keep the existing unlock visibility guard, then replace its timer branch with:

```gdscript
_update_cooldown_bar(
	slam_bar,
	maxf(player.ground_slam_ability.cooldown_timer, 0.0),
	player.ground_slam_ability.slam_cooldown
)
```

- [ ] **Step 10: Implement Air Dash cooldown and used-in-air state**

```gdscript
func _update_air_dash_bar() -> void:
	var ability := player.air_dash_ability
	if not ability or not ability.is_unlocked:
		air_dash_bar.visible = false
		return
	air_dash_bar.visible = true

	var time_left := maxf(ability.cooldown_timer, 0.0)
	_update_cooldown_bar(
		air_dash_bar,
		time_left,
		ability.air_dash_cooldown
	)
	if time_left <= 0.0 and ability.dash_used_in_air:
		air_dash_bar.tint_progress = color_unavailable
```

The radial fill reflects the real timer. If that timer completes before
landing, the icon remains gray until `reset_air_state()` clears
`dash_used_in_air`.

- [ ] **Step 11: Implement 3-hit combo cooldown**

```gdscript
func _update_combo_bar() -> void:
	if not PlayerData.is_ability_unlocked(&"3_hit_combo"):
		combo_bar.visible = false
		return
	combo_bar.visible = true

	var timer := player.combat_component.combo_cooldown_timer
	var time_left := 0.0 if timer.is_stopped() else timer.time_left
	_update_cooldown_bar(
		combo_bar,
		time_left,
		player.combat_component.combo_cooldown_after_combo
	)
```

- [ ] **Step 12: Run the feature contract**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .codex/tests/player-progress-feedback.tests.ps1
```

Expected: `PASS: player progress feedback is configured`.

- [ ] **Step 13: Run adjacent contracts**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .codex/tests/save-system-contract.tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .codex/tests/player-debug-flight.tests.ps1
```

Expected:

```text
PASS: PlayerData save contract is configured
PASS: debug flight controls and wheel speed are configured
```

- [ ] **Step 14: Confirm user-owned files remain untouched**

Run:

```powershell
git diff --name-only HEAD -- `
  entities/player/player.tscn `
  levels/Level_01.tscn `
  UI/menus/main_menu.tscn
```

Expected: no output.

- [ ] **Step 15: Commit the HUD implementation**

```powershell
git add -- UI/player_hud.gd UI/player_hud.tscn
git commit -m "feat: show live ability cooldown feedback"
```

---

### Task 4: Document, Verify, and Hand Off the GUI Check

**Files:**

- Modify: `.codex/HANDOFF.md`
- Modify: `.codex/ROADMAP.md`
- Modify: `.codex/project-index.txt`
- Test: `.codex/tests/player-progress-feedback.tests.ps1`

**Interfaces:**

- Consumes: the implemented layout and live feedback.
- Produces: accurate context for later Codex chats and a verified `master`.

- [ ] **Step 1: Update the handoff**

Extend `### Player Progress Feedback` with:

```markdown
- Vabo расположен отдельной строкой под сердцами; положение настраивается
  через margins узла `HealthContainer/HealthStack/VaboOffset`.
- Текст `Vabo` заменён временным белым ромбовидным символом.
- Double Jump становится серым после второго прыжка и снова белым при
  приземлении.
- Air Dash и 3-hit combo показывают круговое заполнение своих реальных
  cooldown-таймеров; новые gameplay-таймеры не добавлялись.
```

- [ ] **Step 2: Update the roadmap**

Under Completed → Player Progress Feedback, add:

```markdown
- Per-ability readiness feedback for Double Jump, Air Dash, Ground Slam,
  3-hit combo, and Roll.
- Vabo diamond marker and designer-adjustable placement below health.
```

- [ ] **Step 3: Regenerate the project index**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .codex/update-project-index.ps1
```

- [ ] **Step 4: Run all sandbox-safe contracts**

```powershell
$safeTests = @(
    'cloud-stable-noise.tests.ps1',
    'godot-47-warning-regressions.tests.ps1',
    'phantom-camera-lifecycle.tests.ps1',
    'player-debug-flight.tests.ps1',
    'player-progress-feedback.tests.ps1',
    'save-system-contract.tests.ps1',
    'update-project-index.tests.ps1'
)
foreach ($testName in $safeTests) {
    Write-Output "RUN: $testName"
    & powershell -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path '.codex/tests' $testName)
    if ($LASTEXITCODE -ne 0) {
        throw "FAILED: $testName"
    }
}
```

Expected: all seven tests exit `0`.

- [ ] **Step 5: Check repository scope**

```powershell
git diff --check
git status --short
```

Expected before the documentation commit: only handoff, roadmap, project
index, and any Godot-generated `Vabo.png.import` remain.

- [ ] **Step 6: Commit documentation and Godot import metadata**

If the open editor generated `Vabo.png.import`, include it:

```powershell
git add -- `
  .codex/HANDOFF.md `
  .codex/ROADMAP.md `
  .codex/project-index.txt `
  assets/textures/ui/Vabo.png.import
git commit -m "docs: record live ability HUD feedback"
```

If `Vabo.png.import` does not exist yet, omit only that path.

- [ ] **Step 7: Request the manual Godot GUI smoke test**

Ask the user to verify:

1. Vabo is below the hearts.
2. `VaboOffset` left/top margins move only the Vabo row.
3. The text label is replaced by a white diamond.
4. Locked abilities do not occupy layout space.
5. Double Jump turns gray after the second jump and white on landing.
6. Air Dash fills radially during `air_dash_cooldown`.
7. 3-hit combo fills radially after the third attack.
8. Roll and Ground Slam retain their previous behavior.

- [ ] **Step 8: Confirm final state**

```powershell
git status --short --branch
git log -6 --oneline
```

Expected: clean `master`, with user-owned scene commits preserved and the new
HUD commits on top.

