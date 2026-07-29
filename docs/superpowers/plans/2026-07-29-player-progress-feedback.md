# Player Progress Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a live Vabo counter beside health and a bottom-right strip that shows only unlocked abilities, including three new temporary icons.

**Architecture:** `PlayerData` remains the progression source of truth. `PlayerHUD` performs one initial sync, listens to `vabo_changed` and `ability_unlocked`, and keeps the existing player-instance polling only for Roll charges and Ground Slam cooldown. The HUD scene owns layout and textures; no progression state is duplicated in UI nodes.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` scenes, PNG UI assets, PowerShell contract tests, ImageGen.

## Global Constraints

- Do not launch Steam Godot headless from the Codex sandbox.
- Automated verification must use PowerShell tests under `.codex/tests/`.
- Runtime and visual smoke tests are performed manually in the normal Godot GUI.
- Keep `assets/textures/ui/Roll.png` and `assets/textures/ui/GroundSlam.png` unchanged.
- New ability icons must be `128x128` transparent PNGs with bold white silhouettes and no text, frame, gradient, shadow, or baked background.
- Locked abilities must be completely hidden with no empty layout slots.
- The visible Vabo name must use `ui_vabo` in `assets/translations/texts.csv`, with English and Russian values added together.
- Do not modify `Level_01` transforms or unrelated scene-generated resource values.
- After implementation, update `.codex/HANDOFF.md`, `.codex/ROADMAP.md`, and `.codex/project-index.txt`.

---

## File Map

**Create**

- `assets/textures/ui/DoubleJump.png` — temporary Double Jump indicator.
- `assets/textures/ui/AirDash.png` — temporary Air Dash indicator.
- `assets/textures/ui/Combo3Hit.png` — temporary 3-hit combo indicator.
- `.codex/tests/player-progress-feedback.tests.ps1` — static HUD, localization, asset, and documentation contract.

**Modify**

- `ui/player_hud.tscn` — Vabo row, unified ability strip, texture references.
- `ui/player_hud.gd` — initial progression sync and reactive updates.
- `assets/translations/texts.csv` — localized `ui_vabo` label.
- `.codex/HANDOFF.md` — completed work and HUD behavior.
- `.codex/ROADMAP.md` — move Player Progress Feedback to Completed.
- `.codex/project-index.txt` — include newly created project files.

**Do not modify**

- `common/autoload/player_data.gd` — its existing signals and query API are sufficient.
- `assets/textures/ui/Roll.png`
- `assets/textures/ui/GroundSlam.png`
- `levels/Level_01.tscn`

---

### Task 1: Generate and Validate the Three Missing Ability Icons

**Files:**

- Create: `assets/textures/ui/DoubleJump.png`
- Create: `assets/textures/ui/AirDash.png`
- Create: `assets/textures/ui/Combo3Hit.png`
- Reference: `assets/textures/ui/Roll.png`
- Reference: `assets/textures/ui/GroundSlam.png`

**Interfaces:**

- Consumes: the existing white-silhouette visual language in `Roll.png` and `GroundSlam.png`.
- Produces: three transparent `128x128` PNG textures loaded by `ui/player_hud.tscn`.

- [ ] **Step 1: Read the ImageGen skill and inspect both reference icons**

Read the current `imagegen` skill before generating assets. Inspect
`Roll.png` and `GroundSlam.png` at original resolution. Do not alter either
reference file.

- [ ] **Step 2: Generate `DoubleJump.png`**

Use both existing icons as visual references and generate one isolated icon
with this content:

```text
Temporary game HUD ability icon matching the supplied references: a bold,
rough-edged white silhouette on a fully transparent background. Depict Double
Jump as two distinct stacked upward impact impulses/chevrons with a compact
character-motion feel. Centered, thick readable shapes, no text, no border,
no frame, no gradient, no shadow, no color, no background. Must remain legible
at 64x64.
```

Save the selected result as
`assets/textures/ui/DoubleJump.png`. Normalize mechanically to exactly
`128x128` without adding a background.

- [ ] **Step 3: Generate `AirDash.png`**

Use both existing icons as visual references and generate one isolated icon:

```text
Temporary game HUD ability icon matching the supplied references: a bold,
rough-edged white silhouette on a fully transparent background. Depict Air
Dash as a strong horizontal airborne burst: a compact forward arrow/body
shape with two short trailing speed streaks. Centered, thick readable shapes,
no text, no border, no frame, no gradient, no shadow, no color, no background.
Must remain legible at 64x64.
```

Save the selected result as `assets/textures/ui/AirDash.png`. Normalize
mechanically to exactly `128x128` without adding a background.

- [ ] **Step 4: Generate `Combo3Hit.png`**

Use both existing icons as visual references and generate one isolated icon:

```text
Temporary game HUD ability icon matching the supplied references: a bold,
rough-edged white silhouette on a fully transparent background. Depict a
3-hit combo as three clearly separated sequential diagonal attack slashes,
increasing slightly in force from first to third. Centered, thick readable
shapes, no text or numeral, no border, no frame, no gradient, no shadow, no
color, no background. Must remain legible at 64x64.
```

Save the selected result as `assets/textures/ui/Combo3Hit.png`. Normalize
mechanically to exactly `128x128` without adding a background.

- [ ] **Step 5: Verify dimensions and alpha**

Run:

```powershell
Add-Type -AssemblyName System.Drawing
$root = 'C:\GodotProjects\zeldaclone'
foreach ($name in @('DoubleJump.png', 'AirDash.png', 'Combo3Hit.png')) {
    $path = Join-Path $root "assets\textures\ui\$name"
    $bitmap = [System.Drawing.Bitmap]::new($path)
    try {
        if ($bitmap.Width -ne 128 -or $bitmap.Height -ne 128) {
            throw "$name is not 128x128"
        }
        $hasTransparentPixel = $false
        $hasOpaquePixel = $false
        for ($y = 0; $y -lt $bitmap.Height; $y++) {
            for ($x = 0; $x -lt $bitmap.Width; $x++) {
                $alpha = $bitmap.GetPixel($x, $y).A
                if ($alpha -eq 0) { $hasTransparentPixel = $true }
                if ($alpha -gt 0) { $hasOpaquePixel = $true }
            }
        }
        if (-not $hasTransparentPixel -or -not $hasOpaquePixel) {
            throw "$name does not contain both transparent and visible pixels"
        }
    }
    finally {
        $bitmap.Dispose()
    }
}
Write-Output 'PASS: progress icons are 128x128 RGBA assets'
```

Expected: `PASS: progress icons are 128x128 RGBA assets`.

- [ ] **Step 6: Visually inspect all five icons at gameplay scale**

View the three new icons together with Roll and Ground Slam. Confirm that each
new silhouette is recognizable at `64x64`, contains no baked background, and
does not visually overpower the existing pair.

- [ ] **Step 7: Commit the icon set**

```powershell
git add -- assets/textures/ui/DoubleJump.png assets/textures/ui/AirDash.png assets/textures/ui/Combo3Hit.png
git commit -m "art: add temporary ability HUD icons"
```

---

### Task 2: Add the Failing Player Progress HUD Contract

**Files:**

- Create: `.codex/tests/player-progress-feedback.tests.ps1`
- Test: `.codex/tests/player-progress-feedback.tests.ps1`

**Interfaces:**

- Consumes: `PlayerData.vabo_changed(new_amount: int)`,
  `PlayerData.ability_unlocked(ability_name: StringName)`, and
  `PlayerData.is_ability_unlocked(ability_name: StringName) -> bool`.
- Produces: a regression contract for the HUD scene, HUD script, localization,
  icon files, roadmap, and handoff.

- [ ] **Step 1: Write the failing contract test**

Create `.codex/tests/player-progress-feedback.tests.ps1` with:

```powershell
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hudScript = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'ui\player_hud.gd'
)
$hudScene = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'ui\player_hud.tscn'
)
$translations = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot 'assets\translations\texts.csv'
)
$roadmap = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot '.codex\ROADMAP.md'
)
$handoff = Get-Content -Raw -Encoding UTF8 (
    Join-Path $projectRoot '.codex\HANDOFF.md'
)

foreach ($relativePath in @(
    'assets\textures\ui\DoubleJump.png',
    'assets\textures\ui\AirDash.png',
    'assets\textures\ui\Combo3Hit.png'
)) {
    if (-not (Test-Path (Join-Path $projectRoot $relativePath))) {
        throw "Missing progress icon: $relativePath"
    }
}

foreach ($token in @(
    '@onready var vabo_value: Label',
    '@onready var roll_container: HBoxContainer',
    '@onready var double_jump_icon: TextureRect',
    '@onready var air_dash_icon: TextureRect',
    '@onready var combo_icon: TextureRect',
    'func _connect_progress_signals() -> void',
    'PlayerData.vabo_changed.connect(_on_vabo_changed)',
    'PlayerData.ability_unlocked.connect(_on_ability_unlocked)',
    'func _sync_progress_feedback() -> void',
    'func _on_vabo_changed(new_amount: int) -> void',
    'func _on_ability_unlocked(_ability_name: StringName) -> void',
    'PlayerData.is_ability_unlocked(ability_name)',
    'if indicator is TextureRect and indicator.texture == null'
)) {
    if (-not $hudScript.Contains($token)) {
        throw "Player HUD progress contract is missing: $token"
    }
}

foreach ($token in @(
    'path="res://assets/textures/ui/DoubleJump.png"',
    'path="res://assets/textures/ui/AirDash.png"',
    'path="res://assets/textures/ui/Combo3Hit.png"',
    '[node name="HealthRow" type="HBoxContainer" parent="HealthContainer"]',
    '[node name="VaboContainer" type="HBoxContainer" parent="HealthContainer/HealthRow"]',
    '[node name="VaboValue" type="Label" parent="HealthContainer/HealthRow/VaboContainer"]',
    '[node name="AbilityStrip" type="HBoxContainer" parent="ActionsContainer"]',
    '[node name="DoubleJumpIcon" type="TextureRect" parent="ActionsContainer/AbilityStrip"]',
    '[node name="AirDashIcon" type="TextureRect" parent="ActionsContainer/AbilityStrip"]',
    '[node name="ComboIcon" type="TextureRect" parent="ActionsContainer/AbilityStrip"]',
    'text = "ui_vabo"'
)) {
    if (-not $hudScene.Contains($token)) {
        throw "Player HUD scene contract is missing: $token"
    }
}

$russianVabo = -join @(
    [char]0x0412,
    [char]0x0430,
    [char]0x0431,
    [char]0x043E
)
$vaboTranslationRow = 'ui_vabo,"Vabo","' + $russianVabo + '"'
if (-not $translations.Contains($vaboTranslationRow)) {
    throw 'Vabo localization is missing English and Russian values'
}

$completedIndex = $roadmap.IndexOf('## Completed')
$progressIndex = $roadmap.IndexOf('### Player Progress Feedback')
$nextIndex = $roadmap.IndexOf('## Next')
if (
    $completedIndex -lt 0 -or
    $progressIndex -le $completedIndex -or
    $nextIndex -le $progressIndex
) {
    throw 'Roadmap does not record Player Progress Feedback as completed'
}
if (-not $handoff.Contains('### Player Progress Feedback')) {
    throw 'Handoff does not record Player Progress Feedback'
}

Write-Output 'PASS: player progress feedback is configured'
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/player-progress-feedback.tests.ps1
```

Expected: FAIL with
`Player HUD progress contract is missing: @onready var vabo_value: Label`.

- [ ] **Step 3: Commit the red contract**

```powershell
git add -- .codex/tests/player-progress-feedback.tests.ps1
git commit -m "test: add player progress HUD contract"
```

---

### Task 3: Implement Reactive Vabo and Ability HUD Feedback

**Files:**

- Modify: `ui/player_hud.gd:5-223`
- Modify: `ui/player_hud.tscn:1-111`
- Modify: `assets/translations/texts.csv`
- Test: `.codex/tests/player-progress-feedback.tests.ps1`

**Interfaces:**

- Consumes:
  - `PlayerData.current_vabo: int`
  - `PlayerData.vabo_changed(new_amount: int)`
  - `PlayerData.ability_unlocked(ability_name: StringName)`
  - `PlayerData.is_ability_unlocked(ability_name: StringName) -> bool`
- Produces:
  - `PlayerHUD._connect_progress_signals() -> void`
  - `PlayerHUD._sync_progress_feedback() -> void`
  - `PlayerHUD._on_vabo_changed(new_amount: int) -> void`
  - `PlayerHUD._on_ability_unlocked(_ability_name: StringName) -> void`

- [ ] **Step 1: Add localized Vabo copy**

Append this row to `assets/translations/texts.csv`:

```csv
ui_vabo,"Vabo","Вабо"
```

- [ ] **Step 2: Rebuild the top-left health row in the HUD scene**

Under `HealthContainer`, replace the direct `HeartsLayout` child with:

```text
HealthContainer
└── HealthRow (HBoxContainer)
    ├── HeartsLayout (HBoxContainer)
    └── VaboContainer (HBoxContainer)
        ├── VaboLabel (Label, text = "ui_vabo")
        └── VaboValue (Label, text = "0")
```

Keep the authored top-left position. Give `VaboLabel` and `VaboValue` a
readable `24px` font size and a dark outline. Set `VaboValue` to a minimum
width of `64` and right alignment so digit changes do not move the row.

The exact scene node declarations must include:

```ini
[node name="HealthRow" type="HBoxContainer" parent="HealthContainer"]
custom_minimum_size = Vector2(320, 128)
layout_mode = 2
alignment = 1

[node name="HeartsLayout" type="HBoxContainer" parent="HealthContainer/HealthRow"]
custom_minimum_size = Vector2(128, 128)
layout_mode = 2

[node name="VaboContainer" type="HBoxContainer" parent="HealthContainer/HealthRow"]
layout_mode = 2
theme_override_constants/separation = 8
alignment = 1

[node name="VaboLabel" type="Label" parent="HealthContainer/HealthRow/VaboContainer"]
layout_mode = 2
theme_override_constants/outline_size = 4
theme_override_font_sizes/font_size = 24
text = "ui_vabo"

[node name="VaboValue" type="Label" parent="HealthContainer/HealthRow/VaboContainer"]
custom_minimum_size = Vector2(64, 0)
layout_mode = 2
theme_override_constants/outline_size = 4
theme_override_font_sizes/font_size = 24
text = "0"
horizontal_alignment = 2
```

- [ ] **Step 3: Rebuild the bottom-right actions layout**

Replace `ActionsContainer/VBoxContainer` with one horizontal
`ActionsContainer/AbilityStrip`. Keep the Roll pips as a nested
`RollContainer`, then place Double Jump, Ground Slam, Air Dash, and Combo in
the approved order.

```text
AbilityStrip
├── RollContainer
│   ├── Pip3
│   ├── Pip2
│   └── Pip1
├── DoubleJumpIcon
├── SlamIcon
├── AirDashIcon
└── ComboIcon
```

Set the three new `TextureRect` nodes to `64x64`, preserve aspect ratio, and
set `visible = false`. Set `RollContainer.visible = false` and
`SlamIcon.visible = false` in the authored scene so locked abilities never
flash for a frame. Increase the bottom-right container width to fit the full
strip without changing any level scene.

Add these scene resources:

```ini
[ext_resource type="Texture2D" path="res://assets/textures/ui/DoubleJump.png" id="6_double_jump"]
[ext_resource type="Texture2D" path="res://assets/textures/ui/AirDash.png" id="7_air_dash"]
[ext_resource type="Texture2D" path="res://assets/textures/ui/Combo3Hit.png" id="8_combo"]
```

- [ ] **Step 4: Update HUD node references**

Replace the old Roll, Slam, and hearts paths and add static icon references:

```gdscript
@onready var vabo_value: Label = \
	$HealthContainer/HealthRow/VaboContainer/VaboValue
@onready var hearts_container: HBoxContainer = \
	$HealthContainer/HealthRow/HeartsLayout
@onready var roll_container: HBoxContainer = \
	$ActionsContainer/AbilityStrip/RollContainer
@onready var double_jump_icon: TextureRect = \
	$ActionsContainer/AbilityStrip/DoubleJumpIcon
@onready var slam_bar: TextureProgressBar = \
	$ActionsContainer/AbilityStrip/SlamIcon
@onready var air_dash_icon: TextureRect = \
	$ActionsContainer/AbilityStrip/AirDashIcon
@onready var combo_icon: TextureRect = \
	$ActionsContainer/AbilityStrip/ComboIcon

@onready var pips: Array[TextureProgressBar] = [
	$ActionsContainer/AbilityStrip/RollContainer/Pip1,
	$ActionsContainer/AbilityStrip/RollContainer/Pip2,
	$ActionsContainer/AbilityStrip/RollContainer/Pip3,
]
```

- [ ] **Step 5: Connect progression signals and perform initial sync**

After the `Engine.is_editor_hint()` early return in `_ready()`, call:

```gdscript
_connect_progress_signals()
_sync_progress_feedback()
```

Add:

```gdscript
func _connect_progress_signals() -> void:
	if not PlayerData.vabo_changed.is_connected(_on_vabo_changed):
		PlayerData.vabo_changed.connect(_on_vabo_changed)
	if not PlayerData.ability_unlocked.is_connected(_on_ability_unlocked):
		PlayerData.ability_unlocked.connect(_on_ability_unlocked)


func _sync_progress_feedback() -> void:
	_on_vabo_changed(PlayerData.current_vabo)
	var indicators: Dictionary = {
		&"roll_ability": roll_container,
		&"double_jump": double_jump_icon,
		&"ground_slam": slam_bar,
		&"air_dash": air_dash_icon,
		&"3_hit_combo": combo_icon,
	}
	for ability_name: StringName in indicators:
		var indicator: Control = indicators[ability_name]
		if indicator is TextureRect and indicator.texture == null:
			indicator.visible = false
			continue
		indicator.visible = PlayerData.is_ability_unlocked(ability_name)


func _on_vabo_changed(new_amount: int) -> void:
	vabo_value.text = str(maxi(new_amount, 0))


func _on_ability_unlocked(_ability_name: StringName) -> void:
	_sync_progress_feedback()
```

This keeps unknown ability keys harmless because only the five authored keys
are queried and rendered.

- [ ] **Step 6: Preserve Roll and Ground Slam runtime behavior without gaps**

Change `_update_roll_pips()` so the whole `roll_container` is hidden or shown,
not each pip independently:

```gdscript
func _update_roll_pips() -> void:
	if not player.roll_ability or not player.roll_ability.is_unlocked:
		roll_container.visible = false
		return
	roll_container.visible = true

	var current_charges = player.current_roll_charges
	var is_penalty = player.is_roll_recharging
	# Keep the existing charge, penalty, and recharge calculations unchanged.
```

Keep `_update_slam_bar()` calculations unchanged. Its existing
`slam_bar.visible = false/true` behavior already collapses the hidden slot in
an `HBoxContainer`.

- [ ] **Step 7: Run the feature contract**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/player-progress-feedback.tests.ps1
```

Expected at this stage: FAIL because `.codex/HANDOFF.md` does not yet contain
the feature section and `.codex/ROADMAP.md` still lists the feature under
`## Next`.

- [ ] **Step 8: Run existing HUD-adjacent contracts**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/save-system-contract.tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/player-debug-flight.tests.ps1
```

Expected:

```text
PASS: PlayerData save contract is configured
PASS: player debug flight is configured
```

- [ ] **Step 9: Commit the runtime HUD implementation**

```powershell
git add -- ui/player_hud.gd ui/player_hud.tscn assets/translations/texts.csv
git commit -m "feat: show Vabo and unlocked abilities in HUD"
```

---

### Task 4: Update Persistent Handoff and Complete Verification

**Files:**

- Modify: `.codex/HANDOFF.md`
- Modify: `.codex/ROADMAP.md`
- Modify: `.codex/project-index.txt`
- Test: `.codex/tests/player-progress-feedback.tests.ps1`
- Test: `.codex/tests/update-project-index.tests.ps1`

**Interfaces:**

- Consumes: completed icon assets and HUD implementation.
- Produces: accurate entry context for future Codex chats and a clean verified
  repository state.

- [ ] **Step 1: Record the completed HUD feature in the handoff**

Add a `### Player Progress Feedback` section under confirmed working changes
in `.codex/HANDOFF.md` stating:

```markdown
### Player Progress Feedback

- HUD показывает текущие Vabo рядом со здоровьем и обновляется через
  `PlayerData.vabo_changed`.
- Справа снизу показываются только открытые способности; закрытые способности
  не оставляют пустых слотов.
- Roll сохраняет отображение зарядов, Ground Slam — cooldown.
- Для Double Jump, Air Dash и 3-hit combo добавлены временные белые PNG-иконки
  `128x128`; существующие Roll и Ground Slam не заменялись.
- Источник прогресса остаётся в `PlayerData`; HUD не хранит копию состояния.
```

Also change the “Следующий приоритет” list so the F10 Debug Panel becomes item
1 and `Level_01` completion becomes item 2.

- [ ] **Step 2: Move roadmap work to Completed**

Move the entire `### Player Progress Feedback` subsection from `## Next` into
`## Completed`. Keep `### F10 Debug Panel` as the first item under `## Next`.
Add the design link:

```markdown
Design:
`docs/superpowers/specs/2026-07-29-player-progress-feedback-design.md`.
```

- [ ] **Step 3: Regenerate the project index**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/update-project-index.ps1
```

Expected: `.codex/project-index.txt` includes
the tracked HUD paths with their canonical `UI/` casing. The compact index
does not list PNG assets or `.ps1` tests by design.

- [ ] **Step 4: Run the complete sandbox-safe non-engine test suite**

Run only the contract tests confirmed as sandbox-safe in `.codex/HANDOFF.md`.
Do not run `battle-arena-editor.tests.ps1` or
`godot-47-compat.tests.ps1`; both launch the Steam Godot executable.

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

Expected: every test prints its `PASS` result and the wrapper exits with code
`0`.

- [ ] **Step 5: Check diff integrity and repository scope**

Run:

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors; only the intended documentation and regenerated
index remain uncommitted after Tasks 1–3.

- [ ] **Step 6: Request the manual Godot GUI smoke test**

Ask the user to verify in normal GUI Godot:

1. Vabo is beside the hearts and updates on pickup.
2. Locked abilities have no visible or empty slots.
3. Each collected ability appears immediately.
4. Roll charges and Ground Slam cooldown still animate correctly.
5. All five icons remain readable and non-overlapping at the target viewport.
6. Death reload preserves session Vabo and restored ability indicators.

Do not run Steam Godot headless from Codex.

- [ ] **Step 7: Commit documentation and final verification state**

```powershell
git add -- .codex/HANDOFF.md .codex/ROADMAP.md .codex/project-index.txt
git commit -m "docs: record player progress HUD"
```

- [ ] **Step 8: Confirm final repository state**

Run:

```powershell
git status --short --branch
git log -4 --oneline
```

Expected: clean `master` worktree with four new implementation commits after
the design and plan commits.
