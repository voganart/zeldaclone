# Roll Low Passage Design

## Goal

Make Roll traversal under low ceilings physical and predictable without
depending on collision tunneling, forced ejection, or obstacle length.

## Confirmed Geometry

`Obstacle_roll` has a collider only above the player. The volume below it is a
real physical opening that fits the reduced player capsule.

## State Flow

1. `PlayerRoll` starts normally, immediately switches to the reduced capsule,
   consumes a Roll charge, and uses the existing Roll root motion.
2. At the end of the Roll animation:
   - if the standing capsule fits, restore it and transition to `PlayerMove`;
   - if it does not fit, keep the reduced capsule and transition to
     `PlayerLowPassage`.
3. `PlayerLowPassage` plays the existing looping `Roll_crouch_loop` animation
   at reduced playback speed and accepts normal horizontal movement input at a
   reduced movement speed.
4. When the standing capsule fits continuously for `0.1` seconds, request an
   exit but keep the reduced capsule.
5. Restore the standing capsule and transition to `PlayerMove` only inside the
   safe phase window around the start/end of `Roll_crouch_loop`, after one
   final clearance check.

The low-passage state has no fixed duration, so the same behavior supports
short and arbitrarily long obstacles and allows the player to move back out.

## Gameplay Rules

- Roll distance remains determined by the normal Roll animation/root motion.
- Low-passage movement is input-driven; there is no automatic push or
  teleport to an exit.
- The player may move forward, backward, or sideways while crouched.
- Roll invulnerability ends when the normal Roll ends.
- Jump, attack, and another Roll are unavailable in `PlayerLowPassage`.
- The reduced capsule must never be restored while the standing capsule
  overlaps the ceiling.
- The loop must not transition to standing from an arbitrary rotational pose.

## Components

- `PlayerRoll`: owns only the timed Roll and chooses its exit state.
- `PlayerLowPassage`: owns crouched movement, looping animation, restricted
  actions, and safe stand-up.
- `Player`: owns capsule resize/restore and standing-clearance queries.
- `AnimationController`: selects `Roll_crouch_loop` and exposes its playback
  speed without changing the source animation asset.

## Physics Requirements

- `move_and_slide()` is called only by the common player physics loop.
- Both Roll root motion and low-passage input become velocity/motion before
  that single call.
- The standing-clearance query uses the complete standing capsule at the
  player's intended standing transform and includes the obstacle collision
  layer.
- Passage speed is a gameplay tuning value, not a collision escape force.

## Failure Handling

- If there is no movement input, the player remains safely crouched.
- If movement is blocked by another collider, normal CharacterBody collision
  response stops the player; no forced depenetration is added.
- If the player leaves the passage in either direction, the same clearance
  check restores normal movement.

## Verification

Automated contract tests must cover:

- Roll transitions to low passage when standing clearance is blocked.
- Roll transitions directly to move when standing clearance is free.
- Low passage retains the reduced capsule while blocked.
- Low passage restores the standing capsule only after clearance.
- Low passage has no Roll invulnerability and blocks jump/attack/Roll.
- Movement remains centralized to one `move_and_slide()` call.

GUI smoke test in `Level_01`:

- enter the current obstacle from both directions;
- release input and remain safely under it;
- reverse direction and leave through the entry side;
- traverse fully through the exit side;
- verify short and extended obstacle lengths with visible collision shapes;
- confirm there is no snap, penetration, or forced ejection.
