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
