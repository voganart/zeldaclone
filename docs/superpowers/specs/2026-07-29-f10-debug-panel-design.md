# F10 Debug Panel — Design

## Goal

Add a compact runtime debug panel for quickly testing saves, player state,
progression, and checkpoints while building `Level_01`.

The panel is a development tool. It must not be available in release exports.

## Scope

The first version provides:

- `F10` toggle;
- delete/reset save with confirmation;
- restore player health;
- unlock all abilities;
- lock all abilities;
- inspect and change the current Vabo amount;
- teleport the player to the active checkpoint;
- reload the current level.

Runtime object inspection and transform editing are explicitly deferred to a
later iteration.

## Architecture

`DebugTools` is a debug-only autoload responsible for:

- handling the F10 action;
- creating and owning the panel;
- exposing whether gameplay input is blocked;
- finding the current player and level when an action is requested;
- coordinating save, progression, teleport, and reload actions.

The UI is a separate `CanvasLayer` scene under `ui/debug_panel/`. It contains
no gameplay state of its own and delegates actions to `DebugTools`.

The autoload remains registered in project settings so development builds have
a stable global entry point. At runtime it immediately disables itself when
`OS.is_debug_build()` is false and never creates the panel.

The panel only opens when the current scene contains a node in the `player`
group. Pressing F10 in menus has no effect.

## Layout

The panel is anchored to the left edge and is approximately `320 px` wide. It
has no fullscreen dimmer and must leave most of the game visible.

Content is arranged vertically in collapsible categories:

- Save;
- Player;
- Progression;
- Checkpoint.

Each category header is a button with a `▶` or `▼` prefix. Category content can
be independently expanded or collapsed. The layout uses compact rows and
short controls instead of large cards or wide spacing.

The title row includes a compact close button. Closing through this button and
closing through F10 use the same panel lifecycle.

The initial content is:

- Save: destructive reset button and confirmation row;
- Player: restore health and reload level;
- Progression: Vabo value control, unlock all, lock all;
- Checkpoint: teleport to active checkpoint.

## Input Behaviour

Opening the panel does not pause the scene tree. Gameplay, animation, physics,
cooldowns, and effects continue to run.

While the panel is open:

- player movement, jump, attack, roll, abilities, and debug flight input are
  blocked;
- UI mouse and keyboard interaction remains active;
- closing with `F10` restores gameplay input immediately.
- opening stores the previous mouse mode and makes the cursor visible;
- gameplay camera input cannot recapture the mouse while the panel is open;
- closing restores the stored mouse mode.

The existing player input layer queries
`DebugTools.is_gameplay_input_blocked()` and clears its current input state
while blocked. The player's separate debug-flight input handler uses the same
guard. The debug panel must not simulate releases or change saved input
bindings.

## Actions

### Delete Save

The first press reveals a compact confirmation row. Confirming:

1. calls the existing new-game/reset flow;
2. deletes the disk save and resets runtime `PlayerData`;
3. reloads the current gameplay level;
4. starts at `PlayerStart` with no active checkpoint.

Cancel hides the confirmation row without changing state.

### Restore Health

Find the active player through the `player` group. If it has a health
component, restore current health to maximum through the existing health API.

### Ability Controls

Unlock All and Lock All operate through `PlayerData`, using the canonical
ability identifiers already used by ability chests and the HUD:

- `roll_ability`;
- `double_jump`;
- `ground_slam`;
- `air_dash`;
- `3_hit_combo`.

`PlayerData` gains a public setter for changing an ability in either direction
and a generic ability-state-changed signal. Existing unlock behaviour remains
compatible. The player reapplies its runtime ability state and the HUD updates
visibility when this signal fires.

Debug ability changes do not request an autosave themselves. They change the
current runtime progression state; a later normal gameplay autosave may
snapshot that state. Delete Save remains the reliable way to return to a clean
progression state.

### Vabo

The panel displays the current Vabo value in a compact numeric control. Applying
the value updates `PlayerData` through a public non-negative setter and
therefore updates the HUD through the existing signal. This action does not
request an autosave by itself.

### Checkpoint Teleport

If `PlayerData.active_checkpoint_id` is set, find the matching Memory Node in
the current scene and move the player to its spawn position using the same
checkpoint positioning contract as level loading. If no active checkpoint or
matching node exists, show a short status message and do nothing.

### Reload Level

Reload the current gameplay scene without modifying `PlayerData` or the disk
save.

## Feedback and Localization

All visible labels, buttons, confirmations, and status messages use keys in
`assets/translations/texts.csv`, with English and Russian values added
together.

Actions show a short inline status message for success or unavailable state.
The panel does not use modal OS dialogs.

## Error Handling

- Missing player, health component, checkpoint, or gameplay scene produces a
  localized status message instead of an error.
- Save reset checks the returned error and only reloads after a successful
  reset.
- Repeated F10 presses are safe during scene transitions.
- Opening the main menu does not expose gameplay actions against missing
  objects; the panel starts hidden and is intended for gameplay scenes.

## Testing

PowerShell contract tests verify:

- the debug input action and autoload registration;
- release-build guarding;
- compact collapsible category structure;
- gameplay input blocking integration;
- use of existing save and progression APIs;
- localization keys in both languages.

The user performs the runtime Godot GUI smoke-test:

- F10 toggle and compact layout;
- category collapse/expand;
- player input blocked only while open;
- save reset returns to a clean level start;
- health, abilities, Vabo, checkpoint teleport, and reload actions.
