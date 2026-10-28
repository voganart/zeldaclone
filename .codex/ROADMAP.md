# Project Roadmap and Wishlist

This is the persistent backlog for ideas agreed in Codex chats. Keep features
here until they are implemented or deliberately rejected.

## Project-wide Rules

- All player-facing text must use keys from
  `assets/translations/texts.csv`.
- Add English and Russian values together; do not hardcode UI copy in scripts
  or scenes.

## Completed

### Memory Save System

- One versioned save slot.
- Placeable Memory Nodes for checkpoints and healing.
- Auto-save after permanent abilities and completed one-shot puzzles.
- Reload the level on death: reset enemies, crates, and temporary hazards.
- Preserve Vabo during death reloads in the current session.
- Preserve completed puzzles and permanent routes by unique ID.
- First integration target: `Level_01`.
- Dynamic `New Game / Continue` main-menu action.
- English and Russian save feedback.

Design:
`docs/superpowers/specs/2026-07-29-memory-save-system-design.md`.

### Player Progress Feedback

- Show current Vabo below the hearts with a temporary diamond icon.
- Hide locked abilities without reserving empty slots.
- Show Roll charges and radial cooldowns for Ground Slam, Air Dash, and
  3-hit combo.
- Desaturate Double Jump after the second jump until landing.
- Keep Air Dash unavailable feedback visible until landing.

Design:
`docs/superpowers/specs/2026-07-29-player-progress-feedback-design.md`.

### F10 Debug Panel

- Compact `320 px` left-side panel toggled with `F10`.
- Collapsible Save, Player, Progression, and Checkpoint categories.
- Reset save, restore health, reload level, set Vabo, lock/unlock abilities,
  and teleport to the active checkpoint.
- Gameplay continues while player input is blocked.
- Mouse capture stays disabled while open; F10 and the title close button both
  restore the previous mouse mode.
- Debug tools do not initialize in release exports.
- English and Russian UI copy.

Design:
`docs/superpowers/specs/2026-07-29-f10-debug-panel-design.md`.

## Next

### Finish Level_01

- Continue building the complete tutorial/gameplay route.
- GUI-validate the implemented `PlayerLowPassage` flow in both directions,
  while idle under the ceiling, when reversing, and with an extended obstacle.
  The state now keeps the reduced capsule, provides slow manual movement, and
  restores standing only after stable clearance and a safe crouch-loop phase.
- Validate the ability-gated traversal sequence.
- Reach a complete playable loop before broad UI or environment polish.

### Vertical Slice Iterations (agreed 2026-10-28)

Design source: `docs/design/GDD.md`. One iteration per chat, verified in Godot
before the next one.

1. Done: free 3D camera by default; F4 camera toggle disabled through
   `GameConstants.CAMERA_TOGGLE_ENABLED` (code kept).
2. Level_01 flow: arena waves and reward chest, enemies along Zone02-05,
   fill empty Zone04-06 breakables, remove the duplicate `_setup_*` calls.
3. In progress: Level_01 finale "Сбой" — after the arena, fragile stones
   rise from the void (`CollapseRun`), crumbling path to `LevelExit`
   (demo complete -> main menu). Next: richer platforming Zone05 -> Zone06
   (Jump -> Double Jump -> Dash -> Slam chain). Later: separate prologue
   level with the Great Failure escape on Hearth Isle.
4. Zone dressing via an editor `@tool` script (deterministic, re-runnable):
   grass -> ruins -> sand rocks -> lava teaser near the arena, using the
   existing `Mat_*_1k` materials and rock meshes.
5. Second enemy: Ancient Guardian mini-boss (scaled Monstr.glb, stone
   material, slow slam + spinning laser that requires Roll).
6. Main menu: 3D floating-island background with clouds, animated title,
   working Settings (volume, sensitivity, invert Y).
7. Done (prototype): Perfect Dodge — enemy hit lands in the first 0.3 s of
   Roll -> slow-mo, Vabo flash, roll charge refund, red-charged fists (x2
   damage, lethal-level hit stop, finisher knockback, 5 s lifetime).
8. Cleanup: `UI/` vs `res://ui/` case mismatch, tracked `*.tmp`/`.blend1`
   files, Level_01 dependency on `levels/test_level/enemy_spawner.tscn`.
9. Ability reveal through Vabita's spirit instead of chest drops: a ghostly
   low-poly variant of the player mesh with a glowing ghost shader,
   particles, short memory line; also used at key story beats.
10. Pause menu (resume, settings, restart from checkpoint, main menu) and a
    richer main menu.
11. Enemy AI bug pass and more interesting behaviour; animation polish for
    the player and enemies; general balance tuning.

### Save and Collectibles Rules (agreed 2026-10-28)

- Autosave on entering key places through `AutosaveZone`; Memory Nodes stay
  as manual heal + save points.
- Hand-placed Vabo is collected once per level visit: it does not come back
  after death, checkpoint reload, or Continue. It respawns when the level is
  entered again from another level (hub revisit). Collected IDs follow the
  same banking as Vabo: lost together if the player quits before a save.
- Enemies, crates, and their drops respawn after death (farmable).
- Abilities, opened chests, and cleared arenas are permanent.

### Progression and Hub

- Spend Vabo through the Keeper of Memory.
- Health upgrades.
- Ability upgrades and Tkakamcha modifiers.
- Return portal and level selection through the hub.

## Later Polish

- Add runtime object inspection and numeric transform editing to the F10 panel.
- Balance Vabo farming from respawned enemies and crates.
- Tune checkpoint spacing after `Level_01` is fully playable.
- Add unique Memory Node VFX, audio, and activation animation.
- Add save-slot selection only if the project actually needs multiple slots.

## Archived / Not Active

- Experimental distant-cloud streaming and impostor LOD remain on the
  `codex/cloud-lod` branch and are not part of the current roadmap.

### Enemy AI and Tooling (2026-10-28)

- Tier-1 enemy Gogo Runt: `tools/blender/gen_gogo_runt.py` -> `GogoRunt.glb`
  (own mesh, 20-bone rig, 12 actions named like Monstr for the shared
  AnimationTree), `entities/enemies/enemy_gogo_runt.tscn`. Hits scripted via
  `Enemy.fallback_attack_hit_times` (glTF has no method tracks).
- AI: slot ring around the player (AIDirector, rotating, flank-aware,
  navmesh/wall-validated), CombatStance waits on its slot and engages only
  with an attack token, chase loses track after 4 s, navmesh-projected
  retreats, no wall ramming.
- F10 panel: god mode, infinite HP/abilities, fly speed, time scale, enemy
  spawn/kill/freeze, AI/nav/collision debug, checkpoints teleport, stats.
  Hotkeys Alt+1..6. AI test arena: `levels/test_level/ai_test_arena.tscn`.
