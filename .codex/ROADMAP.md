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

## Next

### Player Progress Feedback

- Show current Vabo in the HUD.
- Clearly show unlocked movement/combat abilities.

### F10 Debug Panel

- Toggle a left-side debug panel with `F10`.
- Delete/reset the current save from the panel.
- Inspect the selected scene object.
- Move, rotate, and scale the selected object with numeric controls.
- Keep the panel extensible for checkpoint, progression, graphics, cloud, and
  gameplay debug actions.
- Make all debug tools unavailable in release exports.
- Use localization keys for visible labels and confirmation dialogs.

The first panel version should prioritize save reset and common gameplay
controls. Runtime scene editing can be added incrementally instead of building
a full editor replacement.

### Progression and Hub

- Spend Vabo through the Keeper of Memory.
- Health upgrades.
- Ability upgrades and Tkakamcha modifiers.
- Return portal and level selection through the hub.

## Later Polish

- Balance Vabo farming from respawned enemies and crates.
- Tune checkpoint spacing after `Level_01` is fully playable.
- Add unique Memory Node VFX, audio, and activation animation.
- Add save-slot selection only if the project actually needs multiple slots.

## Archived / Not Active

- Experimental distant-cloud streaming and impostor LOD remain on the
  `codex/cloud-lod` branch and are not part of the current roadmap.
