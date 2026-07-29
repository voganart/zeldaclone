# Memory Save System Design

## Goal

Create a reusable save module for *Kvantubikeya: Echoes of the Void* that
supports placeable checkpoints, automatic saves after permanent rewards, and
selective persistence for completed puzzles.

The first implementation targets one save slot and `Level_01`.

## Player Experience

Saving is represented by a world object called a **Memory Node**. It is an
ancient crystal or mechanism that reacts to Tiko's Keeper Amulet and anchors
his memory in the broken world.

When activated, the node:

- becomes the current respawn point;
- fully restores health;
- saves current Vabo, abilities, level, and persistent world flags;
- plays a short Vabo light pulse and a quiet confirmation sound;
- briefly shows the message `Память закреплена`;
- remains softly lit after activation.

The interaction must be short and must not open a menu.

## Save Boundaries

### Saved by a Memory Node

- current level path;
- active checkpoint ID;
- current Vabo;
- maximum health;
- unlocked abilities;
- completed persistent puzzle IDs.

### Saved Immediately

- obtaining a permanent ability;
- completing a persistent puzzle or permanently opening a route.

These events save the complete current snapshot, not only the changed field.

### Runtime Persistence Between Deaths

`PlayerData` remains alive while a scene reloads. Vabo collected after the
last disk save remains available after death during the current game session.
If the player quits before another save event, that unbanked progress is lost.

### Reset After Death

- enemies;
- crates and their loot;
- ordinary hazards;
- moving and fragile platforms;
- other temporary scene state.

This intentionally allows repeated combat and Vabo farming while preserving
the cost of replaying the section.

### Persistent After Completion

- solved one-shot puzzles;
- permanently opened doors, bridges, and routes;
- other objects explicitly registered with a unique `persistent_id`.

Ordinary traps are not persistent unless a designer deliberately marks their
controller as a completed one-shot challenge.

## Architecture

### `SaveManager` Autoload

`SaveManager` owns disk serialization and the active save snapshot. It exposes
operations to:

- load or create the single save slot;
- save at a checkpoint;
- save after a permanent event;
- clear the save;
- query and register persistent IDs;
- provide the active checkpoint ID to the current level.

The file is stored under `user://` as versioned JSON. Invalid or incompatible
data falls back to a new game without preventing the project from starting.

### `PlayerData` Autoload

`PlayerData` is the runtime source of truth for:

- Vabo;
- maximum health;
- ability unlocks for `roll_ability`, `double_jump`, `ground_slam`,
  `air_dash`, and `3_hit_combo`;
- persistent completion flags;
- current level and checkpoint IDs.

It emits signals when currency or permanent progression changes. Player
instances apply this state when spawned.

### Memory Node Scene

A reusable `MemoryNode` scene has:

- exported unique `checkpoint_id`;
- an interaction or activation area;
- a spawn marker;
- inactive and active visual states;
- a one-shot confirmation signal for UI and VFX.

The node is placeable anywhere in a level. Level scripts do not need a custom
save implementation for each node.

### Persistent World Object Contract

A persistent puzzle controller has an exported `persistent_id`. On scene
startup it asks `SaveManager` whether that ID is complete and immediately
applies its completed state. When solved, it registers the ID and triggers a
permanent-event save.

The persistence hook belongs on the puzzle or route controller, not on every
child mesh, collider, or animation.

## Death and Load Flow

1. Player death requests a restart from `SceneManager`.
2. The current level is reloaded without writing a new disk save.
3. Temporary scene objects return to their authored state.
4. Persistent puzzle controllers reapply completed flags.
5. The level spawns the player at the active Memory Node; if none exists, it
   uses the authored `PlayerStart`.
6. The new player instance applies Vabo-independent permanent ability and
   health progression from `PlayerData`.

Starting the game loads the last disk snapshot before entering its saved
level.

## Scope of the First Slice

- one versioned save slot;
- save/load/clear API;
- PlayerData integration for Vabo, max health, and current abilities;
- placeable Memory Node;
- checkpoint-based respawn in `Level_01`;
- one generic persistent-ID integration contract;
- automated regression tests;
- minimal activation feedback using existing assets where possible.

The Vabo HUD, upgrade shop, save-slot menu, and F10 debug panel are separate
follow-up features.

## Verification

Automated checks cover:

- new save creation and invalid-file fallback;
- round-trip serialization of all snapshot fields;
- Vabo surviving death reload without forcing a disk save;
- checkpoint selection and fallback to `PlayerStart`;
- ability persistence after player recreation;
- completed persistent IDs reapplying after scene reload;
- enemies, crates, and temporary hazards remaining outside saved state.

Manual `Level_01` verification covers:

- activation feedback and full heal;
- death respawn at the latest Memory Node;
- enemy and crate reset;
- persistent puzzle/route state;
- restart from the saved checkpoint;
- save deletion followed by a clean new game.
