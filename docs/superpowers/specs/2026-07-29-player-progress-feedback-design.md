# Player Progress Feedback Design

## Goal

Add a minimal readable progression layer to the existing gameplay HUD:

- show the current Vabo amount directly below health;
- show every unlocked player ability in one consistent HUD area;
- keep locked abilities completely hidden;
- preserve the existing Roll and Ground Slam cooldown presentation.

This is an intermediate production UI. It should be clear and functional
without turning the task into final HUD polish.

## Scope

The first slice covers:

- a live Vabo counter below the top-left heart row;
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

The Vabo counter sits on its own row below the existing heart display in the
top-left HUD area. A vertical `HealthStack` owns the heart row and a
`VaboOffset` margin wrapper. Designers adjust `VaboOffset` left and top
margins without changing script node paths or fighting container alignment.

The visible `Vabo` word is replaced by a compact white diamond icon matching
the temporary ability-icon style. The numeric amount sits to its right. The
value must remain readable as the number grows and must not shift or overlap
the heart row.

### Abilities

All unlocked abilities appear in a single bottom-right actions block.

- Locked abilities have no placeholder, silhouette, or empty slot.
- An ability becomes visible immediately after it is unlocked.
- Roll retains its existing charge presentation.
- Double Jump is white while the second jump is available, becomes gray after
  the second jump is consumed, and returns to white on landing. It does not
  gain a new timer.
- Ground Slam retains its existing radial cooldown.
- Air Dash uses its existing `cooldown_timer` and `air_dash_cooldown` for a
  radial cooldown display.
- 3-hit combo uses the existing `combo_cooldown_timer` and
  `combo_cooldown_after_combo` for a radial cooldown display after the third
  attack.
- The strip uses a stable authored order:
  `roll_ability`, `double_jump`, `ground_slam`, `air_dash`, `3_hit_combo`.

The container must reflow when hidden icons become visible, without leaving
gaps for locked abilities.

## Temporary Icon Set

Keep the existing `Roll.png` and `GroundSlam.png`.

The temporary set contains:

- Double Jump: two readable upward impulses;
- Air Dash: a directional airborne burst;
- 3-hit combo: three sequential attack marks.
- Vabo: a simple readable diamond marker.

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
- player runtime state drives ability readiness and cooldown fill;
- Double Jump availability is derived from `current_jump_count`;
- Air Dash fill is derived from its existing float cooldown values;
- combo fill is derived from the existing `Timer`, only after the three-hit
  finisher starts its cooldown;
- scene reload or save load performs a complete initial HUD sync;
- duplicate signal connections must be avoided.

No new gameplay timers or progression state are stored in the HUD or
individual icon controls.

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
- the four temporary icon resources are referenced;
- Double Jump uses availability tint rather than a fake timer;
- Air Dash and 3-hit combo read their existing cooldown sources;
- release-independent HUD behavior does not introduce debug-only state;
- handoff and roadmap documentation record the completed feature.

Manual GUI Godot verification covers:

- Vabo appears below hearts and updates after pickups;
- `VaboOffset` margins move the Vabo row without breaking script paths;
- Vabo survives a death reload according to the existing session rules;
- each unlocked ability appears immediately and remains visible after reload;
- locked abilities leave no empty slots;
- Roll charges and Ground Slam cooldown still render correctly;
- Double Jump turns gray after the second jump and white on landing;
- Air Dash and 3-hit combo show radial cooldown recovery;
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
