# Player Progress Feedback Design

## Goal

Add a minimal readable progression layer to the existing gameplay HUD:

- show the current Vabo amount next to health;
- show every unlocked player ability in one consistent HUD area;
- keep locked abilities completely hidden;
- preserve the existing Roll and Ground Slam cooldown presentation.

This is an intermediate production UI. It should be clear and functional
without turning the task into final HUD polish.

## Scope

The first slice covers:

- a live Vabo counter in the top-left health area;
- an ability strip in the existing bottom-right actions area;
- the five saved abilities from `PlayerData`;
- three temporary icons for Double Jump, Air Dash, and 3-hit combo;
- reactive updates when Vabo or ability progression changes;
- non-runtime contract tests;
- handoff and roadmap documentation updates.

Final HUD art direction, elaborate unlock presentation, input prompts, tooltips,
and progression menus remain outside this task.

## Layout

### Vabo

The Vabo counter sits beside the existing heart display in the top-left HUD
area. It consists of a compact visual marker and the current numeric amount.
The value must remain readable as the number grows and must not shift or
overlap the heart row.

### Abilities

All unlocked abilities appear in a single bottom-right actions block.

- Locked abilities have no placeholder, silhouette, or empty slot.
- An ability becomes visible immediately after it is unlocked.
- Roll and Ground Slam retain their existing cooldown and charge behavior.
- Double Jump, Air Dash, and 3-hit combo are persistent unlocked-state
  indicators; no artificial cooldown display is added.
- The strip uses a stable authored order:
  `roll_ability`, `double_jump`, `ground_slam`, `air_dash`, `3_hit_combo`.

The container must reflow when hidden icons become visible, without leaving
gaps for locked abilities.

## Temporary Icon Set

Keep the existing `Roll.png` and `GroundSlam.png`.

Create three missing icons:

- Double Jump: two readable upward impulses;
- Air Dash: a directional airborne burst;
- 3-hit combo: three sequential attack marks.

Requirements:

- `128x128` PNG;
- transparent background;
- white, bold silhouette;
- no text, frame, gradient, shadow, or baked background;
- readable when displayed at approximately `64x64`;
- visually compatible with the existing temporary Roll and Ground Slam icons.

These are working assets and may be replaced during later UI polish.

## Runtime Architecture

`PlayerData` remains the source of truth for Vabo and permanent abilities.
`PlayerHUD` owns presentation only.

On HUD startup:

1. Read `PlayerData.current_vabo`.
2. Read the saved ability dictionary.
3. Apply the initial counter value and icon visibility.
4. Continue binding the existing player-instance ability cooldown data.

During play:

- `PlayerData.vabo_changed` refreshes the counter;
- `PlayerData.ability_unlocked` reveals the corresponding ability icon;
- scene reload or save load performs a complete initial HUD sync;
- duplicate signal connections must be avoided.

No new progression state is stored in the HUD or individual icon controls.

## Localization

The numeric Vabo display and icon-only ability strip do not require visible
labels in this slice. If a visible name, tooltip, or accessibility label is
introduced during implementation, it must use a key in
`assets/translations/texts.csv` with English and Russian values added
together.

## Error Handling

- Unknown ability keys are ignored without breaking the HUD.
- Missing optional icon textures hide only the affected indicator.
- A missing player instance must not prevent Vabo and permanent progression
  from being displayed from `PlayerData`.
- Editor preview must remain safe and must not depend on runtime autoloads.

## Verification

Automated PowerShell contract tests, without launching Godot, verify:

- Vabo UI nodes and `PlayerData.vabo_changed` integration;
- all five ability keys are mapped to HUD indicators;
- locked abilities are hidden rather than rendered as empty slots;
- the three new icon resources are referenced;
- release-independent HUD behavior does not introduce debug-only state;
- handoff and roadmap documentation record the completed feature.

Manual GUI Godot verification covers:

- Vabo appears beside hearts and updates after pickups;
- Vabo survives a death reload according to the existing session rules;
- each unlocked ability appears immediately and remains visible after reload;
- locked abilities leave no empty slots;
- Roll charges and Ground Slam cooldown still render correctly;
- all five icons are readable at gameplay scale and do not overlap at the
  target viewport.

## Completion Documentation

Every completed implementation task must leave concise context for later
Codex chats:

- update `.codex/HANDOFF.md` with what changed and any important constraints;
- move or mark the relevant item in `.codex/ROADMAP.md`;
- update `.codex/PROJECT_MAP.md` or `.codex/ENTRY_POINTS.md` when structure or
  entry points change;
- regenerate `.codex/project-index.txt` when project files are added, removed,
  or renamed.
