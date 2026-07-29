# Cloud Rollback and Stabilization Design

## Goal

Return the cloud visuals and distribution to the known-good `741627c` state, while preserving the useful smooth LOD transition and matched billboard lighting. Remove the later experimental background-cloud architecture that introduced a visible sky seam, shader errors, sparse formations, and vertical popping.

## Safe rollback strategy

- Keep `db93641` as the pushed backup of the complete experimental state.
- Revert the cloud architecture through normal Git history instead of rewriting or resetting the branch.
- Restore cloud-facing files to their `741627c` behavior selectively, so unrelated project and user changes remain untouched.
- Preserve the WeatherManager only where it is independent and useful for shared wind control; remove its far-sky and coarse weather-field dependencies.

## Resulting cloud architecture

- `CloudManager` again creates the attractive deterministic overlapping clusters from `741627c`.
- Existing volumetric, cheap-volume, and billboard LODs remain.
- Billboard and volumetric lighting continue to share day/night reference lighting, including the fixed lower shadow.
- LOD changes continue to use shader dithering rather than renderer visibility fading, so transitions also work on mobile renderers.
- Far-sky quad clouds, coarse `CloudWeatherField`, `DriftRoot`, lifecycle dissolve, and the regenerated experimental cloud layout are removed.

## Noise and movement

- Cloud shape noise is no longer sampled from player-relative or recycled world position.
- Each cloud keeps a stable per-instance shape seed.
- Wind adds one slow global offset to the noise, controlled by WeatherManager when available.
- Moving the player or recycling a cloud does not visibly slide or replace its internal shape.

## Verification

Static tests must verify:

1. deleted experimental layers are no longer referenced;
2. both cloud shaders use stable per-instance noise plus global wind;
3. world/player position is absent from cloud shape-noise coordinates;
4. dither LOD and reference-lighting uniforms remain present;
5. project resources and scene references resolve without obvious missing paths.

Manual Godot verification is required because launching the Steam editor from automation previously caused native memory crashes:

1. open `level_01`;
2. confirm the old attractive clustered formations are back;
3. fly through clouds and confirm noise does not move with the player;
4. check day/night lighting and billboard transitions;
5. report console errors and a screenshot before further cloud work.

## Deferred follow-up

Do not add runtime capture or a new impostor baker in this rollback. After the restored system is visually approved, a separate task can create 3–5 manually authored cluster archetypes and bake full-sphere impostor atlases offline. This keeps the current recovery small and reversible.
