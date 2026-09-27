# Stroke feel

Phase 3 (Genesis creation). A land stroke should read as cause and effect:
the ground rumbles as land rises, fog parts over what you made, the air swells
and trees sway harder, and plants under the brush sprout again.

## Pieces

- `NativeChunkEditor` emits `stroke_started(center, radius, mode)`,
  `stroke_moved(center, radius, mode, amount)` and
  `stroke_finished(center, radius, mode)`. Centre is world space, radius world
  units; `amount` is the brush strength one dab batch spent (seconds for trails).
  A single mountain click emits start and finish in the same frame.
- `scripts/stroke_feedback.gd` (child of the fidelity scene, `StrokeFeedback`)
  listens and drives:
  - **Tremor**: holds `reference_tremor` trauma near `RUMBLE_MAX` scaled by
    rise speed (the `formation_feedback` idea). Kicks stay under the creature's
    0.2 stumble threshold; a mountain gives one `MOUNTAIN_THUMP`.
  - **Wind**: `atmosphere.swell` eases to `SWELL_LAND`/`SWELL_GROWTH` during a
    stroke and back to zero after. It only feeds `zs_wind_strength` and the
    ambient wind audio, not saved state or creature physics. Land strokes also
    send an atmosphere puff every `GUST_INTERVAL`, which tears fog and pushes
    foliage across the brush.
  - **Fog reveal**: global `zs_reveal` (xz, radius, strength) thins
    fog over the stroke's bounds, holds `REVEAL_HOLD` s after release, then
    closes slowly. Read by `reference_air_sample` (display fog),
    `reference_fog` and `living_fog` (FogVolumes).
  - **Growth wave**: six globals `zs_growth_wave_N` (xz, radius, progress).
    Plants the wave covers shrink away (`WAVE_SHRINK_SECONDS`) and replay the
    usual seeded easeOutBack pop over `WAVE_SECONDS`. Plant shaders read
    `min(zs_growth.y, zs_growth_wave_at(xz))`, so with no wave active the global
    grow-in behaves exactly as before. Overlapping waves combine by the most
    advanced one, and all retire together once grown, so a plant pops once per
    pass.

  - **Arrival gusts**: emerged trees come 5-23 s after a forest stroke, long
    after its swell has eased (`SWELL_HOLD` 0.8 s). Emergence emits
    `tree_arrived(p, born)` for each tree it places. When a batch's birth
    comes, the feedback sends one light puff (`ARRIVAL_PUFF` 0.3, against 0.45
    for a stroke's puffs) at the batch's middle, at most every `ARRIVAL_GAP`
    (1.2 s). A puff starts 5 m upwind and travels with the air, so it reaches
    the trees about when their 1.8 s rise ends, and they sway as they settle
    in. It is local: the global swell is untouched. Any emerged tree gets one,
    so trees that follow a land stroke settle the same way.
    `studies/atmosphere.gd` `send_gust` takes an optional strength for this.

All tunables are constants at the top of `scripts/stroke_feedback.gd`.

## Rumble and pour

Long world changes (Regenerate landscape, New open plain, and anything else
that takes seconds to resolve) hold a rolling rumble and pour a heavy fog
across the plate. `scripts/world_rumble.gd` (`WorldRumble`, the fidelity
scene's `world_rumble`) owns both. Tunables are constants at its top.

```gdscript
var rumble: Node = scene.get("world_rumble")
rumble.hold(&"mountain", 0.8)   # 0..1; call again to change it; strongest hold wins
rumble.release(&"mountain")     # the tail keeps rolling while the editor resolves
rumble.pour_fog()               # whole plate, rolls in from upwind, drains when the rumble eases
rumble.pour_fog(rect, 4.0)      # plate-metre rect, spreads from its middle, drains after 4 s
rumble.drain_fog()              # start the drain now
```

- **Envelope.** `level` eases toward the strongest hold (`RISE` 1.3/s up,
  `FALL` 1.1/s down). After the last `release`, a tail at `TAIL` (55%) of that
  hold keeps it rolling while the editor is still resolving: `forming`,
  `refresh_pending > 0` or `water_settling`. When none is, it eases out, gone
  in about 2 s. `holding` is true while any hold or the tail runs.
- **Tremor.** The level drives `reference_tremor.rumble`, a held displacement
  on its own clock (`rumble_clock`): a slower, rounder roll and heave than
  trauma's shake, with slow breathing swells and occasional surges
  (`PEAK` 0.36, `BREATH`, `SURGE`). It never decays by itself and never emits
  `shaken`, so creatures do not stumble through it. Trauma kicks (formation
  kicks, the mountain thump) stay as sharp accents on top. `tremor.enabled`
  turns both off.
- **Sound.** GenesisAudio's rumble voice follows `strength` (up to 85% of
  `RUMBLE_GAIN`, pitch 0.78-0.95) whenever that is louder than the stroke's
  rumble, and plays through a paused world clock.
- **Pour.** Globals `zs_pour` (amount, lid depth above the plate floor, front
  0..1, flow clock) and `zs_pour_area` (xz centre, radius; 0 is the whole
  plate). `zs_pour_at` in `reference_globals.gdshaderinc` fills the low
  ground up to a churning lid (`POUR_DEPTH` 2.4 m) with a thin skin on the
  slopes. It reads the drawn ground (`zs_drawn_ground`, which follows
  `zs_growth.x`), so the fog sits on the old land as it sinks, the new land
  rises out of it, and it pools in the valleys as they form. The front rolls
  in over `ROLL_IN` (2.6 s). Draining lowers the lid to `DRAIN_DEPTH` first,
  so it sinks into the valleys, then thins it away. Read by the display fog
  (`reference_air_sample`, which also tints it toward the fog colour) and the
  native fog volume (`reference_fog`). It ignores the stroke reveal.
- **Regrowth** (`scripts/cozy_regrowth.gd`): holds `regrow` from the start,
  0.55 -> 0.85 as the old land sinks, 0.8 while the new one is made, 1.0 as it
  rises and down to 0.6 as the plants arrive, then releases it when the new
  place is ready. It pours over the whole plate at the start and drains at
  45% of the grow-in, just as the land finishes forming. Headless, with seed
  184: busy 9.2 s, rumble gone 13 s, fog gone 11.5 s; a new plain is 8.5 s,
  12.4 s and 10.8 s.
- **Cost.** About 1 us a frame while active; two globals written only while
  they move. Shader cost is one two-octave noise per fog sample, only while
  `zs_pour.x > 0`.

`tools/probe_regen_envelope.gd` prints the envelope over a regenerate and a
new plain, headless.

## Cost

No per-frame allocation. Globals are written only while they change: the
reveal while it is open, and each wave slot while it is animating. Shader cost
is one six-slot loop per plant vertex (inside `plant_growth` only) and per
grass clump, plus one distance per fog sample.

## Checking it

Headless runs do not compile shaders, so the shader side is unverified until
launch (`./run-cozy-flow.command`). Paint with Raise over a planted area:

- the camera should rumble softly while the brush is down and stop on release;
- fog over the stroke should thin within about a second and drift back a few
  seconds after release;
- trees and grass should sway harder during the stroke, then settle;
- plants under the brush should shrink and pop back behind it, staggered,
  while plants away from the stroke do not move.

Wave coverage is applied in `reference_surface`, `layered_tree_wood`,
`layered_canopy_surface` and `dense_grass`. The `prototype_*` study shaders
keep the plain global grow-in.
