# Endless flight: bare patches in the grass (prototype round)

The user's "really ugly rough spots" were dark-green stretches with no
tufts, where the painted ground showed through smeared: hillsides, a strip
down a valley side, the sides of hollows. Stills of seed 1 found the same
spots (`captures/bare-patches/before_*`).

## The cause

The carpet's mask (`scripts/endless/endless_grass.gd`, the probe in
`grow_cell`) was narrower than the turf the ground paints:

- **Slope.** Tufts grew only where the normal's up was over 0.905 (full
  past 0.95), so none on turf steeper than about 25 degrees. The paint
  draws turf down to the rock's edge at 0.80 (37 degrees). Every slope in
  that band was bald: 5% of the 3 to 36 m turf on seed 1, nearly all of it
  on hill and hollow sides, and 10% more thinned.
- **Height.** Tufts thinned out from 36 m over the sea and were gone by
  58 m. The paint only turns to tundra from 42 to 78 m (shifted 15 m
  either way by its broad patch), so green hills from about 45 to 80 m
  were bald.

Where no tufts grow, the paint takes the carpet's far tone (darker), and
up close its grain is soft value noise drawn along the view. That is the
smeared, streaky look. It is how the paint has always looked; it showed
because the tufts were missing.

Ruled out with A/B stills:

- The paint's shear on steep ground (`gxz`): turning it off changed nothing
  visible on these patches.
- Rivers and river mouths: the patches are away from any river (the
  river banks' stones are a separate, intended bare strip).
- LOD rings and streaming: the cells were all stood, and the masks alone
  account for the patches.

## What changed

- **Slope** (`SLOPE` 0.83..0.88; was 0.905..0.95). Tufts now grow down to
  the rock. They follow the rock's ragged edge as the ground paints it:
  `EndlessPatch.rock_ragged` is the ground's `ragged` (er_vnoise's hash
  ported, lattice hashes cached for each cell), read per node under up
  0.95. So the tufts stop where the rock's tongues start and fill the turf
  tongues between them.
- **Height** (`ALPINE` 0.3..0.7). Tufts thin out with the paint's own
  tundra, its `alpine` (`EndlessPatch.alpine` / `alpine_of` / `broad`),
  instead of at a fixed 36..58 m. The broad patch is read at the cell's
  corners and eased across, so the probe stays cheap. The ground shader
  gets a new uniform, `turf_alpine`. When it is set, `carpet_turf` uses it
  in place of `turf_high`, so the paint under and past the tufts agrees
  with where they grow.
- The tufts' tint already carried the paint's olive on steep turf and its
  tundra, so the new tufts match the paint under them with no change.
- No land, rock, river or meadow shape changed. Meadows and flats are as
  before.

## Flags

- `--grass-cover=old`: the old masks (OLD_SLOPE and HIGH, no ragged
  edge). It should match main exactly, and all the `before_*` stills use
  it.
- `--grass-slope=a,b`: the slope band by hand.
- Constants in `endless_grass.gd`: `SLOPE`, `ALPINE`, `ALPINE_TOP`,
  `ROCK_NEAR`, `OLD_SLOPE`, `HIGH`.

## Cost

- **Coverage.** The carpet covers 9 to 18% more of the land (whole-land
  sample, ±1.5 km): seed 1 goes from 51 to 60%, seed 3 from 76 to 83%,
  and seed 7 from 70 to 77% (`cover.gd`). Flat meadows don't change.
- **Tufts in view.** At a sloped valley at 6 m there are +11% (505k to
  558k). At a coast slope +47% (115k to 169k). At the hills +28% (269k to
  344k). Over a flat meadow +4%.
- **Cell grow time.** Measured single-threaded, `bench.gd`, near / far ring
  per cell, old against new:

  | place | near ring | far ring |
  |---|---|---|
  | hills | 394 → 460 ms (+34% tufts) | 93 → 106 ms |
  | valley | 554 → 590 ms | 109 → 117 ms |
  | meadow | 348 → 408 ms | ~88 → ~98 ms |

  A first version read the alpine noise for every tuft and cost +65% on the hills, so the broad
  patch is now eased from the corners.
- **Frame time: not verified.** On this Mac the settled views sat at the
  display's 6.9 ms cap both before and after, even at a 2x render scale.
  Other runs were spiky (50 to 100+ ms frames in both modes), likely from
  other windows on the machine. Metal reports no GPU time. Earlier rounds
  found the near ring's cost follows its tuft count (about 4.5 ms for a
  full meadow low down). On a GPU-bound machine, then, expect up to about
  +1 to 2 ms low over steep hills and coast slopes, and nothing over flat
  meadows. This needs checking in play.

## Verified

- Headless import: 0 errors.
- Smoke PASS, 0 errors, for `endless_flight.tscn` as is, with
  `--grass-cover=old`, and at `--seed=1 --at=-612,-960 --alt=6`.
- `test_ground_look` passes. No test reads the endless grass, patch or
  ground files.
- Rendered stills, judged by eye:
  - The valley strip, the coast slope, the hills and the ridge are now
    carpeted.
  - Tufts stop at rock outcrops and gullies.
  - Grass and flowers on the turf above a rock ledge stop at its painted
    edge (`ridge_rock_edge_crop.png`).

## Stills (`captures/bare-patches/`, git-ignored)

- `sheet_a.png`: before | after for `valley`, `coast`, `rockslope` and
  `hills`.
- `sheet_b.png`: before | after for `gully`, `valley20` and `ridge`.
- `pair_<view>.png`: one pair per view.
- `before_*` / `after_*`: the frames. All are seed 1 from the chase camera:
  - valley: `--at=-612,-960 --alt=6`
  - coast: `--at=-852,1490 --alt=6`
  - rockslope: `--at=-260,-1280 --alt=8`
  - gully: `--at=-84,-1100 --alt=6`
  - hills: `--at=972,-30 --alt=8`
  - valley20: valley at `--alt=20`
  - ridge: a still eye at 972,45,30 looking at 972,20,-80
- The chase frames are not exactly matched: the plane flies on while the
  scene loads, so the before and after framings differ a little.
  `rockslope`'s before frame differs the most.
- Drivers and scripts, copied from scratch/bare:
  - `final.sh`: the set.
  - `own.sh`, `eye.sh`: one still.
  - `find.gd`: cells with bare-band slopes.
  - `probe.gd`: over and up on a grid.
  - `cover.gd`: coverage.
  - `bench.gd`: grow time.
  - `perf.gd`, `grow.gd`: frame time and grow time in the scene.

## Unverified, open

- Frame time on a GPU-bound machine (see Cost).
- How it looks in motion: the boost flight's cell lag over steep hills with
  the slower grows. Earlier rounds kept up with a lag of at most 3 cells,
  and grows are now up to about 17% slower there.
- The rock edge on the CPU leaves out the paint's small `rock_edge * 0.4`
  term (±0.04) and the partial rock breaking through high ground. A tuft or
  flower can stand a hair over a rock's lip.
- What is still bare, by design:
  - the tundra, alpine past 0.7, mostly over 65 to 80 m;
  - river banks' stones;
  - beaches;
  - rock.

  Up close the paint there still has its soft, smeared grain. If the user
  meets that on high shoulders, the next lever is the paint's near grain
  (`grain_near`, the footprint mix in `endless_ground.gdshader`), not the
  mask.
- Windows and other GPUs.

## Existing tests this breaks

None known. The full suite was not run.
