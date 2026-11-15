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

# Follow-up: the reach made cheap (far plants)

Prototype round. Smoke check passed (default world and `--world=regions`).
No tests added. **The native kernels were NOT rebuilt**: `grass_cell.h` and
its GDScript twin are untouched (ZenScapeGrass is still 6; the kernels this
worktree copied from game-visual-polish are current).

## What changed

- **Far plants** (`MeadowFlowerMesh.build_far` / `far_mesh`): each drift
  kind again, with the same heads on the same necks and the same colours,
  normals and vertex layout, so the same material lights, sways, nods and
  thins them. They are 23-64 triangles against 184-322:
  - Petals are one triangle, or one quad for broad ones (cosmos, buttercup,
    dandelion). The poppy's cups keep their rows.
  - Discs are low cones without backs. Stems are two segments. There are
    no leaves, buds or bracts.
  - Lupine is a tapering four-sided column, thinner and darker than the
    florets' reach: as wide as what they cover, with grass between.
  - Sunflower and wheat (not in drifts) fall back to the whole plant.
- **The swap** (`FLOWER_SWAP` (30, 10), reference_surface `flower_swap`):
  - Each drift flower is the plant out to 30 ring m, give or take 5 (each
    at its own distance, a hash of where it stands), and its far plant
    past it.
  - The plant's batch hides it past its distance and the far plant's batch
    hides it nearer, so each is drawn exactly once.
  - 25-35 m is past the leaves' fade (FLOWER_DETAIL 14-30) and before the
    thinning (40), where every plant stands whole at keep 1, so nothing
    else changes at the hand-over.
  - Looking level, the plants stand to about 36-50 m ahead.
- **Batches.**
  - The plants are cut into 16 m squares per cell (`_sub_split`) and culled
    by the rings like the near carpet's tiles (reach 36 m), so few are
    drawn past the swap.
  - The far plants are one batch a kind a cell. They are no longer split
    into kept and rest. `--flower-cheap-split=1` puts the split back: 23
    more draws for 1% fewer vertices.
- **FLOWER_END 120 -> 100.**
  - The kept 40% now go between 80 and 100 ring m (116-145 m ahead looking
    level) instead of 80-120.
  - 40% of a drift, with grown heads, still stands 2 s out at Boost. The
    last 0.5 s of thin tail is gone.
- **Flags.**
  - `--flower-swap=D,band[,sub]`; `--flower-swap=0` is the plant all the
    way.
  - `--flower-cheap-split=1`, `--flower-far-stems=0`, `--flower-grow=X`
    (FLOWER_GROW).
  - **The merged previous round is `--flower-swap=0 --flower-fade=40,80,120`.**

## What each lever bought

Counts (primitives, draws) are deterministic run to run, so they are the
primary evidence. GPU times were taken **while the user was playing a game
on this PC** (shared GPU). They are interleaved old/prev/new, three runs
each, with the spread in brackets. Re-run them on an idle machine before
trusting the last 0.1 ms.

Low Boost flight (5 m, `--at=640,470 --heading=0`, 14 s) at 1440x900, 3D
scale 0.75. Primitives are over old (9.43 M):

| | Primitives | Draws |
|---|---|---|
| prev (merged round) | +15.4% | 1531 (+55) |
| far plants, swap 35, kept/rest split | +1.4% | 1548 |
| ... no split | +2.4% | 1525 |
| ... no split, FLOWER_END 100 | +1.3% | 1516 |
| **final (swap 30, end 100)** | **+0.6%** | **1513 (+37)** |
| ... swap 25 (not taken) | +0.05% | 1510 |

meadow_low GPU, held view at 1440, 2-3 runs each:

| Variant | GPU ms | Over old |
|---|---|---|
| old | 7.79 (7.67-7.85) | |
| prev | 8.46-8.54 | +9% |
| far plants (end 120) | 8.14 (8.06-8.24) | +4.5% |
| every flower a far plant, end 120 | 8.0 (7.97-8.03) | +2.6% |
| same, no stems | 8.0 | same: triangles don't set it |
| same, heads not grown (`--flower-grow=0`) | 8.10 | same: pixels don't set it |
| keep 25% past 80 | 8.16 | none |
| every flower a far plant, end 80 | 7.83 | 0 |
| far plants, end 100 | 7.96 | +2.2% |
| **final** | 7.98 (7.95-8.00) | +2.2% |

- The far plants bought about half of the round's cost (the vertices).
- What is left follows the reach: how many bloom cells and instances are
  drawn far out. It does not follow the far plants' triangles, their
  stems, their size on screen or how many of them show. Cutting
  FLOWER_END from 120 to 100 bought the next 0.15 ms.
- The rest of meadow_low's 2% is the plants standing whole to 40 m (old
  thinned them from 22).
- Lever 2 (reach pulled in with height) was not built: cruise (45 m up)
  came to +1% without it.
- Shadows: no flower batch casts shadows (already off).

## Final numbers

1440x900, 3D scale 0.75 (the driver's default), 3 runs each:

| | old | prev | new |
|---|---|---|---|
| meadow_low GPU | 7.81 (7.77-7.85) | 8.52 (8.49-8.54) +9.1% | 7.98 (7.95-8.00) +2.2% |
| cruise GPU | 8.19 (8.18-8.20) | 8.71 (8.70-8.73) +6.3% | 8.30 (8.27-8.31) +1.3% |
| Boost flight GPU (frame log) | 10.13 (10.11-10.16) | 10.95 (10.92-11.01) +8.1% | 10.33 (10.32-10.34) +2.0% |
| Boost primitives | 9.43 M | 10.88 M +15.4% | 9.49 M +0.6% |
| Boost draws | 1476 | 1531 | 1513 |
| render_cpu | 1.48 | 1.53 | 1.50 |
| main tick | 6.56 | 6.60 | 6.59 |

`--win=keep`: the project's own full-screen window, **2560x1438 at 3D scale
0.75** as this PC's saved preset has it (not the user's 1.0):

| | old | prev | new |
|---|---|---|---|
| meadow_low GPU | 10.79 (10.48-10.98) | 11.46 (11.16-11.63) +6.2% | 11.09 (11.00-11.17) +2.8% |
| cruise GPU | 11.95 (11.57-12.15) | 12.50 (12.14-12.68) +4.6% | 12.16 (12.06-12.22) +1.7% |
| Boost flight GPU | 13.23 (12.84-13.45) | 14.07 (13.71-14.27) +6.3% | 13.54 (13.47-13.58) +2.3% |
| Boost primitives | 9.65 M | 11.06 M +14.6% | 9.72 M +0.7% |
| Boost draws | 1529 | 1585 | 1568 |

- The full-window old's first run was low against its other two (10.48 vs
  10.9-11.0; 12.84 vs 13.4), likely the shared GPU.
- Paired with runs 2 and 3 only, new is +0.2-1.6% on meadow_low, about 0%
  on cruise and +0.5-0.9% on Boost.
- CPU (render_cpu, tick) is unchanged within noise. Draws are 17 fewer
  than prev and 37 more than old.

## Proof (scratch, uncommitted)

- **Films**, centre crops a frame every 0.1 s, old | prev | new:
  - 5 m Boost pass: `scratch/fl/film_boost5_{a,b,c}.png`
  - 25 m: `scratch/fl/film_boost25_{a,b,c}.png`
  - Full frames: `scratch/fl/boost5_*`, `boost25_*`.
  - New shows the cosmos patch standing from the first frame, as prev
    does. No frame shows a pop or a plant changing between frames. At 25 m
    up the far patch is a little less pink than prev.
- **Stills**, old | prev | new: `scratch/fl/{cosmos,lupine,poppy,cosmos_up25}/sheet3.png`.
  The one visible loss is the farthest drifts at 120 m (ring 83): prev
  still shows a thin red poppy strip there, new hardly (FLOWER_END 100).
- **The far plant at its nearest** (27 ring m), full over far, 2x:
  `scratch/fl/card/zoom.png`. Heads read as heads, not cards. The first
  far lupine was a bright solid spike, which is why it is now thin and
  dark.
- **Drivers:** `scratch/cost_ab.py`, `scratch/proof.py`, `scratch/vp.py`
  (`view_prims.gd`: primitives at held views), `scratch/boost_cost.gd`.
  Logs are `scratch/bg/{t1..t7,k1}.log`, frame logs `scratch/fl/t*_*.csv`.

## Tests

None reference the changed code. `test_ground_look.gd` fails on
reference_surface's varyings (16 against its 14), but it fails the same at
the parent commit, so it is not this round's. The full suite was not run.

## Unverified

- GPU timings were taken under the user's game load (see above), and not
  at the user's 3D scale 1.0. Not flown by hand.
- `--world=regions` was only smoked. Night and other profiles were not
  looked at.
- One driven Boost run in the first batch flew elsewhere (its counts were
  unlike every other run of its flags). It was discarded and re-run.
- The cause of the far tail's cost (per cell or per instance, not per
  triangle or pixel) is inferred from the variants above, not profiled.
