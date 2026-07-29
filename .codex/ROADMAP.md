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
- Redesign the rejected Roll tutorial fix: require real free collision volume
  under the obstacle, keep the reduced capsule in a low-passage state for
  arbitrarily long tunnels, and restore standing only after a clearance check.
  Design approved in conversation and documented in
  `docs/superpowers/specs/2026-07-29-roll-low-passage-design.md`.
- Validate the ability-gated traversal sequence.
- Reach a complete playable loop before broad UI or environment polish.

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
