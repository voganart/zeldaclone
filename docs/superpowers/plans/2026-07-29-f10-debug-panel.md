# F10 Debug Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a compact debug-only F10 panel for resetting saves and testing player, progression, and checkpoint state.

**Architecture:** Register a debug-gated `DebugTools` autoload that owns a separate `CanvasLayer` panel and coordinates existing gameplay services. Add small public progression setters to `PlayerData`, refresh runtime player/HUD state through a generic ability-state signal, and gate player input while the panel is open.

**Tech Stack:** Godot 4.7, GDScript, `.tscn` UI scenes, CSV localization, PowerShell contract tests.

## Global Constraints

- Work directly in `master`; do not create a branch or worktree.
- The panel is approximately `320 px` wide, left anchored, and has no fullscreen dimmer.
- Opening the panel does not pause gameplay.
- Gameplay input is blocked while the panel is open.
- Debug tools do not initialize in release exports.
- All visible copy is localized in English and Russian.
- Do not change player balance, level transforms, or user-authored scene placement.
- Do not run Steam Godot headless from the Codex sandbox.
- Update `.codex/HANDOFF.md`, `.codex/ROADMAP.md`, and the project index after implementation.

---

### Task 1: Runtime Progression Debug API

**Files:**
- Create: `.codex/tests/f10-debug-panel.tests.ps1`
- Modify: `common/autoload/player_data.gd`
- Modify: `entities/player/player.gd`
- Modify: `ui/player_hud.gd`

**Interfaces:**
- Produces: `PlayerData.set_vabo(amount: int) -> bool`
- Produces: `PlayerData.set_ability_unlocked(ability_name: StringName, unlocked: bool) -> bool`
- Produces: `PlayerData.ability_state_changed(ability_name: StringName, unlocked: bool)`
- Produces: `Player.refresh_progression_from_player_data() -> void`
- Consumes: existing `PlayerData.vabo_changed`, `PlayerData.unlock_ability()`, and `Player._apply_unlocks()`

- [ ] **Step 1: Write the failing progression contract**

Create `.codex/tests/f10-debug-panel.tests.ps1` with UTF-8 reads for the four
production files. Assert these literal contracts:

```powershell
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Read-ProjectFile([string]$relativePath) {
    Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot $relativePath)
}

$playerData = Read-ProjectFile 'common\autoload\player_data.gd'
$player = Read-ProjectFile 'entities\player\player.gd'
$hud = Read-ProjectFile 'ui\player_hud.gd'

foreach ($token in @(
    'signal ability_state_changed(',
    'func set_vabo(amount: int) -> bool:',
    'func set_ability_unlocked(',
    'ability_state_changed.emit(ability_name, unlocked)'
)) {
    if (-not $playerData.Contains($token)) {
        throw "PlayerData debug contract is missing: $token"
    }
}

if (-not $player.Contains(
    'func refresh_progression_from_player_data() -> void:'
)) {
    throw 'Player progression refresh API is missing'
}

if (-not $hud.Contains(
    'PlayerData.ability_state_changed.connect(_on_ability_state_changed)'
)) {
    throw 'HUD does not observe ability lock/unlock changes'
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/f10-debug-panel.tests.ps1
```

Expected: FAIL on missing `ability_state_changed`.

- [ ] **Step 3: Implement public progression setters**

In `common/autoload/player_data.gd`, add:

```gdscript
signal ability_state_changed(
	ability_name: StringName,
	unlocked: bool
)


func set_vabo(amount: int) -> bool:
	var normalized_amount := maxi(amount, 0)
	if normalized_amount == current_vabo:
		return false
	current_vabo = normalized_amount
	vabo_changed.emit(current_vabo)
	return true


func set_ability_unlocked(
	ability_name: StringName,
	unlocked: bool
) -> bool:
	var key := String(ability_name)
	if not abilities.has(key) or bool(abilities[key]) == unlocked:
		return false
	abilities[key] = unlocked
	if unlocked:
		ability_unlocked.emit(ability_name)
	ability_state_changed.emit(ability_name, unlocked)
	return true
```

Change `add_vabo()` to call `set_vabo(current_vabo + amount)`. Change
`unlock_ability()` to return `set_ability_unlocked(ability_name, true)`.

In `entities/player/player.gd`, add:

```gdscript
func refresh_progression_from_player_data() -> void:
	_apply_unlocks()
```

In `ui/player_hud.gd`, connect the generic signal beside existing progression
signals:

```gdscript
if not PlayerData.ability_state_changed.is_connected(
	_on_ability_state_changed
):
	PlayerData.ability_state_changed.connect(_on_ability_state_changed)


func _on_ability_state_changed(
	_ability_name: StringName,
	_unlocked: bool
) -> void:
	_sync_progress_feedback()
```

- [ ] **Step 4: Run the progression contract**

Run the Task 1 test. Expected: PASS.

- [ ] **Step 5: Run save and HUD regressions**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/save-system-contract.tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/player-progress-feedback.tests.ps1
```

Expected: both PASS.

- [ ] **Step 6: Commit**

```powershell
git add -- .codex/tests/f10-debug-panel.tests.ps1 common/autoload/player_data.gd entities/player/player.gd ui/player_hud.gd
git commit -m "feat: expose runtime progression debug controls"
```

---

### Task 2: DebugTools Controller and Gameplay Input Gate

**Files:**
- Create: `common/autoload/debug_tools.gd`
- Modify: `common/autoload/game_constants.gd`
- Modify: `entities/player/components/input_handler.gd`
- Modify: `entities/player/player.gd`
- Modify: `project.godot`
- Modify: `.codex/tests/f10-debug-panel.tests.ps1`

**Interfaces:**
- Consumes: Task 1 progression setters and `Player.refresh_progression_from_player_data()`
- Produces: `DebugTools.is_gameplay_input_blocked() -> bool`
- Produces: `DebugTools.set_panel_open(value: bool) -> void`
- Produces: action methods `reset_save_and_reload`, `restore_health`, `set_vabo`, `set_all_abilities`, `teleport_to_checkpoint`, and `reload_level`

- [ ] **Step 1: Extend the contract and verify RED**

Add assertions for:

```powershell
$debugTools = Read-ProjectFile 'common\autoload\debug_tools.gd'
$inputHandler = Read-ProjectFile 'entities\player\components\input_handler.gd'
$project = Read-ProjectFile 'project.godot'

foreach ($token in @(
    'DebugTools="*res://common/autoload/debug_tools.gd"',
    'debug_panel_toggle={',
    'physical_keycode":4194341'
)) {
    if (-not $project.Contains($token)) {
        throw "Project debug-panel contract is missing: $token"
    }
}

foreach ($token in @(
    'if not OS.is_debug_build():',
    'func is_gameplay_input_blocked() -> bool:',
    'func reset_save_and_reload()',
    'func restore_health() -> bool:',
    'func set_all_abilities(unlocked: bool) -> void:',
    'func teleport_to_checkpoint() -> bool:',
    'func reload_level()'
)) {
    if (-not $debugTools.Contains($token)) {
        throw "DebugTools contract is missing: $token"
    }
}

if (-not $inputHandler.Contains(
    'DebugTools.is_gameplay_input_blocked()'
)) {
    throw 'Player input is not blocked by the debug panel'
}
```

Run the contract. Expected: FAIL because `debug_tools.gd` is missing.

- [ ] **Step 2: Add input action and autoload**

In `GameConstants`, add:

```gdscript
const INPUT_DEBUG_PANEL_TOGGLE = "debug_panel_toggle"
```

In `project.godot`, register `DebugTools` after `SaveManager`, and add
`debug_panel_toggle` with physical keycode `4194341` (`F10`), matching the
existing input-map serialization format.

- [ ] **Step 3: Implement the debug controller**

Create `common/autoload/debug_tools.gd` with:

```gdscript
extends Node

const PANEL_SCENE := preload("res://ui/debug_panel/debug_panel.tscn")
const ABILITY_NAMES: Array[StringName] = [
	&"roll_ability",
	&"double_jump",
	&"ground_slam",
	&"air_dash",
	&"3_hit_combo",
]

var _panel: CanvasLayer
var _debug_enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_debug_enabled = OS.is_debug_build()
	if not _debug_enabled:
		set_process_input(false)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(
		GameConstants.INPUT_DEBUG_PANEL_TOGGLE
	):
		return
	if not is_gameplay_input_blocked() and not _get_player():
		return
	set_panel_open(not is_gameplay_input_blocked())
	get_viewport().set_input_as_handled()


func is_gameplay_input_blocked() -> bool:
	return (
		_debug_enabled
		and is_instance_valid(_panel)
		and _panel.visible
	)
```

`set_panel_open()` lazily instantiates `PANEL_SCENE`, adds it to the autoload,
and forwards `set_open(value)` to the panel.

Implement actions with these exact boundaries:

```gdscript
func restore_health() -> bool
func set_vabo(amount: int) -> void
func set_all_abilities(unlocked: bool) -> void
func teleport_to_checkpoint() -> bool
func reset_save_and_reload() -> Error
func reload_level() -> void
func _get_player() -> Player
func _get_active_memory_node() -> MemoryNode
```

Action rules:

- health: `player.health_component.heal(player.health_component.max_health)`;
- Vabo: `PlayerData.set_vabo(amount)`;
- abilities: call `PlayerData.set_ability_unlocked()` for every canonical ID,
  then `player.refresh_progression_from_player_data()`;
- teleport: set `player.global_transform` from
  `MemoryNode.get_spawn_transform()` and set `player.velocity = Vector3.ZERO`;
- reset: `SaveManager.clear_save()`, then `PlayerData.reset_progress()`, close
  the panel, and `await SceneManager.reload_current_scene()`;
- reload: close the panel, then `SceneManager.reload_current_scene()`.

- [ ] **Step 4: Gate player input**

In `PlayerInput._physics_process()` change the initial guard to:

```gdscript
if (
	not input_enabled
	or DebugTools.is_gameplay_input_blocked()
):
	_clear_input()
	return
```

At the start of `Player._unhandled_input()` add:

```gdscript
if DebugTools.is_gameplay_input_blocked():
	return
```

- [ ] **Step 5: Run tests and commit**

Run the F10 contract plus player debug-flight and Godot warning tests. Expected:
all PASS.

```powershell
git add -- common/autoload/debug_tools.gd common/autoload/game_constants.gd entities/player/components/input_handler.gd entities/player/player.gd project.godot .codex/tests/f10-debug-panel.tests.ps1
git commit -m "feat: add debug tools controller and input gate"
```

---

### Task 3: Compact Collapsible Panel and Localization

**Files:**
- Create: `ui/debug_panel/debug_panel.gd`
- Create: `ui/debug_panel/debug_panel.tscn`
- Modify: `assets/translations/texts.csv`
- Modify: `.codex/tests/f10-debug-panel.tests.ps1`

**Interfaces:**
- Consumes: all Task 2 `DebugTools` action methods
- Produces: `DebugPanel.set_open(value: bool) -> void`

- [ ] **Step 1: Extend UI/localization contract and verify RED**

Assert the scene has:

```text
offset_right = 320.0
SaveHeader
SaveContent
PlayerHeader
PlayerContent
ProgressionHeader
ProgressionContent
CheckpointHeader
CheckpointContent
ResetConfirmRow
VaboSpinBox
StatusLabel
```

Assert the script contains:

```text
func set_open(value: bool) -> void:
func _set_section_expanded(
DebugTools.reset_save_and_reload()
DebugTools.restore_health()
DebugTools.set_all_abilities(true)
DebugTools.set_all_abilities(false)
DebugTools.teleport_to_checkpoint()
DebugTools.reload_level()
```

Assert `texts.csv` contains English and Russian values for every key listed in
Step 3. Run the contract. Expected: FAIL on the missing panel scene.

- [ ] **Step 2: Create the compact scene**

Create `ui/debug_panel/debug_panel.tscn` with this hierarchy:

```text
DebugPanel (CanvasLayer, hidden, layer 200)
└── Panel (PanelContainer, left/top/bottom anchored, width 320)
    └── Margin (12 px)
        └── Scroll (vertical)
            └── Sections (VBox, separation 4)
                ├── Title
                ├── SaveHeader (Button)
                ├── SaveContent (VBox)
                │   ├── ResetSaveButton
                │   └── ResetConfirmRow (HBox, hidden)
                │       ├── ResetConfirmButton
                │       └── ResetCancelButton
                ├── PlayerHeader (Button)
                ├── PlayerContent (VBox)
                │   ├── RestoreHealthButton
                │   └── ReloadLevelButton
                ├── ProgressionHeader (Button)
                ├── ProgressionContent (VBox)
                │   ├── VaboRow (HBox)
                │   │   ├── VaboLabel
                │   │   ├── VaboSpinBox
                │   │   └── VaboApplyButton
                │   ├── UnlockAllButton
                │   └── LockAllButton
                ├── CheckpointHeader (Button)
                ├── CheckpointContent (VBox)
                │   └── TeleportCheckpointButton
                └── StatusLabel
```

Use `custom_minimum_size.y = 30` for buttons, `separation = 4`, and no
fullscreen `ColorRect`.

- [ ] **Step 3: Add localization**

Append these rows to `assets/translations/texts.csv`:

```csv
debug_panel_title,"Debug Tools","Инструменты отладки"
debug_category_save,"Save","Сохранение"
debug_category_player,"Player","Игрок"
debug_category_progression,"Progression","Прогрессия"
debug_category_checkpoint,"Checkpoint","Контрольная точка"
debug_reset_save,"Reset Save","Сбросить сохранение"
debug_reset_confirm,"Reset save and restart level?","Сбросить сохранение и перезапустить уровень?"
debug_confirm,"Confirm","Подтвердить"
debug_cancel,"Cancel","Отмена"
debug_restore_health,"Restore Health","Восстановить здоровье"
debug_reload_level,"Reload Level","Перезапустить уровень"
debug_apply,"Apply","Применить"
debug_unlock_all,"Unlock All Abilities","Открыть все способности"
debug_lock_all,"Lock All Abilities","Закрыть все способности"
debug_teleport_checkpoint,"Teleport to Checkpoint","Телепорт к контрольной точке"
debug_status_health_restored,"Health restored","Здоровье восстановлено"
debug_status_progression_updated,"Progression updated","Прогрессия обновлена"
debug_status_checkpoint_missing,"Active checkpoint not found","Активная контрольная точка не найдена"
debug_status_player_missing,"Player not found","Игрок не найден"
debug_status_save_reset_failed,"Could not reset save","Не удалось сбросить сохранение"
```

- [ ] **Step 4: Implement the panel script**

Create `debug_panel.gd` with `class_name DebugPanel`, cached node references,
and four section descriptors. Use header buttons with `toggle_mode = true`.

```gdscript
func set_open(value: bool) -> void:
	visible = value
	if value:
		vabo_spin_box.value = PlayerData.current_vabo
		reset_confirm_row.visible = false


func _set_section_expanded(
	header: Button,
	content: Control,
	title_key: StringName,
	expanded: bool
) -> void:
	header.button_pressed = expanded
	content.visible = expanded
	header.text = (
		("▼ " if expanded else "▶ ")
		+ tr(String(title_key))
	)
```

Connect each action to `DebugTools`. Show one-line localized feedback through
`StatusLabel`. Reset Save first reveals `ResetConfirmRow`; confirmation awaits
`DebugTools.reset_save_and_reload()`, cancel hides the row.

- [ ] **Step 5: Run tests and commit**

Run the F10 contract and translation-related save/HUD contracts. Expected: all
PASS.

```powershell
git add -- ui/debug_panel/debug_panel.gd ui/debug_panel/debug_panel.tscn assets/translations/texts.csv .codex/tests/f10-debug-panel.tests.ps1
git commit -m "feat: add compact collapsible debug panel"
```

---

### Task 4: System Documentation and Final Verification

**Files:**
- Modify: `.codex/HANDOFF.md`
- Modify: `.codex/ROADMAP.md`
- Regenerate: `.codex/project-index.txt`

**Interfaces:**
- Consumes: completed Tasks 1–3
- Produces: next-chat handoff and verified repository state

- [ ] **Step 1: Update system documentation**

Move F10 Debug Panel from `## Next` to `## Completed` in the roadmap. Record:

- compact `320 px` left panel;
- F10 toggle;
- collapsible Save/Player/Progression/Checkpoint sections;
- no pause, gameplay input blocked while open;
- save reset behaviour;
- release-export guard;
- deferred object inspector/transform editing.

Add the same concise operational summary and manual smoke checklist to
`.codex/HANDOFF.md`.

- [ ] **Step 2: Regenerate the project index**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/update-project-index.tests.ps1
```

Expected: PASS and new debug-panel files present in the index.

- [ ] **Step 3: Run all safe tests**

Run every `.codex/tests/*.tests.ps1` in a separate PowerShell process. Expected:
all pass, including the new F10 contract.

- [ ] **Step 4: Verify repository scope**

Run:

```powershell
git diff --check
git status --short
git diff --name-only HEAD -- entities/player/player.tscn levels/Level_01.tscn ui/player_hud.tscn
```

Expected: no unintended changes to the user's scene tuning.

- [ ] **Step 5: Commit documentation**

```powershell
git add -- .codex/HANDOFF.md .codex/ROADMAP.md .codex/project-index.txt
git commit -m "docs: hand off F10 debug panel"
```

- [ ] **Step 6: Request GUI smoke-test**

Ask the user to verify F10 toggle, compact layout, collapsed sections, blocked
gameplay input, every action, and absence from a release export.
