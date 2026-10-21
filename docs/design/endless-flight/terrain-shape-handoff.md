# Endless flight, terrain round: mountain ranges and valleys

The ask: "more interesting terrain": more mountains, and valleys.

## Launch

- Mac: `./run-endless-flight.command [--seed=7]`
- Any: `godot --path . res://studies/endless_flight.tscn -- --no-title [flags]`
- A range on seed 1: `--at=-700,-300 --heading=66 --alt=90`. Down a valley: `--at=400,-1065 --heading=22 --alt=35`. Ranges from high up: `--at=200,900 --heading=95 --alt=150`.

## What changed

- `scripts/endless/land_field.gd`, the land's shape (still pure GDScript; there is no native version of this field):
  - **Ranges.** Long, winding mountain ranges now run along the crest lines of a warped noise (`RANGES`, `WARP`, `RANGE_WIDTH`), wherever a broad mask allows (`RANGE_MASK`, `RANGE_BAND`). Each range has a massif under ridged crests (`RIDGES` 700 m). Its height varies along the range, from 95 to 215 m over the lowland (`PEAK_TALL`, `PEAK_SCALE`), so peaks run 140 to 240 m over the sea. Snow starts at `SNOW` 125 m over the sea (the ground shader gets the line from `field.snow_line()`). Land over 80 m now covers 9 to 17% of the land, against 1 to 3% before.
  - **Valleys.** Valleys are carved along the zero lines of another warped noise (`VALLEYS` 2100 m, `VALLEY_WARP*`). They are long, winding and never end, and they cut through the ranges and the hills alike. Each has a flat U floor about `WorldScale.opening(TOY_VALLEY)` wide (50 toy, so 100 m at the knobs), which swings 0.75 to 1.7x along the valley (`VALLEY_SWING`). Its sides run 150 m through the ranges (steep, rock) and 300 m through the hills (gentle) (`VALLEY_SIDE`). The floor sits at the lowland's level and is painted as a meadow, so the grass and flowers grow there. Distance to the valley's line is read as |noise| over its gradient (2 extra noise reads).
  - `--old-land` gives back round one's land exactly (`_old_sample`), and round one's ceiling with it.
- **The ceiling.** `scripts/sky_glide.gd` gains `var ceiling_y := CEILING`, which `sky_plane.gd` uses too. This is a shared change, but its default is unchanged, so the isles fly as before. The endless flight sets it to `SEA_Y+CEILING_OVER` (215 m over the sea, or 175 in world y, against 135 over the sea before). You can fly over most ridges and passes, while the tallest peaks stand above the ceiling and into the cloud roof (the clouds' heights are unchanged). `SEA_Y` stays at -40.

## Flags

| Flag | What it does |
|---|---|
| `--mountains=X` | How much of the land the ranges cover. Default 1; 2 is about twice as much; 0 gives no ranges. |
| `--peaks=X` | Scales the ranges' height. Default 1. |
| `--valleys=X` | How deep the valleys cut. Default 1; over 1 their sides widen; 0 gives none. |
| `--no-valleys` | Same as `--valleys=0`. |
| `--old-land` | Round one's land and ceiling. |
| `--ceiling=M` | The plane's ceiling, in metres over the sea. Default 215. |

## Verified (M5 Pro Mac)

- Headless import: 0 errors.
- Smoke: these all PASS with 0 errors:
  - `endless_flight.tscn` as is
  - `endless_flight.tscn` with `--old-land`
  - `endless_flight.tscn` with `--mountains=2 --peaks=1.3 --no-valleys --ceiling=300`
  - `aqueduct_isle.tscn` and `flight_study.tscn` (they share the ceiling change)
  - `test_sky_plane.gd` passes.
- Flats check (`scratch/terrain/flats.gd`), over an 8 km square at 16 m, seeds 1, 3, 7 and 42:
  - A flat point has a slope of 0.06 or less across 64 m. A strip is 192 m of flat points in a row, along an axis or a diagonal.
  - 24 to 32% of the land is flat (round one's land: 25 to 29%).
  - Of about 600 land blocks of 256 m, these have no strip within 600 m:

    | | new land | old land |
    |---|---|---|
    | blocks with no strip within 600 m | 3 to 13 | 14 to 37 |
    | blocks with no strip within 400 m | 22 to 35 | 50 to 88 |

  - The worst block is about 1.0 to 1.3 km from a strip, about 50 s at cruise.
  - The valley floors and the meadows carry the strips. The check also writes shaded maps, `scratch/terrain/map_<seed>.png`, with the strips marked.
- Stream cost (`scratch/terrain/perf.gd`), flying from the seed 1 range, unpaced:

  | | new land | old land |
  |---|---|---|
  | land chunk build on a worker (mean) | 18.4 ms | 11.4 ms |
  | land chunk build on a worker (slowest) | 50 ms | 24 ms |
  | grass cell grow | 144 ms | 122 ms |
  | main-thread mesh commit (slowest) | 2.5 ms | 1.8 ms |

  The builds run on the workers, and the main thread's commit is about the same.
- Rendered stills (Forward+), judged by eye:
  - `scratch/terrain/range2.png`: a snowy range with ridges, flown along.
  - `scratch/terrain/valley1.png`: down a valley, with a meadow floor and steep rock walls.
  - `scratch/terrain/ranges_high.png`: ranges from high up, peaks into the clouds.

## Not verified

- How flight feels between the walls, and the hand landing on a valley floor: there was no play-loop landing run this round.
- Long flights.
- GPU frame time with the larger rock faces.

## Tests this breaks

None known. The full suite was not run.

## Notes for the arches round

- **Where arches go.**
  - Rock arches: on the range flanks and along the crests, where `mountain` in `sample` is about 0.3 to 0.7. Also across a valley's narrows, where its sides are steep (floor under about 1x).
  - Ruin arches: on the valley floors (a gate across the floor, its span from `WorldScale.opening`), and on the lowland meadows' edges. Keep them off the 192 m landing strips.
  - `sample` already computes `mountain` and the valley distance `d` against `half`/`side`. Expose them, say as `shape(x,z)`, so placement can ask the field.
- **Collision.** The flight treats the land as a pure heightfield. `plane.stone` returns true everywhere, and the ground, sight and hit callables in `studies/endless_flight.gd` (around lines 283-301) read `field.height`. A heightfield cannot hold an overhang. An arch needs:
  - its own solid test added to those callables, for example a list of arch volumes (boxes or capsules) near the eye, so the plane passes under the span and is turned aside by the legs;
  - colliders on layer 1 for the wheels and for walking;
  - the heightfield under the arch kept at the floor.

  The walls' steepness already turns the glide aside (`SkyGlide.STEEP` 1.0).
