# Endless flight, rivers round

The ask: one river down each valley, painted in the ground shader with the
sea's water look, everything stepping around it, the plane meeting it as it
meets the sea, and `--no-rivers`. This is a prototype round, with no
committed tests. It is a checkpoint, and the look is a first try.

## Launch

`godot --path . res://studies/endless_flight.tscn -- --no-title --seed=1 [spot] [flags]`

| Spot | Flags |
|---|---|
| down a valley | `--at=400,-1065 --heading=22 --alt=35` |
| low along a river | `--at=400,-1089 --heading=18 --alt=6` |
| from high up | `--at=200,900 --heading=95 --alt=150` |
| a river mouth | `--at=-760,-1700 --heading=180 --alt=25` |

## What changed

- **`scripts/endless/land_field.gd`.** The river is part of the land's shape,
  so meshes, colliders, grass, arches, the sea's depth map and the flight all
  read the same `height()`.
  - **Line.** It runs along the valley's line, near one edge of the floor,
    at the foot of that side (`RIVER_HUG` 0.9 of the floor's half-width).
    A slow noise picks the side, so the river crosses the floor every few
    km (`RIVER_SIDE`). It meanders `RIVER_SWAY` over `RIVER_MEANDER` m. Its
    distance is in world metres: the noise's world slope scales the floor's
    warped units, so the width holds round bends and the river stays on the
    floor.
  - **Channel.** The water is 10 to 24 m wide (`RIVER_WIDTH`, over 820 m),
    with a ±28% pinch over 150 m (`RIVER_PINCH`). The banks stand 2 to 3 m
    over the water (`RIVER_DROP`) and run 8 m up to the floor
    (`RIVER_BANK`, smoothstep). The bed dips 0.6 m more under the drawn
    water (`RIVER_BED`). That dip is the wheels' ground; the shader draws
    the water flat. Coarse chunks fade the cut out, but the water is still
    painted on them.
  - **Level.** The water sits at the lowland's level under the valley (the
    continents, not the hills), `RIVER_DROP` under it, and never under the
    sea. So it falls towards the coast and meets the sea at sea level.
  - **Flow.** It runs downhill along the valley at 0.35 m/s plus
    `9·sqrt(fall)` (`RIVER_FLOW`). Where the level is about flat, the
    current stills (`RIVER_STILL`).
  - **Floor fixes, rivers on only** (see "The valley floor's height"):
    - The floor's cut comes in fully by `inland` 0.3 (`RIVER_INLAND`)
      rather than scaling by `inland`. It goes back to the old cut by half
      way up the sides (`RIVER_CUT_SIDE`).
    - Hollows under the floor are filled to it, out to 110 m past the floor
      (`RIVER_FILL_SIDE`).
    - By the river, the land is raised to the banks' top through a hollow,
      and eased down to it near a coast where the valley cuts little (a
      flood plain up to 26 to 40 m, `RIVER_PLAIN`). Where the land stands
      higher than that, or falls under the water (a lake), the river ends:
      its width tapers to 0.
  - **Reads.** `last_river` (distance outside the water's edge),
    `last_river_r/_w/_y/_flow`, `river_y(x,z)`, and `shape()`'s new
    `river`, `river_r`, `river_w` and `river_y` keys. All the changes are
    additive. Two existing lines changed: the old-land branch of `sample`
    and the valley's `keep` line, which is the same when rivers are off.
- **`scripts/endless/land_stream.gd`.**
  - CUSTOM1 (RGB float) carries the signed distance, the half-width
    (negative on the skirt) and the level.
  - CUSTOM0.zw carry the flow (±4 m/s).
- **`shaders/endless_ground.gdshader`.**
  - **Vertex.** The grid under the water is lifted to its level, so the
    water is flat. The colliders keep the bed.
  - **Fragment.** The water mask and banks are worked out per pixel from
    the interpolated distance, so a river stays crisp on coarse chunks. The
    edge is ragged near the eye.
  - **Water.** It is unlit and drawn in EMISSION, as the sea is: the sea's
    colours by a depth faked from the way in from the bank, the bed through
    the shallows, the sky by fresnel with the cloud field mirrored, and a
    dim "banks" band low in the mirror (the ground has no screen march).
  - **Sun and surface.** The sun's path and glitter, the ripples' faces lit
    toward the sun (the sea's `body_shade`), and a pale edge line.
  - **Movement.** Ripples (the sea's chop maps) drift down the flow, drawn
    out along it, with faint current streaks.
  - **Banks.** The stones run 0.7 to 5.6 m out from the water, with a
    wet, darker rim. The carpet, the flower drifts and the grass paint stop
    there.
  - **Mouth.** The painted water gives way to the sea where its level is
    within 0.35 m of the sea (`river_mouth`).
- **`scripts/endless/endless_look.gd`.** Passes the sea's chop maps and tints
  to the ground (`_river_water`). `--river-knob=uniform=value` sets any
  `river_*` uniform (str_to_var).
- **`scripts/endless/endless_grass.gd`, `endless_patch.gd`.** No tuft or
  flower grows on a bank's stones. `EndlessPatch.river_bank` mirrors the
  shader's bank width, so the tufts stop where the stones start.
- **`scripts/endless/arch_plan.gd`.** No arch has a foot in a river or on
  its bank. An aqueduct across a valley slides along its line so the river
  runs through one of its openings, and there is none where no opening
  clears the river.
- **`studies/endless_flight.gd`.**
  - `plane.water` is the river's level over a river (`water_at`), so the
    plane skims it as it skims the sea.
  - `floor_at` is NAN on a river's water, as on the sea, so the hand
    landing can't touch down there.
  - The camera keeps above it, and the prop wash and the grass react skip
    it.

## Flags and knobs

| Flag | What it does |
|---|---|
| `--no-rivers` | The land, the arches and the grass exactly as on main (the flats check matches main to the metre). |
| `--river-width=X` | Width (1). |
| `--river-drop=X` | Banks' height (1). |
| `--river-cut=0` / `--river-fill=0` | Turn off the valley-floor fixes (the river then runs under walls and uphill in places). |
| `--river-knob=river_depth=Vector2(0.8,5.0)` | Any shader knob. |

The shader knobs:

- Water colour: `river_depth`, `river_tint_depths`, `river_light`,
  `river_absorb`, `river_bed_fade`.
- Ripples and current: `river_ripple_size`, `river_ripple_strength`,
  `river_streak`, `river_cycle`, `river_streaks`.
- Mirror: `river_fresnel`, `river_calm`, `river_shore_mirror`,
  `river_cloud_mirror`.
- Banks and edges: `river_bank`, `river_edge`, `river_body_shade`,
  `river_mouth`.

## Stills

Main's still is on the left of each sheet, this branch's on the right.
They are git-ignored, in this worktree's `scratch/river/`.

- `sheet_valley.png`, `sheet_low.png`, `sheet_high.png`, `sheet_mouth.png`.
- Singles: `main_*.png` and `after_*.png`.
- Iterations: `r1` to `r8`.
- Top-down maps: `z_*.png` and `s7*.png`, from `scratch/river/map.gd`.

Main's stills come from a `git archive main` copy at `/tmp/zs_main`. The
sheets are made by `scratch/river/sheets.sh`.

## The valley floor's height

`scratch/river/floor_probe.gd` walks the valley lines. On main the floor
does rise and fall along a valley:

- **Slowly.** The floor's level follows the continents, from 26 m down to
  3 m over the sea across a few km. Near the coast it drops fast.
- **In hollows.** Where the hills dip under the floor, the valley never cut
  them, so the floor follows the hollow. This is 17 to 22% of a valley's
  length, up to 15 m deep, with slopes up to 25% along the line.
- **In ranges near a coast.** The floor's cut scales by `inland`, so up to
  12% of the massif is left standing. The floor there stands 10 to 15 m
  over its own level and follows the range.

Rivers fix all three:

- The water follows the continents' level, which is smooth (0.1 to 1%
  falls inland, 3 to 6% near the coast). It flows down that, stilling
  where the level is flat.
- The hollows are filled.
- In ranges near a coast, the floor's cut comes in fully by `inland` 0.3.

So no river runs uphill. Where the level has a crest along a valley (km
apart), the flow stills to a pool and goes the other way past it. That is
not a real divide, but it doesn't read as uphill.

## Flats check (seeds 1, 3, 7, 42)

`python3 tools/godot.py -s res://scratch/river/flats.gd -- --seeds=1,3,7,42`

- It compares main's field (`scratch/river/main_land_field.gd`, from
  `git show main:`) against this branch's.
- Definitions are the terrain handoff's: an 8 km square at 16 m. A point is
  flat if its slope is 0.06 or less across 64 m. A strip is 192 m of flat
  points in a row. Distances are measured from 256 m blocks.
- River water and the first 2 m of its bank never count as flat.

| seed | flat % main / rivers | strip % | blocks with no strip within 600 m | within 400 m | worst block (km) |
|---|---|---|---|---|---|
| 1 | 29.0 / 30.7 | 21.7 / 23.2 | 2 / 1 | 21 / 18 | 1.28 / 1.28 |
| 3 | 24.8 / 26.0 | 17.6 / 18.3 | 6 / 2 | 31 / 22 | 1.18 / 0.64 |
| 7 | 28.9 / 30.3 | 21.5 / 22.1 | 4 / 6 | 17 / 19 | 0.72 / 0.77 |
| 42 | 33.5 / 34.9 | 25.8 / 26.3 | 1 / 1 | 17 / 17 | 1.60 / 1.60 |

- **Seeds 1, 3, 42.** Equal or better than main on every measure.
- **Seed 7.** Two more blocks over 600 m, two more over 400 m, and the
  worst block 50 m further. They are all in one place, by the square's
  edge (about 2500..2800, 3300..3800): a valley along a narrow coastal
  plain whose river took the seaward side.
- **What decided it.**
  - The stencil reads any drop over 3.84 m within ±32 m as not flat. A
    river in the middle of a floor left no strip on either side, so the
    river runs at the floor's edge.
  - The channel keeps under that drop: 2 to 3 m of bank plus 0.6 m of bed.
- **Land moved.** 23 to 27% of the land moves by more than 5 cm, nearly all
  of it valley floors and their lower sides: hollows filled, coastal range
  floors cut down, and the floor eased to the banks' top by the river.
  Main's meadows move by up to 30 m where a coastal range floor is cut
  down. `--river-cut=0 --river-fill=0` shows the river alone.

## Hand landing and the water (play loop)

The landing driver is `scratch/river/land.gd`. It uses real input: F for
flaps, stick pitch from the move actions, and `fly_brake`.

```
python3 tools/drive.py scratch/river/land.gd -- --scene-args --seed=1 --at=357,-1079 --heading=18 --alt=14
```

- **Beside a river.** It touched down, rolled and stopped (phase
  `stopped`, so you can get out) on the valley floor: meadow 1.0, inside
  the floor, 17.9 m from the water and 2.9 m over it.
- **East of it,** `--at=443,-1051`: it stopped 33 m from the water.
- **Over the river,** `--at=400,-1065 --heading=22`: the plane flew down
  the river skimming it. It touched down only as it came off the water
  onto the bank's foot, as it would off the sea onto a beach.

`scratch/river/skim.gd` holds the nose down over the water for 300 frames,
with flaps on:

| | over the water | touchdown | under the water |
|---|---|---|---|
| a river, `--at=400,-1089 --heading=18 --alt=4` | 0.90 m held (SkyGlide `SKIM`) | none | 0 frames |
| the sea, `--at=-1000,-1450 --heading=-60 --alt=4` | 0.84 to 0.93 m over the swell | none | 0 frames |

So the plane meets a river as it meets the sea. It skims and never lands
or crashes on either, and the landing treats the water as an edge
(`floor_at` NAN). The walker isn't built in endless flight: the landing's
OUT phase has no caller. When it is, `floor_at` and `field.river_y` give
the same edge the sea does.

## Build time (M5 Pro Mac; the machine was loaded, load average 8 to 10)

- **Single thread, same chunks interleaved.** `scratch/river/bench.gd`
  builds the 67² sample grids of 64 level-0, 36 level-2 and 16 level-4
  chunks round the valley spot. That is the worst case: every sample is
  within 80 m of a river.

  | field per chunk | main | rivers | `--no-rivers` |
  |---|---|---|---|
  | mean | 16.2 ms | 20.8 ms (+28%) | same as main |
  | slowest | 35.0 ms | 39.0 ms | same as main |

  Inside a river's band, a sample costs about +65%. The band is roughly a
  tenth of the land.
- **Flying, unpaced, 1500 frames** (`scratch/river/perf.gd`, run by
  `scratch/river/perf_ab.sh`). Main runs from `/tmp/zs_main`, rounds
  interleaved:

  | land chunk build on a worker | main | rivers |
  |---|---|---|
  | mean, range route | 52 to 100 ms | 127 ms |
  | mean, valley route | 86 to 112 ms | 129 to 219 ms |
  | slowest, range route | 105 to 230 ms | 262 to 272 ms |
  | slowest, valley route | 195 to 241 ms | 203 to 334 ms |
  | main-thread commit, slowest | 2.7 to 6.6 ms | 2.8 to 3.4 ms |

  The worker means swing about 2x run to run under this load. The grass
  cells also sample the field (now with the river) on the same workers,
  which adds contention.
- **What would cut it.** Moving the river's slow fields onto a lattice was
  tried and was slower in GDScript. A native kernel for the field is the
  real fix.

## Smoke

`tools/smoke.py studies/endless_flight.tscn` passes with 0 errors with no
flag, `--no-rivers`, `--old-land` and `--water=old`.

## Unverified and open

- **GPU cost.** The water is one branch per wet pixel: 3 to 6 texture
  taps, a cloud-map loop of 4 taps and the sky gradient. Not measured.
- **In motion.** The ripples' flow and the streaks drifting were not
  watched in a moving capture. There may be shimmer at range, and a pop
  where the cut fades in at about 8 m chunk steps (the water drops 2 to
  3 m there).
- **Look.** Still to judge:
  - The water is the sea's saturated blue, and close up it can read a
    little like a canal: an even channel with stone banks.
  - It has no shadows (it is unlit, as the sea is).
  - Night was not looked at.
- **Where rivers meet the land.**
  - Where a river crosses its floor (the side noise turning), it runs
    down the middle for a while.
  - Lakes the river meets end it (it tapers out at the shore), and where
    it resumes past a lake was not looked at.
  - Seed 7's coastal plain (above).
- **Ruins.** Aqueducts sliding over a river and arches kept off it were
  not looked at in stills.
- **Valley fog.** The parallel round's fog was not tried with rivers.
- **Painted or a ribbon?** The painted water holds up. A separate ribbon
  mesh isn't needed for this look. It would help only with shadows, a
  proper screen-space mirror, or water over a lifted bed far off (the
  water on coarse chunks sits 2 to 3 m high, on the floor).

## Tests this breaks

None known. No test references the endless land, grass, arches or
shaders. The full suite was not run.
