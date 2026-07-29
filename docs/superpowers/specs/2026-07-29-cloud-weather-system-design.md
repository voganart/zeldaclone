# Cloud Weather System Design

## Goal

Replace the current narrow, expensive cloud-cell volume with a layered weather
system that:

- always provides distant cloud cover in every viewing direction;
- keeps a smaller set of enterable volumetric clouds near the player;
- produces natural cloud banks instead of repeated radial bouquets;
- moves, evolves, forms, and dissolves clouds slowly;
- drives grass, trees, water, physical clouds, and sky clouds from one manually
  controlled wind source;
- avoids frame-time spikes when coverage dimensions increase.

Automatic weather changes, rain, lightning, and gameplay effects are outside
this implementation. Weather values change only through the profile, Inspector,
debug panel, or explicit game code.

## Layered Cloud Architecture

### Far sky layer

Extend the active `sky_gradient.gdshader` with the useful two-noise cloud logic
already present in `assets/shaders/clouds.gdshader`.

The far layer:

- renders as part of the sky and follows the camera implicitly;
- covers the horizon, upper sky, and lower empty background with independent
  masks;
- uses half-resolution sky rendering;
- skips expensive cloud sampling during cubemap/radiance passes;
- shares day/night light and shadow colors with physical clouds;
- uses global weather direction, offset, strength, and evolution values;
- is atmospheric scenery and cannot be entered physically.

It is the permanent visual safety layer. Empty physical-cloud coverage must
never expose a completely blank sky.

### Physical near layer

Keep the existing `Cloud` scene, procedural Volume/Billboard shaders, LOD
controller, exclusion volumes, pooling, and dither transition.

Replace 120-meter full-volume cell enumeration with coarse weather chunks:

- default chunk size: 1000 m;
- horizontal and vertical chunk ranges are calculated independently;
- only a few hundred chunks may be examined during a full refresh;
- entering a new chunk reconciles only the new desired chunk set;
- member creation and relocation remain distributed across frames;
- physical pool capacity remains a hard limit, initially 72-96 on High.

Add horizontal and vertical prewarm/fade independently. Vertical chunk changes
use hysteresis, so ascending through a boundary does not remove one entire layer
and reveal another.

## Weather Field and Natural Formations

Create a deterministic low-frequency weather-density field. A chunk samples
this field before producing formations.

- Adjacent high-density chunks form broad cloud banks and fronts.
- Low-density regions produce natural gaps.
- Density controls formation count, member count, scale, and thickness.
- Formation offsets are elongated and asymmetric rather than radial.
- Wind direction influences elongation but does not instantly rotate existing
  formations when the user changes wind.
- World seed, chunk coordinate, formation index, and member index preserve
  deterministic identity.

The same weather field is sampled in advected coordinates. As accumulated wind
offset changes, formations enter from the upwind side and leave downwind.

## Physical Drift and Lifecycle

Pooled clouds live under one `CloudDriftRoot`. WeatherManager advances a global
cloud offset. Moving the root moves all active cloud nodes with one transform
update rather than updating every cloud transform every frame.

Streaming evaluates the player in weather-field coordinates:

`virtual_player_position = player_position - accumulated_cloud_offset`

This causes the deterministic field to drift through the world while preserving
formation identity. The drift root is periodically rebased by whole chunk
increments to avoid unbounded coordinates.

Each formation receives deterministic lifecycle values:

- lifetime measured in several real-time minutes;
- long fully visible phase;
- slow formation and dissolution fades;
- small per-member phase offsets so a bank erodes progressively;
- lifecycle updates at low frequency, not every frame.

Lifecycle fade multiplies recycle fade and boundary fade in
`CloudLodController`. Both cloud shaders discard before raymarching when the
combined fade is effectively zero.

Noise motion has two components:

- advection follows wind direction and cloud speed;
- evolution moves through a separate noise axis slowly, changing the form
  without making it boil.

## WeatherManager

Create autoload `WeatherManager` backed by
`common/weather/weather_profile.tres`.

`WeatherProfile` exposes:

### Wind

- `wind_direction`: normalized horizontal direction;
- `wind_speed`: world drift speed;
- `wind_strength`: vegetation/water response;
- `wind_turbulence`: small-scale variation;
- `manual_blend_duration`: smoothing after a manual edit.

### Clouds

- `cloud_drift_multiplier`;
- `cloud_noise_advection`;
- `cloud_evolution_speed`;
- `formation_lifetime_min`;
- `formation_lifetime_max`;
- `formation_fade_duration`.

WeatherManager owns smoothed current values and accumulated cloud offset. It
provides setters and `apply_profile(profile, blend_duration)` but does not choose
profiles automatically.

It writes canonical global shader parameters:

- `weather_wind_direction`;
- `weather_wind_speed`;
- `weather_wind_strength`;
- `weather_wind_turbulence`;
- `weather_cloud_offset`;
- `weather_cloud_evolution`.

Compatibility adapters update existing consumers:

- call the `SimpleGrass` singleton wind setters instead of modifying the addon;
- mirror direction/strength into existing water globals
  `wind_direction` and `wind_intensity`;
- convert `TreeWindShader.gdshader` to canonical weather globals;
- route legacy island-grass wind values through the same manager where that
  scene is used;
- make both physical cloud shaders and the far sky shader consume canonical
  weather values.

WeatherManager is the only runtime writer of shared wind state.

## Manual Workflow

Extend the existing F10 panel with a Weather section backed by the same
`WeatherProfile` resource.

The user can change direction, speed, strength, turbulence, cloud drift,
evolution, lifetime, and fade duration while flying. Changes blend over
`manual_blend_duration`.

`Save Project` saves both cloud and weather resources. `Reload Saved` reloads
both. Existing user-tuned values in `cloud_tuning_profile.tres` must be
preserved; new fields receive defaults without resetting current overrides.

No automatic Calm/Breezy/Storm selection is included. Named preset resources
can be added later through the same `apply_profile` API.

## Performance Constraints

- Far clouds run at half resolution and skip cloud work in cubemap passes.
- Physical coverage changes do not enumerate fine 3D grids.
- Weather field sampling occurs only on coarse chunk reconciliation.
- Pool capacity remains fixed.
- One drift-root transform moves all physical clouds.
- Lifecycle evaluation runs at low frequency.
- Zero-fade clouds exit shaders before raymarch loops.
- Existing Billboard and Cheap Volume LOD remain the dominant distant physical
  renderers.
- No runtime Viewports, captures, baked atlases, or per-frame material
  duplication.

## Failure Handling

- Missing WeatherProfile uses safe in-code manual defaults and reports one
  warning.
- Missing SimpleGrass autoload skips only the grass adapter.
- Missing far-cloud textures disables far clouds but keeps the sky gradient.
- Invalid zero wind direction retains the last valid direction.
- Lifetime maximum is clamped to lifetime minimum.
- Chunk generation is deterministic even when weather materials are missing.

## Validation

Automated/static tests verify:

- WeatherProfile sanitization and WeatherManager manual smoothing;
- canonical shader globals exist and have one runtime writer;
- SimpleGrass and water compatibility mapping;
- physical and sky cloud shaders consume the same wind direction and offset;
- coarse chunk iteration stays bounded independently of the old cell size;
- weather-field output is deterministic and spatially correlated;
- vertical prewarm and hysteresis preserve overlapping layers;
- drift-root rebasing preserves world placement;
- formation lifecycle fade is slow, deterministic, and clamped;
- zero combined fade exits before cloud raymarch;
- the existing LOD-lighting, exclusion, tuning-panel, and debug-flight
  regressions remain green.

Manual verification:

1. Look up, down, and 360 degrees before moving; far clouds remain present.
2. Ascend and descend across several chunks; no complete cloud layer switches.
3. Fly for several minutes; physical banks drift consistently with sky clouds.
4. Observe formations slowly changing and dissolving without rapid noise boil.
5. Edit wind direction and strength in F10; grass, trees, water, and both cloud
   layers transition together.
6. Compare average FPS and 1% Low while flying through chunk boundaries.
7. Verify physical clouds remain enterable and respect island exclusion volumes.
