# Endless flight, rivers flow round

The user's report: "The rivers look like roads, and are flat, when they
should be more like rapids, or flowing." This is a prototype look round:
shader only, proved by a smoke check and before/after stills. There are
no committed tests.

## What changed (`shaders/endless_ground.gdshader`, river parts only)

- **White water by speed.** Broken water starts at 1.0 m/s and is full
  at 2.2 m/s (`river_rapids`). The land's speed comes from the level's
  fall, so the steep stretches near a coast run white. Riffle patches,
  48 m across, break up any running stretch (`river_riffle`). Still pools
  stay calm, and the white water settles into a mouth.
- **Foam.** Streaks drawn out down the flow, thin at their edges and
  thick in their cores. They drift at 1.8x the current, never under
  0.45 m/s (`river_flow_look`), and are re-made every 2 s, cross-faded
  (`river_foam_size`). They also show as:
  - a broken fringe along both banks, 0.6 m wide on calm water and 2.8 m
    on white water (`river_bank_foam`; this replaces the even pale edge
    line);
  - a front where the river meets the sea (`river_mouth_foam`).
  Far off, the foam becomes a soft whitening.
- **Calm water.** Thin streak lines, and broad slicks (4.5 m wide, about
  6x that long) that shade the body and the mirror (`river_slick`). The
  depth swings down the river (bars and pools), so the shallows' band
  never runs even.
- **White-water surface.** The body is aerated and paler, and the
  ripples churn rougher (`river_churn`). The normal leans down the fall.
  The geometry was already tilted per vertex; no stepping was found.
- **Fixes.**
  - The noise is now `ep_noise`, an integer hash. `zs_noise`'s sin hash
    showed lattice seams on NVIDIA.
  - The water's footprint is its own flat one (`r_fp`), not the bed's
    steep-ground one, which jumped between chunks.
  - The mouth now reads the drawn height, not the level's interpolation.
  - The old streaks turned their frame about the world's origin, so they
    squeezed far out. The new grain averages the noise along the flow
    and has no such frame.
- **Not done.** Small falls (optional). The land, its carving and the
  meadows are untouched.

## Knobs

`--river-knob=river_rapids=Vector3(1.0,2.2,1.0)`. Also `river_riffle`,
`river_flow_look`, `river_foam_size`, `river_bank_foam`,
`river_mouth_foam`, `river_churn` and `river_slick`. `river_edge` is
retired.

## Stills (seed 1, hour 10, `--no-valley-fog`)

These are git-ignored, in this worktree's `scratch/rflow/`. Each
`sheet_steep.png`, `sheet_calm.png` and `sheet_flat.png` has before on
the left and after on the right, high, mid and low. Singles are
`before_*.png` and `after_*.png`.

| Spot | Where | Speed |
|---|---|---|
| steep | (48,-24) | 2.5 m/s |
| calm | (-2440,1928) | 0.6 m/s |
| flat | (400,-1089), a valley crossing | 1 to 2 m/s |

The views are `scratch/rflow/views.ps1`. The film driver is
`scratch/rflow/film.gd`; its stills are 1.1 s apart.

## Open

- **In motion.** Not watched live: the film's stills are 1.1 s apart.
- **Coarse chunks.** The flow there is interpolated from vertices.
- **Valley crossings.** Where two valleys' rivers overlap, their flows
  cancel along a line. That line draws calm in white water (`after_flat_*`).
  This comes from the land data.
- **Old frame.** The old ripple layers still turn their frame about the
  origin (`zs_river_layer`).
- **GPU cost.** Not measured. A wet pixel adds about 28 value-noise taps.

## Tests this breaks

None known. No test references the ground shader. The full suite was not
run. The smoke check passes: `tools/smoke.py studies/endless_flight.tscn`,
with and without `--seed=1 --at=48,-24`.
