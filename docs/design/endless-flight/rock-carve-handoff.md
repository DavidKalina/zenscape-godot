# Endless flight, rock carve round

The ask: the eroded walls still looked like a tarp draped over the land,
because all the relief was in the normals. This round carves the erosion
into the land's shape on steep rock, then fixes the rock shader to suit it.
It is a prototype round, with no committed tests.

## Launch

`godot --path . res://studies/endless_flight.tscn -- --no-title --seed=1 [spot] [flags]`

| Spot | Flags |
|---|---|
| valley wall | `--at=400,-1065 --heading=22 --alt=35` |
| range | `--at=-700,-300 --heading=66 --alt=90` |
| wall up close | `--at=-760,-420 --heading=40 --alt=45` |
| far | `--at=-700,-300 --heading=66 --alt=300` |
| middle distance (new) | `--at=-1100,-250 --heading=80 --alt=110` |

## What changed

- **`scripts/endless/land_field.gd`.** `sample()` is now `_broad()` (the land
  as it was) followed by `_carve()`. The carve is local and deterministic and
  streams per chunk, so meshes, colliders, grass, arches, the sea map, the
  cloud map and landing all read the same `height()`. No native version of
  the field exists, so nothing else needed the change.
  - **Mask.** The broad land's slope is read off an 8 m lattice
    (`CARVE_GRID`, cached and eased between nodes). The carve fades in over
    slopes of 0.38 to 0.9 (`CARVE_SLOPE`). It applies only where a range
    stands (`CARVE_MOUNTAIN`) and fades out at meadow 0.2 to 0.5.
  - **Blocks.** Voronoi cells of 32 m, each one a plane: the slope at the
    cell's centre, tilted and lifted at random, with sharp blends between
    cells. A wall breaks into planes, and its outline gets notches
    (`FACET_*`).
  - **Ledges.** Benches every 14 m of height. Their contours wander, and
    they appear only in bands (`BENCH*`).
  - **Gullies.** Waves run across the fall line at 36, 15 and 6 m spacing
    (10, 4.5 and 1 m deep). Each lattice cell has its own phase and spacing
    (±45%). Their strength is patchy along the run, and each size follows
    the slope the last one left, so they fork and stop. The grooves are
    narrow and the buttresses broad (`GULLIES`, `GULLY_*`).
  - **Valley floors.** A valley's carve never drops below its floor.
  - **Detail.** A chunk sets `field.detail` to its grid step. A size under
    3 to 5 steps fades out, and the carve is off at 16 m steps
    (`CARVE_FADE`, `CARVE_DETAIL_OFF`). The coarse sea and cloud maps set
    their texel the same way.
  - **Shader data.** `last_cavity` and `last_ridge` say where a point sits
    in a groove or a ledge's inner corner, and where on a crest or lip.
    `land_stream.gd` passes them to the shader as `CUSTOM0` (RGBA8).
- **`shaders/endless_rock.gdshaderinc`, `endless_ground.gdshader`.**
  - `er_rock` takes a new `vec2 carved` argument.
  - Grooves get darker and cooler, crests catch light, and the bounce light
    is lower inside grooves (`rock_carve_shade`).
  - The relief tile restarts per 70 m block, with its own offset and ±18%
    spacing. A second, wider, shifted sample blends in by slow noise. The
    big tile is at 0.45 of its old strength (`rock_relief_big`).
  - Pass 2's thin bed seams and lips are at 0.12 of their old strength
    (`rock_seams`), and the cell seam cracks and joints are calmed too. Bed
    tone steps are at 0.65 (`rock_beds`).
  - Pass 2's planes are back: `rock_plane_calm` is 0.1, so their tone and
    tilt are nearly as they were. `rock_calm` still quiets dry-brush.
- **`assets/textures/endless_rock_erosion.png`** is rebaked
  (`art/blender/rock_erosion/rock_erosion_build.py`). The tile's ledges are
  gone: they were the thin horizontal lines across the flutes. It now has
  three flute sizes, each in its own patches. `-- --ledges=0.7 --flutes=2`
  bakes the old tile.
- **`--rock-knob=name=value`** (`endless_look.gd`) sets any `rock_*` float
  uniform from the command line. It is repeatable.

## Flags

| Flag | What it does |
|---|---|
| `--no-carve` | The land uncarved (last round's shape), with the current shader. |
| `--rock-flat` | Pass 2's shader exactly. Add `--no-carve` for pass 2 as it was. |
| `--carve=X` | Carve strength (default 1). |
| `--carve-blocks=X`, `--carve-ledges=X`, `--carve-gullies=X` | Each form's share (default 1, 0 for off). |
| `--rock-knob=rock_seams=0.3` | Any shader knob: `rock_carve_shade` 1, `rock_seams` 0.12, `rock_beds` 0.65, `rock_plane_calm` 0.1, `rock_relief_big` 0.45, plus the old `rock_relief`, `rock_calm`, `rock_bump` and others. |

## Stills

The stills are git-ignored, in this worktree's `scratch/carve/`.

- **Last round's erosion (left) against this round's (right).**
  `sheet_erosion_{valley,range,wall,far}.png`. The left halves are the
  erosion round's `e3_*.png`.
- **Pass 2 (left, `--rock-flat --no-carve`) against this round's (right).**
  `sheet_pass2_{valley,range,wall,far,mid}.png`.
- **Singles.** `f2_*.png` (this round), `p2_*.png` (pass 2), and `c1` to
  `c7` (the iterations).
- **Top-down shaded relief maps, uncarved and carved.** `relief_*.png`.
  They come from `scratch/carve/probe.gd`.

## Flats check

`scratch/carve/flats.gd` runs headless: `python tools/godot.py -s res://scratch/carve/flats.gd -- --seeds=1,3,7,42`.
It uses the terrain handoff's definitions. The area is an 8 km square
sampled at 16 m. A flat point has a slope of 0.06 or less across 64 m. A
strip is 192 m of flat points in a row. Distances are measured from each
land block of 256 m.

| seed | flat % (uncarved / carved) | strip % | blocks with no strip within 600 m | within 400 m | worst block (km) | land the carve moves |
|---|---|---|---|---|---|---|
| 1 | 28.7 / 29.0 | 21.6 / 21.8 | 3 / 2 | 23 / 21 | 1.28 / 1.28 | 18.7% |
| 3 | 24.5 / 24.8 | 17.5 / 17.6 | 6 / 6 | 31 / 31 | 1.18 / 1.18 | 23.7% |
| 7 | 28.7 / 28.9 | 21.3 / 21.5 | 4 / 4 | 17 / 17 | 0.72 / 0.72 | 20.1% |
| 42 | 33.2 / 33.5 | 25.6 / 25.8 | 1 / 1 | 17 / 17 | 1.60 / 1.60 | 15.6% |

- **Meadows.** No point with a meadow of 0.5 or more moves.
- **Moved "flat" points.** The carve moves 9 to 19 "flat" points per seed
  by more than 0.5 m. All of them are range crests 110 to 150 m over the
  sea, symmetric ridge tops that the ±32 m test reads as flat. None is in
  a strip, and strip share went up slightly.
- **Valley floors.** These are untouched (the floor clamp plus the meadow
  mask), and the valley-floor meadows' edges are as before.

## Hand landing (play loop)

`scratch/carve/land.gd` drives the real input: F for flaps, stick pitch
from the move actions, and `fly_brake`.

```
python tools/drive.py scratch/carve/land.gd -- --scene-args --seed=1 --at=400,-1065 --heading=22 --alt=14
```

It touched down, rolled and stopped (phase `stopped`, so you can get out)
on the valley floor: meadow 0.82, 69 m off the valley's line, with a floor
half-width of 78 m. The second spot, `--at=-760,-420 --heading=40`, also
stopped (meadow 0.92).

## Build time

`scratch/carve/perf.gd` flies 1500 unpaced frames from the seed 1 range:
`python tools/drive.py scratch/carve/perf.gd -- --frames=1500 --scene-args --seed=1 --at=-700,-300 --heading=66 --alt=90 [--no-carve]`.
The machine was under load from other sessions (load average 6 to 8), so
both columns run slower than the terrain round's idle 18 ms mean and 50 ms
slowest. Compare the columns with each other.

| land chunk build on a worker | uncarved (`--no-carve`) | carved |
|---|---|---|
| mean, flying | 22 to 36 ms | 53 to 84 ms |
| slowest, flying | 32 to 56 ms | 120 to 190 ms |
| mean, first load (prime) | 20 to 23 ms | 31 to 39 ms |
| main-thread commit, slowest | 2 to 3 ms | 2 to 3 ms (unchanged) |

- **Where the time goes.** The carve costs about 4 to 5 µs of GDScript per
  rock sample, against about 1.3 µs for the whole broad sample. A chunk
  that is all rock pays about 20 ms more on an idle machine. Over the range,
  the stream built about 25% fewer chunks in the same frames.
- **What would cut it.** A native kernel for `_carve`. Or stop the carve
  one level nearer (`CARVE_DETAIL_OFF` 8, which drops the far ranges'
  carve past about 660 m). Or evaluate the carve on a 2 m lattice and ease
  between nodes.

## Smoke

`tools/smoke.py studies/endless_flight.tscn` passes with 0 errors with no
flag, `--no-carve`, `--rock-flat`, `--rock-flat --no-carve`, `--old-land`,
and `--carve=1.5 --carve-ledges=0 --rock-knob=rock_seams=0`.

## Unverified

- **GPU cost.** Not measured. It adds one more relief sample set (3 taps)
  where the second sample blends in, and a few ALU ops for the carve shade.
- **Shimmer and popping in motion.** The 6 m gullies fade in at level 0,
  inside about 166 m, so there may be a small pop there. Not checked in
  motion.
- **Flight between carved walls.** The walls are now rougher for the
  glide's steepness turn-aside, and that has not been flown.
- **Other seeds, night, and arches standing on carved flanks.** The arches
  read `height()`, so they sit on the carved land, but they were not
  looked at.
- **Close walls.** Up close, the cast shadows of the buttresses read as
  dark vertical blobs, and the near wall's foot still has last round's soft
  green smear (meadow paint on a steep foot).
- **Ledges.** Where they show, the ledges can give a peak a stacked,
  pagoda look. `--carve-ledges=0.5` or `0` tones that down. This is for the
  user to judge.

## Tests this breaks

None known. No test references `land_field.gd` or the endless shaders, and
the full suite was not run. `er_rock` changed its signature, but only the
ground shader calls it.
