# Handoff: flower reach (visual polish round, lane "flowers")

Prototype round. Smoke check passed (default world and `--world=regions`).
No tests added.

**THE NATIVE KERNELS WERE REBUILT (ZenScapeGrass 5 -> 6), in this worktree
only.** The DLLs are git-ignored. A checkout whose library is still 5 (the
main checkout on this PC, and the Mac) falls back to the old flowers with a
warning ("predate flower_part") until it is rebuilt with
`tools/build_native_kernels.py` (template_debug and template_release).

## Across d593ae19 (one A/B)

`d593ae19`'s changes to `endless_grass.gd`, `grass_tuft_mesh.gd` and
`endless_tuft_far.gdshader` were reverted in the working tree and the cosmos
patch (644, 346) shot from 120/90/60/40/20 m. Against today's code the
stills differ on 0.02-0.6% of pixels, the near blades' wind phase. The flowers
and the far tufts' painted tips look the same, so nothing regressed there in
held views. A film A/B across it was not run, so the culling cadence it
changed is unverified in motion. The swap the user saw was already there: real
flowers reached 55 ring m only (about 80 m ahead with the lead) and thinned in
over the last 30 m, with painted tips and dots further out.

## What changed

- **A third grass layer, `bloom`: only the drifts' own flowers**, those a
  drift gave its kind. No grass is grown in it, so it can reach far ahead
  cheaply: 17-35 ms a cell on a worker, against 68 ms for a near cell.
  The near carpet keeps the strays, a drift's companions and the seed heads,
  thinned over STRAY_FADE (22, 55) as before.
- The split is ZenScapeGrass config `flower_part`, version 6, in
  `grass_cell.h`. The GDScript twin is KitFlora Site `flower_part` in
  `kit_flora.gd`. A skipped flower spends the random number `add` would have,
  so the near carpet's strays stand where they did.
- **Fade** (`FLOWER_FADE` (40, 80), `FLOWER_KEEP` 0.4, `FLOWER_GROW` 0.5,
  `FLOWER_END` 120, `FLOWER_SOFT` 0.2):
  - Every drift flower is there out to 40 ring m.
  - From 40 to 80 they thin to 40%, and the heads that stay grow by
    keep^-0.5 (1.58x at 80).
  - The rest go between 80 and 120, each at its own distance.
  - Each one grows up out of the grass, or sinks into it, over 0.2 of the
    share instead of 0.08. That is about 10-20 m per flower, not a pop.
  - This uses the new `flower_end` and `flower_rank` uniforms in
    `reference_surface.gdshader`. Their defaults leave every other material
    as it was.
- **Distances ahead.** Looking level, the lead 0.45 puts ring R at 1.45 R
  ahead.

  | | Before | Now |
  |---|---|---|
  | All flowers present | about 32 m ahead | about 58 m ahead |
  | First flowers appear | about 80 m ahead | about 175 m ahead |
  | 40% present (heads grown) | n/a | about 116 m ahead |

  At Boost (51-57 m/s), 116 m is about two seconds out.
- **Cheaper far band.**
  - A bloom cell's flowers are one batch per kind for the whole cell, not
    per 24 m tile.
  - Each batch is split by a hash of where each flower stands into the kept
    40% (drawn to 120) and the rest (drawn to about 89).
  - The material's `flower_rank` maps each set's shader rank into its own
    share, so the shader thins them exactly as one set.
- **Painted wash.** The ground's `bloom_fade` and the far tufts' `wash_in`
  now run over (40, 120) (`wash_fade()`). The drift's colour builds under
  the real flowers as they thin, instead of switching on where they end.
  Without this a lupine drift, thin spikes, lost its purple from 25 m up.
- **Flag.**
  - `--flower-fade=old` is the round before, exactly: every flower in the
    near carpet over (22, 55), and the old wash.
  - `--flower-fade=a,b[,end[,keep]]` tunes the new fade. With two values,
    every flower is gone over a..b.
  - `--flower-fade=40,80,140` is the longer reach tried first.
- `studies/endless_flight.gd`: the frame log's `w_grass` counts every layer.

## Numbers (Windows PC, 1440x900 window, 3D scale 0.75)

Old means `--flower-fade=old`. Each figure is two runs that agreed within
0.1 ms.

| | Old | New |
|---|---|---|
| look_views meadow_low, GPU / wall | 7.8 / 7.85 ms | 8.5 / 8.57 ms |
| look_views cruise (45 m up), GPU / wall | 8.17 / 8.23 ms | 8.69 / 8.74 ms |
| Boost flight, 5 m up, 14 s, frame log: main tick | 6.68 / 6.31 ms | 6.55 / 6.54 ms |
| render_cpu | 1.51 / 1.42 ms | 1.54 / 1.52 ms |
| grass + g_stand | 0.70 / 0.62 ms | 0.70 / 0.71 ms |
| GPU | 10.1 ms | 10.9-11.0 ms |
| Median frame | 11.0 / 10.8 ms | 11.4 / 11.5 ms |
| Draws (mean) | 1475 | 1530 (+4%) |
| Objects | 1946 | 2000 |
| Primitives | 9.43 M | 10.87 M (+15%) |
| Grass instances | 613 k | 631 k |
| Cells grown in the flight | 274-329 | 365-368 (bloom cells) |
| Mean grow | 27-29 ms | 26 ms |
| Slowest stand | 1.7-1.9 ms | 1.8-1.9 ms |

- The CPU cost does not change. The cost is about 0.8 ms of GPU, from the
  flowers' vertices, and it follows FLOWER_END squared:
  - 140 cost 0.95 ms with the split and 1.35 ms before it.
  - Bloom with the old distances (`--flower-fade=22,55`) costs the same as
    old.
- These driven views are GPU-bound on this PC, so the frame time moves with
  the GPU. Where play is CPU-bound, the frame should not move.
- The cost could come down by pulling the bloom ring in with height (cruise
  pays 0.5 ms for flowers few can see) or with a head-only far mesh. Flower
  meshes are 184-384 triangles; heads are 30-60% of that.

## Proof (scratch, uncommitted)

- **Stills, old | new, farthest first:**
  - Cosmos patch: `scratch/fl/sheet_cosmos.png`
  - Lupine drift, flat meadow: `scratch/fl/sheet_lupine.png`
  - 14 m poppy patch: `scratch/fl/sheet_poppy.png`
  - Cosmos from 25 m up: `scratch/fl/sheet_up25.png`
  - Driver: `scratch/flower_view.gd`.
- **Films, centre crops, a frame every 0.1 s:**
  - Boost pass, 5 m: `scratch/fl/film_boost_ab.png`
  - Boost at 25 m up: `scratch/fl/film_up25_ab.png`
  - Full frames: `scratch/fl/pass3_old_*`, `pass4_final_*`, `pass_up25_*`.
  - Driver: `scratch/boost_cost.gd`.
- **What the films show.** On the 5 m pass, real cosmos stand on the patch
  from the first frame, about 2 s out. Old shows nothing there for about
  0.5 s, then thin painted tips. On the 25 m pass, old shows the patch
  faintly and new shows real flowers. No frame-to-frame pop was seen in
  either new film.
- **Cost:** `scratch/bg/final.log`, frame logs `scratch/fl/flog5_*.csv`.

## Tests

None reference the grass, `flower_far` or KitFlora's flower loop. No test is
known to break. The full suite was not run.

## Unverified

- Not flown by hand. The films are driven, at 5 m and 25 m, over one patch
  of seed 1.
- `--grass-native=0` (the GDScript twin of `flower_part`) is not checked
  bit for bit against the native.
- The Mac's kernels need a rebuild. Until then it runs the old flowers.
- The pipeline count rose by 3 in one log, from the bloom materials'
  first use. No hitch was traced to it.
- Night and other world profiles (Amberlands has no drifts) were not looked
  at.
