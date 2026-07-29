# Memory Save System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one-slot saves, placeable Memory Node checkpoints, permanent
ability/puzzle state, checkpoint respawn, and localized save feedback to
`Level_01`.

**Architecture:** `PlayerData` owns runtime progression and serializes a
sanitized snapshot. A new `SaveManager` autoload owns versioned JSON disk I/O
and permanent-event saves. Placeable `MemoryNode` scenes select respawn points;
objects with persistent IDs reapply completed state after a level reload.

**Tech Stack:** Godot 4.7, GDScript, Godot scenes/resources, CSV localization,
headless GDScript integration tests, PowerShell verification.

## Global Constraints

- One save slot at `user://savegame.json`.
- Save data is versioned JSON with schema version `1`.
- A Memory Node saves the complete snapshot and fully heals the player.
- Abilities and completed persistent objects save immediately.
- Vabo survives death reloads in the current process but is written to disk
  only by a save event.
- Enemies, ordinary crates, traps, and temporary platforms are never serialized.
- Player-facing text uses `assets/translations/texts.csv` with English and
  Russian values added together.
- Existing F7 flight, Phantom Camera lifecycle, cloud noise, and Godot 4.7
  compatibility fixes must remain unchanged.
- The first level path uses the filesystem-correct case
  `res://levels/Level_01.tscn`.

---

## File Structure

- `common/autoload/player_data.gd`: sanitized runtime progression model.
- `common/autoload/save_manager.gd`: versioned disk persistence and checkpoint
  API.
- `common/persistence/persistent_state.gd`: reusable persistent-ID component.
- `entities/interactive/MemoryNode/memory_node.gd`: checkpoint activation,
  healing, and visual state.
- `entities/interactive/MemoryNode/MemoryNode.tscn`: reusable world scene.
- `.codex/tests/save_system_runtime_test.gd`: real headless behavior tests.
- Existing Player, chest, HUD, menu, game-over, level, and localization files
  receive narrow integrations only.

---

### Task 1: Make PlayerData the Runtime Progression Model

**Files:**
- Modify: `common/autoload/player_data.gd`
- Create: `.codex/tests/save_system_runtime_test.gd`

**Interfaces:**
- Produces: `PlayerData.reset_progress() -> void`
- Produces: `PlayerData.create_snapshot() -> Dictionary`
- Produces: `PlayerData.apply_snapshot(snapshot: Dictionary) -> void`
- Produces: `PlayerData.unlock_ability(ability_name: StringName) -> bool`
- Produces: `PlayerData.is_ability_unlocked(ability_name: StringName) -> bool`
- Produces: `PlayerData.complete_persistent_id(id: StringName) -> bool`
- Produces: `PlayerData.is_persistent_id_complete(id: StringName) -> bool`

- [ ] **Step 1: Write the failing runtime model test**

Create a `SceneTree` test runner that mutates the real `PlayerData` autoload,
round-trips a literal snapshot, and checks normalization:

```gdscript
extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])

func _run() -> void:
	PlayerData.reset_progress()
	PlayerData.apply_snapshot({
		"current_vabo": 27,
		"max_health": 5.0,
		"abilities": {
			"roll_ability": true,
			"double_jump": true,
			"ground_slam": false,
			"air_dash": false,
			"3_hit_combo": false,
		},
		"completed_persistent_ids": ["level_01_gate"],
		"current_level_path": "res://levels/Level_01.tscn",
		"active_checkpoint_id": "level_01_after_crates",
	})
	_expect_equal(PlayerData.current_vabo, 27, "Vabo restores")
	_expect_equal(PlayerData.max_health, 5.0, "max health restores")
	_expect_equal(
		PlayerData.is_ability_unlocked("double_jump"),
		true,
		"ability restores"
	)
	_expect_equal(
		PlayerData.is_persistent_id_complete("level_01_gate"),
		true,
		"persistent ID restores"
	)
	PlayerData.apply_snapshot({
		"current_vabo": -10,
		"max_health": 0.0,
		"abilities": {"unknown_ability": true},
	})
	_expect_equal(PlayerData.current_vabo, 0, "negative Vabo clamps")
	_expect_equal(PlayerData.max_health, 1.0, "health minimum clamps")
	_expect_equal(
		PlayerData.is_ability_unlocked("unknown_ability"),
		false,
		"unknown abilities are ignored"
	)
	if failures.is_empty():
		print("PASS: PlayerData runtime progression")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
```

The production change this catches is losing fields, accepting unknown
abilities, or failing to sanitize corrupted numeric values.

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path 'C:\GodotProjects\zeldaclone' `
  --script res://.codex/tests/save_system_runtime_test.gd
```

Expected: FAIL because `reset_progress`, `apply_snapshot`, and query methods do
not exist.

- [ ] **Step 3: Implement the normalized runtime model**

Replace the partial ability dictionary with exact defaults and add persistent
state:

```gdscript
const DEFAULT_ABILITIES: Dictionary = {
	"roll_ability": false,
	"double_jump": false,
	"ground_slam": false,
	"air_dash": false,
	"3_hit_combo": false,
}

var current_vabo: int = 0
var max_health: float = 3.0
var abilities: Dictionary = DEFAULT_ABILITIES.duplicate(true)
var completed_persistent_ids: Array[String] = []
var current_level_path: String = ""
var active_checkpoint_id: String = ""

signal vabo_changed(new_amount: int)
signal ability_unlocked(ability_name: StringName)
signal persistent_id_completed(id: StringName)

func reset_progress() -> void:
	current_vabo = 0
	max_health = 3.0
	abilities = DEFAULT_ABILITIES.duplicate(true)
	completed_persistent_ids.clear()
	current_level_path = ""
	active_checkpoint_id = ""
	vabo_changed.emit(current_vabo)

func unlock_ability(ability_name: StringName) -> bool:
	var key := String(ability_name)
	if not abilities.has(key) or abilities[key]:
		return false
	abilities[key] = true
	ability_unlocked.emit(ability_name)
	return true

func create_snapshot() -> Dictionary:
	return {
		"current_vabo": current_vabo,
		"max_health": max_health,
		"abilities": abilities.duplicate(true),
		"completed_persistent_ids": completed_persistent_ids.duplicate(),
		"current_level_path": current_level_path,
		"active_checkpoint_id": active_checkpoint_id,
	}
```

`apply_snapshot` must start from defaults, clamp Vabo to `>= 0`, clamp health
to `>= 1.0`, accept only the five known ability keys, deduplicate non-empty
persistent IDs, and coerce level/checkpoint values to strings.

- [ ] **Step 4: Run the test and verify GREEN**

Run the command from Step 2.

Expected: `PASS: PlayerData runtime progression`, exit code `0`.

- [ ] **Step 5: Commit**

```powershell
git add -- common/autoload/player_data.gd .codex/tests/save_system_runtime_test.gd
git commit -m "feat: model persistent player progression"
```

---

### Task 2: Add Versioned and Recoverable Disk Saves

**Files:**
- Create: `common/autoload/save_manager.gd`
- Modify: `project.godot`
- Modify: `.codex/tests/save_system_runtime_test.gd`

**Interfaces:**
- Consumes: `PlayerData.create_snapshot()`
- Consumes: `PlayerData.apply_snapshot(snapshot)`
- Produces: `SaveManager.has_save() -> bool`
- Produces: `SaveManager.save_checkpoint(level_path: String, checkpoint_id: StringName) -> Error`
- Produces: `SaveManager.save_permanent_event() -> Error`
- Produces: `SaveManager.load_save() -> bool`
- Produces: `SaveManager.clear_save() -> Error`
- Produces: `SaveManager.start_new_game() -> void`
- Produces: `SaveManager.complete_persistent_id(id: StringName) -> bool`
- Produces: `SaveManager.invalid_save_recovered: bool`

- [ ] **Step 1: Extend the test with disk round-trip and corruption cases**

Use an isolated test file path and hand-authored expectations:

```gdscript
func _test_save_manager() -> void:
	var original_path: String = SaveManager.save_path
	SaveManager.save_path = "user://codex_save_system_test.json"
	SaveManager.clear_save()
	PlayerData.reset_progress()
	PlayerData.add_vabo(42)
	PlayerData.max_health = 6.0
	PlayerData.unlock_ability("roll_ability")
	var save_error := SaveManager.save_checkpoint(
		"res://levels/Level_01.tscn",
		"level_01_after_crates"
	)
	_expect_equal(save_error, OK, "checkpoint writes")
	PlayerData.reset_progress()
	_expect_equal(SaveManager.load_save(), true, "valid save loads")
	_expect_equal(PlayerData.current_vabo, 42, "disk Vabo round-trip")
	_expect_equal(
		PlayerData.active_checkpoint_id,
		"level_01_after_crates",
		"checkpoint round-trip"
	)

	var file := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	_expect_equal(SaveManager.load_save(), false, "invalid JSON rejected")
	_expect_equal(SaveManager.has_save(), false, "invalid save removed")
	_expect_equal(
		SaveManager.invalid_save_recovered,
		true,
		"recovery status retained for UI"
	)
	SaveManager.clear_save()
	SaveManager.save_path = original_path
```

The production changes this catches are non-round-trippable JSON, wrong schema
handling, writing to the real player save during tests, or leaving corrupted
data active.

- [ ] **Step 2: Run and verify RED**

Run the Task 1 headless command.

Expected: FAIL because the `SaveManager` autoload and API do not exist.

- [ ] **Step 3: Implement SaveManager and register it after PlayerData**

Create the core with exact constants and signals:

```gdscript
extends Node

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://savegame.json"

var save_path: String = DEFAULT_SAVE_PATH
var invalid_save_recovered: bool = false

signal checkpoint_changed(checkpoint_id: StringName)
signal save_completed(reason: StringName)

func _ready() -> void:
	load_save()

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func save_checkpoint(level_path: String, checkpoint_id: StringName) -> Error:
	PlayerData.current_level_path = level_path
	PlayerData.active_checkpoint_id = String(checkpoint_id)
	var error := _write_snapshot()
	if error == OK:
		checkpoint_changed.emit(checkpoint_id)
		save_completed.emit(&"checkpoint")
	return error

func save_permanent_event() -> Error:
	var error := _write_snapshot()
	if error == OK:
		save_completed.emit(&"permanent_event")
	return error

func complete_persistent_id(id: StringName) -> bool:
	if not PlayerData.complete_persistent_id(id):
		return false
	save_permanent_event()
	return true
```

`_write_snapshot` writes `{ "version": 1, "player_data": ... }` to
`save_path + ".tmp"`, flushes and closes it, removes the old target only after
the temporary file succeeds, then renames the temporary file.

`load_save` must reject missing files, invalid JSON, non-dictionaries, unknown
versions, and missing `player_data`. Invalid data resets `PlayerData`, removes
the bad file, sets `invalid_save_recovered = true`, and returns `false`.

Register:

```ini
PlayerData="*res://common/autoload/player_data.gd"
SaveManager="*res://common/autoload/save_manager.gd"
```

- [ ] **Step 4: Run and verify GREEN**

Run the headless runtime test.

Expected: all PlayerData and SaveManager cases print PASS and exit `0`.

- [ ] **Step 5: Commit**

```powershell
git add -- common/autoload/save_manager.gd project.godot .codex/tests/save_system_runtime_test.gd
git commit -m "feat: add versioned save manager"
```

---

### Task 3: Apply Saved Abilities to Every Player Instance

**Files:**
- Modify: `entities/player/player.gd`
- Modify: `entities/interactive/Chest_1/chest.gd`
- Modify: `.codex/tests/save_system_runtime_test.gd`

**Interfaces:**
- Consumes: `PlayerData.is_ability_unlocked(name)`
- Consumes: `SaveManager.save_permanent_event()`
- Changes: `Player.unlock_ability(name) -> bool` updates runtime state before
  applying components and reports whether the unlock was new.

- [ ] **Step 1: Add a real player recreation test**

Load `res://entities/player/player.tscn`, unlock literal progression in
`PlayerData`, instantiate the Player, add it to the test root, wait one process
frame, and assert:

```gdscript
PlayerData.reset_progress()
PlayerData.unlock_ability("double_jump")
PlayerData.unlock_ability("roll_ability")
var player_scene: PackedScene = load("res://entities/player/player.tscn")
var player := player_scene.instantiate()
root.add_child(player)
await process_frame
_expect_equal(
	player.movement_component.max_jump_count,
	2,
	"saved double jump applies to recreated player"
)
_expect_equal(
	player.roll_ability.is_unlocked,
	true,
	"saved roll applies to recreated player"
)
player.queue_free()
await process_frame
```

The production change this catches is reverting `_apply_unlocks` to editor-only
debug flags.

- [ ] **Step 2: Run and verify RED**

Run the headless runtime test.

Expected: FAIL because `_apply_unlocks` still ignores `PlayerData`.

- [ ] **Step 3: Merge debug overrides with saved progression**

Update `_apply_unlocks` so an ability is enabled when either its debug export
or `PlayerData` says it is unlocked:

```gdscript
var has_double_jump := debug_unlock_double_jump \
	or PlayerData.is_ability_unlocked(&"double_jump")
movement_component.max_jump_count = 2 if has_double_jump else 1
air_dash_ability.is_unlocked = debug_unlock_air_dash \
	or PlayerData.is_ability_unlocked(&"air_dash")
ground_slam_ability.is_unlocked = debug_unlock_ground_slam \
	or PlayerData.is_ability_unlocked(&"ground_slam")
roll_ability.is_unlocked = debug_unlock_roll \
	or PlayerData.is_ability_unlocked(&"roll_ability")
combat_component.max_combo_hits = 3 if (
	debug_unlock_3_hit_combo
	or PlayerData.is_ability_unlocked(&"3_hit_combo")
) else 2
```

Update `Player.unlock_ability` to return `bool`, normalize `combo_finisher` to
`3_hit_combo`, call `PlayerData.unlock_ability`, apply the component change,
and call `SaveManager.save_permanent_event()` only when the runtime state
actually changed. Return `true` for a new unlock and `false` for an unknown or
already-unlocked ability.

Keep `chest.gd` calling `player.unlock_ability`; do not duplicate save logic in
the chest.

- [ ] **Step 4: Run and verify GREEN**

Run the headless runtime test and the existing flight regression:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/player-debug-flight.tests.ps1
```

Expected: both exit `0`.

- [ ] **Step 5: Commit**

```powershell
git add -- entities/player/player.gd entities/interactive/Chest_1/chest.gd .codex/tests/save_system_runtime_test.gd
git commit -m "feat: persist player ability unlocks"
```

---

### Task 4: Add the Reusable Persistent-ID Contract

**Files:**
- Create: `common/persistence/persistent_state.gd`
- Modify: `entities/interactive/Chest_1/Chest_1.tscn`
- Modify: `entities/interactive/Chest_1/chest.gd`
- Modify: `.codex/tests/save_system_runtime_test.gd`

**Interfaces:**
- Produces: `PersistentState.completed_on_load`
- Produces: `PersistentState.mark_completed() -> bool`
- Consumes: `SaveManager.complete_persistent_id(id)`

- [ ] **Step 1: Add a component behavior test**

Instantiate the real script twice around a saved ID:

```gdscript
PlayerData.reset_progress()
var script: Script = load("res://common/persistence/persistent_state.gd")
var state := Node.new()
state.set_script(script)
state.persistent_id = &"level_01_roll_chest"
root.add_child(state)
_expect_equal(state.mark_completed(), true, "first completion changes state")
_expect_equal(state.mark_completed(), false, "duplicate completion is ignored")
state.queue_free()
await process_frame

var restored := Node.new()
restored.set_script(script)
restored.persistent_id = &"level_01_roll_chest"
root.add_child(restored)
await process_frame
_expect_equal(restored.is_completed(), true, "completion restores")
restored.queue_free()
```

The production change this catches is duplicate saving or failing to restore a
completed ID after scene recreation.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because `persistent_state.gd` is missing.

- [ ] **Step 3: Implement the component and integrate permanent chests**

Component:

```gdscript
class_name PersistentState
extends Node

@export var persistent_id: StringName
signal completed_on_load

func _ready() -> void:
	if is_completed():
		completed_on_load.emit()

func is_completed() -> bool:
	return not persistent_id.is_empty() \
		and PlayerData.is_persistent_id_complete(persistent_id)

func mark_completed() -> bool:
	if persistent_id.is_empty():
		push_warning("PersistentState requires a non-empty persistent_id")
		return false
	return SaveManager.complete_persistent_id(persistent_id)
```

Add `PersistentState` as a child of the chest scene. In `chest.gd`, connect
`completed_on_load` and apply the opened animation's final pose, disable the
interaction area, and prevent loot spawning. When an ability chest successfully
unlocks a new ability, call `$PersistentState.mark_completed()`.

Expose `persistent_id: StringName` on the chest root and copy it into the child
component during `_ready`; this lets a designer assign stable IDs directly on
packed chest instances without enabling editable children.

Ordinary wooden crates remain untouched and therefore always reset.

- [ ] **Step 4: Run and verify GREEN**

Run the headless runtime test.

Expected: PASS for first completion, duplicate completion, and restored state.

- [ ] **Step 5: Commit**

```powershell
git add -- common/persistence/persistent_state.gd entities/interactive/Chest_1/Chest_1.tscn entities/interactive/Chest_1/chest.gd .codex/tests/save_system_runtime_test.gd
git commit -m "feat: persist completed world objects"
```

---

### Task 5: Build the Placeable Memory Node and Localized Feedback

**Files:**
- Create: `entities/interactive/MemoryNode/memory_node.gd`
- Create: `entities/interactive/MemoryNode/MemoryNode.tscn`
- Modify: `common/autoload/game_events.gd`
- Modify: `ui/player_hud.gd`
- Modify: `ui/player_hud.tscn`
- Modify: `assets/translations/texts.csv`
- Modify: `.codex/tests/save_system_runtime_test.gd`

**Interfaces:**
- Produces: `MemoryNode.checkpoint_id: StringName`
- Produces: `MemoryNode.get_spawn_transform() -> Transform3D`
- Produces: group `memory_nodes`
- Produces: `GameEvents.save_feedback_requested(text_key: StringName)`

- [ ] **Step 1: Add a Memory Node activation test**

Instantiate `MemoryNode.tscn`, set `checkpoint_id`, create a lightweight real
player with the existing HealthComponent scene, call `activate(player)`, and
assert:

```gdscript
_expect_equal(
	PlayerData.active_checkpoint_id,
	"level_01_after_crates",
	"Memory Node selects checkpoint"
)
_expect_equal(
	player.health_component.current_health,
	player.health_component.max_health,
	"Memory Node fully heals"
)
_expect_equal(node.is_active(), true, "Memory Node activates visually")
```

The production changes this catches are saving the wrong ID, forgetting the
heal, or failing to reflect active state.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because the Memory Node scene does not exist.

- [ ] **Step 3: Create the reusable scene**

Use existing assets only:

- root `Node3D` in group `memory_nodes`;
- `MeshInstance3D` using
  `res://assets/models/interactive/items_Vabo.res`;
- `OmniLight3D` with low cyan energy;
- `InteractionArea` using existing localized `ui_interact`;
- `Marker3D` named `SpawnPoint`;
- optional instance of `res://vfx/PickupItemVfx/Vabo_vfx.tscn`.

Core API:

```gdscript
class_name MemoryNode
extends Node3D

@export var checkpoint_id: StringName
@onready var interaction_area: InteractionArea = $InteractionArea
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var light: OmniLight3D = $OmniLight3D
var _active := false

func _ready() -> void:
	interaction_area.interact_callable = _on_interact
	SaveManager.checkpoint_changed.connect(_on_checkpoint_changed)
	_set_active(PlayerData.active_checkpoint_id == String(checkpoint_id))

func activate(player: Node) -> void:
	if checkpoint_id.is_empty():
		push_warning("MemoryNode requires checkpoint_id")
		return
	if player.health_component:
		player.health_component.heal(player.health_component.max_health)
	var level_path := get_tree().current_scene.scene_file_path
	if SaveManager.save_checkpoint(level_path, checkpoint_id) == OK:
		_set_active(true)
		GameEvents.save_feedback_requested.emit(&"save_memory_anchored")

func get_spawn_transform() -> Transform3D:
	return spawn_point.global_transform
```

When a different checkpoint activates, all Memory Nodes compare the emitted ID
and update their low-cost light/emission state.

- [ ] **Step 4: Add HUD feedback and localization**

Add a centered-top `Label` named `SaveFeedback` to `player_hud.tscn`. Connect
`GameEvents.save_feedback_requested` in `player_hud.gd`, assign
`label.text = tr(String(text_key))`, fade in over `0.2` seconds, hold for
`1.2`, and fade out over `0.4`. Repeated saves kill the previous tween.

Append these rows to `texts.csv`:

```csv
ui_continue,"Continue","Продолжить"
save_memory_anchored,"Memory anchored","Память закреплена"
save_data_invalid,"Save data was reset","Данные сохранения были сброшены"
```

- [ ] **Step 5: Run and verify GREEN**

Run the headless runtime test, then import translations through a headless
editor parse:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --editor --path 'C:\GodotProjects\zeldaclone' --quit
```

Expected: runtime test exits `0`; the CSV imports without parse errors.

- [ ] **Step 6: Commit**

```powershell
git add -- entities/interactive/MemoryNode common/autoload/game_events.gd ui/player_hud.gd ui/player_hud.tscn assets/translations/texts.csv assets/translations/texts.en.translation assets/translations/texts.ru.translation .codex/tests/save_system_runtime_test.gd
git commit -m "feat: add localized memory checkpoints"
```

---

### Task 6: Continue from the Saved Level and Checkpoint

**Files:**
- Modify: `levels/level_01.gd`
- Modify: `common/autoload/scene_manager.gd`
- Modify: `ui/menus/main_menu.gd`
- Modify: `ui/menus/main_menu.tscn`
- Modify: `ui/menus/game_over.gd`
- Modify: `.codex/tests/save_system_runtime_test.gd`

**Interfaces:**
- Consumes: Memory Nodes in group `memory_nodes`
- Produces: `Level01.resolve_player_spawn_transform() -> Transform3D`
- Produces: `SceneManager.continue_or_start_game()`
- Produces: dynamic main button label `ui_new_game` / `ui_continue`

- [ ] **Step 1: Add checkpoint resolution tests**

Instantiate a minimal level root with a `PlayerStart` marker and two
MemoryNode instances. Assert three literal cases:

1. no checkpoint ID returns `PlayerStart`;
2. matching ID returns that node's `SpawnPoint`;
3. missing ID safely falls back to `PlayerStart`.

The production change this catches is spawning at the wrong Memory Node or
crashing when a designer renames/removes a checkpoint.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because `resolve_player_spawn_transform` does not exist.

- [ ] **Step 3: Resolve spawn before creating the Player**

In `level_01.gd`, select a Memory Node only when
`PlayerData.current_level_path` matches `scene_file_path`. Iterate group
members, require they are descendants of this level, compare
`checkpoint_id`, and otherwise use `PlayerStart.global_transform`.

Set the new player's complete `global_transform`, not position only.

- [ ] **Step 4: Implement the dynamic main-menu action**

Correct the case of `SceneManager.LEVEL_1_PATH` and add:

```gdscript
func continue_or_start_game() -> void:
	if SaveManager.has_save() and not PlayerData.current_level_path.is_empty():
		change_scene_with_loading(PlayerData.current_level_path)
	else:
		SaveManager.start_new_game()
		change_scene_with_loading(LEVEL_1_PATH)
```

In `main_menu.gd`:

```gdscript
var can_continue := SaveManager.has_save() \
	and not PlayerData.current_level_path.is_empty()
btn_new_game.text = tr("ui_continue" if can_continue else "ui_new_game")
```

The button calls `SceneManager.continue_or_start_game()`. Add a small
`SaveStatusLabel` under the buttons; show localized `save_data_invalid` only
when `SaveManager.invalid_save_recovered` is true, then clear the flag.

- [ ] **Step 5: Keep Game Over retry on runtime progress**

Change `restart_last_level` to prefer `PlayerData.current_level_path`, then
`last_played_level`, then `LEVEL_1_PATH`. Do not call `load_save()` during
retry; this preserves Vabo earned in the current session.

`game_over.gd` continues calling `restart_last_level`, so enemies, crates,
traps, and platforms reset naturally when the scene is re-instantiated.

- [ ] **Step 6: Run and verify GREEN**

Run the runtime test and:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/tests/phantom-camera-lifecycle.tests.ps1
powershell -ExecutionPolicy Bypass -File .codex/tests/godot-47-warning-regressions.tests.ps1
```

Expected: all commands exit `0`.

- [ ] **Step 7: Commit**

```powershell
git add -- levels/level_01.gd common/autoload/scene_manager.gd ui/menus/main_menu.gd ui/menus/main_menu.tscn ui/menus/game_over.gd .codex/tests/save_system_runtime_test.gd
git commit -m "feat: continue from memory checkpoint"
```

---

### Task 7: Integrate Level_01 and Verify the Complete Loop

**Files:**
- Modify: `levels/Level_01.tscn`
- Modify: `.codex/PROJECT_MAP.md`
- Modify: `.codex/GODOT_COMPATIBILITY.md`
- Modify: `.codex/project-index.txt`
- Modify: `.codex/ROADMAP.md`

**Interfaces:**
- Consumes: `MemoryNode.tscn`
- Consumes: chest `PersistentState` IDs
- Produces: first authored checkpoint `level_01_after_crates`

- [ ] **Step 1: Add a failing Level_01 integration assertion**

Extend the runtime test to load `Level_01.tscn` and assert:

- one Memory Node has ID `level_01_after_crates`;
- every ability chest has a non-empty, unique persistent ID;
- the level resource path uses exact filesystem case.

This catches duplicate IDs and accidentally removing the only checkpoint.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because `Level_01` has no Memory Node and chest IDs are empty.

- [ ] **Step 3: Place the first node and assign stable IDs**

Instance `MemoryNode.tscn` under a new `MemoryNodes` root. Set:

```text
checkpoint_id = "level_01_after_crates"
initial transform origin = Vector3(31.0, -2.75, 4.0)
```

The position is the first authored pass after the crate tutorial and remains
designer-adjustable in the editor.

Assign:

```text
Chest1 -> level_01_air_dash_chest
Chest2 -> level_01_ground_slam_chest
Chest3 -> level_01_double_jump_chest_a
Chest4 -> level_01_roll_chest
Chest5 -> level_01_double_jump_chest_b
```

- [ ] **Step 4: Run automated verification**

Run:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path 'C:\GodotProjects\zeldaclone' `
  --script res://.codex/tests/save_system_runtime_test.gd

Get-ChildItem -LiteralPath '.codex/tests' -Filter '*.tests.ps1' |
  ForEach-Object {
    powershell -ExecutionPolicy Bypass -File $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Failed: $($_.Name)" }
  }

git diff --check
```

Expected: runtime test PASS, every PowerShell regression PASS, and
`git diff --check` produces no output.

- [ ] **Step 5: Perform the manual gameplay loop**

In the Godot editor:

1. Delete the test/user save before starting.
2. Verify the menu says `Новая игра` in Russian and `New Game` in English.
3. Break the crate tutorial and activate the Memory Node.
4. Verify full heal, light activation, and localized `Память закреплена`.
5. Collect Vabo, die, press retry, and verify the level reloads at the node.
6. Verify collected runtime Vabo remains.
7. Verify enemies, wooden crates, traps, and moving platforms reset.
8. Open an ability chest, die, and verify the ability and opened chest persist.
9. Quit the game, relaunch, and verify the menu says `Продолжить`.
10. Continue and verify the saved level/checkpoint/progression restores.
11. Temporarily corrupt the save file and verify safe reset plus localized
    recovery feedback.

- [ ] **Step 6: Update persistent project documentation**

Update:

- `.codex/PROJECT_MAP.md` with SaveManager, PlayerData, MemoryNode, and
  persistent-state entry points;
- `.codex/GODOT_COMPATIBILITY.md` to remove the resolved InputMapper
  case-mismatch warning and record the verified save-system checks;
- `.codex/ROADMAP.md` by moving Memory Save System from Current to Completed
  while leaving F10 Debug Panel and Vabo HUD under Next.

Regenerate the index:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/update-project-index.ps1
```

- [ ] **Step 7: Commit**

```powershell
git add -- levels/Level_01.tscn .codex/PROJECT_MAP.md .codex/GODOT_COMPATIBILITY.md .codex/project-index.txt .codex/ROADMAP.md
git commit -m "feat: integrate memory saves into level one"
```

- [ ] **Step 8: Final verification and push**

Re-run Step 4 after all documentation changes. Confirm:

```powershell
git status -sb
git log --oneline -8
```

Expected: only intended commits, no uncommitted files, and the branch is ahead
of `origin/master`. Push only after the user requests or confirms publication.
