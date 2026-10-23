# Endless flight: frame rate (round 1, stopped early)

The goal was 60 fps (16.7 ms of GPU time) on the M5 Pro at the audit's spots
(`see-further-audit.md`), with the look unchanged. The round stopped early
because the user needed the machine. It cut **3 to 7 ms a frame with no
visible change**. Only the mountain range spot is near the budget. What is
left needs trades the eye can see, or tree work (another session owns the
trees).

## Launch

`./run-endless-flight.command`, or
`godot --path . studies/endless_flight.tscn -- --no-title`. The new
behaviour is the default. Each change has a flag that brings back the old
behaviour.

## What changed

1. **Grass tiles culled by the rings** (`scripts/endless/endless_grass.gd`
   `_cull`). Each frame a tile is drawn only while its roots' box meets the
   disc where its ring could still show a tuft. That disc is the same led,
   rise-aware ring distance the shaders use (`endless_ring.gdshaderinc`),
   with 2 m to spare. The near grass is split into 8 m tiles on the worker
   (`_split`), so the tiles at the ring's edge are small. Flowers are cut at
   55 m and the far ring at 230 m. Before this, the near tiles drew to
   81.5 m although no tuft shows past about 43 m. CPU cost: about 0.2 ms a
   frame.
2. **Far grass LOD past 100 m** (`GrassTuft.build_far` and
   `build_lite_morph` in `scripts/grass_tuft_mesh.gd`, `far_morph` in
   `shaders/endless_tuft_far.gdshader`). A far tile whose nearest root is
   past 100 m draws the far ring's tuft with each blade as one triangle:
   11 triangles against 33, and 3/5 of the vertices. So that the swap never
   pops, every far tuft eases into that shape between 65 and 95 m (the
   vertex's way there is stored in CUSTOM0). A tile only swaps once all its
   tufts have fully eased, so the swap itself changes no pixel.
3. **No ambient occlusion** (`scripts/endless/endless_look.gd`
   `_frame_trades`). The land's surfaces get their sky fill as emission,
   which SSAO never darkens. At six spots, including one low among trees,
   turning it off changed no pixel beyond the clouds' own frame-to-frame
   noise (mean difference 0.006 to 0.23 of 255). It cost 2.6 to 4.5 ms,
   because it adds a depth and normal pass over every grass tuft.
4. **Grass materials made at setup** (`_warm`). The first grass cell stood
   in flight no longer makes its plant materials (each one folds its shader,
   `scripts/shader_fold.gd`). Headless dive from 220 m: the slowest cell
   stand went from 85.6 ms to 9.1 ms. Setup takes about 0.13 s more.

The shared code changes are additive: new functions in
`grass_tuft_mesh.gd`, and KitFlora is untouched. The motif yard builds as
before (smoked with `bell_spires` and `editor_aqueduct_gorge`).

## Flags

- `--grass-cull=0`: no culling. Every tile draws to its visibility range,
  as before.
- `--grass-sub=M`: the near grass's tile size (8). 24 is KitFlora's own.
- `--grass-far-lod=M`: the far LOD distance (100). 0 is off: the lite tuft
  everywhere, no morph.
- `--grass-warm=0`: the grass materials are made on first use, as before.
- `--ssao=1`: ambient occlusion on, as before.
- Visible trades. The user chose all three for the Mac (M5 Pro), so on
  macOS they are on by default (`EndlessLook.mac_trades`), and off elsewhere.
  `--mac-trades=0` turns them off on the Mac too; each flag below still wins:
  - `--msaa=2` (or 0): MSAA 2x instead of 4x. Saves 1.2 to 1.7 ms.
  - `--cloud-half-res` (an existing flag): the cloud march at half
    resolution. Saves 1.2 to 2.7 ms. The clouds are visibly softer and lose
    their fine billows.
  - `--shadow-size=4096`: a smaller sun shadow map. Saves 0.4 to 0.9 ms.
    Shadow edges are a little softer.

## Verified

GPU time is from Vulkan (MoltenVK), because Metal reports 0. The window was
2,880 x 1,700, the 3D at the saved 720-line cap (scale 0.42), MSAA 4x, the
plane pinned and the world frozen. The driver is
`scratch/see_further/gpu_spot.gd` (git-ignored).

**Main table, run `ab1`.** One window per spot. The new state and the old
state are switched at run time and interleaved over 3 rounds, so load from
other work hits both alike. "Old" means SSAO on, every grass tile shown and
the plain lite tuft. The spread is the range across the rounds.

| Spot | Old (main) | New | Saved | Grass part | SSAO part | +MSAA 2x | +cloud half-res | +shadow 4096 |
|---|---|---|---|---|---|---|---|---|
| Meadow (`--at=1640,580 --heading=0 --alt=14`) | 31.1 | **24.3** | 6.8 | 3.5 | 3.5 | -1.4 | -2.1 | -0.7 |
| Woods (`--at=-704,-2450 --heading=0 --alt=30`) | 40.6 | **33.5** | 7.2 | 3.5 | 4.5 | -1.5 | -2.3 | +0.3 (noise; spread 1.8) |
| Range (`--at=-700,-300 --heading=66 --alt=90`) | 23.1 | **18.8** | 4.1 | 0.9 | 2.9 | -1.7 | -1.4 | -0.4 |
| Coast (`--at=-770,1900 --heading=0 --alt=40`) | 23.9 | **20.7** | 3.2 | 0.2 | 2.6 | -1.5 | -2.7 | -0.6 |
| Worst, low by a wood (`--at=-722,-2172 --heading=-41 --alt=7`) | 41.0 | **34.6** | 6.4 | 2.7 | 3.6 | -1.2 | -1.2 | -0.9 |

All three trades together would bring range to about 15 ms and coast to
about 16 ms. Meadow would be about 20 ms, and woods and worst about 30 ms.

**Baseline on main** (run `base`, with the paired references only for the
worst spot). The tree costs on current main, after spruce rounds 4 and 5,
are in the GPU ms saved by hiding each part:

| Part | Meadow | Woods* | Range* | Coast | Worst |
|---|---|---|---|---|---|
| Frame | 30.7 | 36.7 | 22.4 | 23.4 | 41.2 |
| Grass (near / far / flowers) | 12.4 (5.3 / 4.7 / 1.8) | 8.3 | 2.9 | 1.0 | 12.9 (5.7 / 5.0 / 2.2) |
| Near trees (all) | 2.2 | 11.3 | 3.2 | 4.6 | 13.1 |
| - full crowns, 0 to 80 m (`Detail_N`) | 0.0 | 6.9 | 1.7 | 0.7 | 4.3 |
| - distance crowns, 80 to 200 m (`Far_N`) | 0.8 | 1.9 | 2.6 | 2.6 | 6.2 |
| - family crowns (`Spruce*Crown`) | 0.8 | 1.1 | 1.9 | 1.2 | 1.2 |
| - trunks | 0.7 | 1.0 | 1.8 | 0.8 | 1.4 |
| Clouds | 4.7 | 4.3 | 5.4 | 5.2 | 3.8 |
| SSAO | 2.5 | | 3.8 | 2.3 | 3.4 |
| Sun shadows | 2.3 | | 3.3 | 1.1 | 2.4 |
| Land | 2.1 | | 3.9 | 5.3 | 1.9 |
| MSAA off | 4.7 | | 6.4 | 4.9 | 4.1 |

\* The woods and range baseline runs drifted during the run (the frame read
higher or lower later on), so their sub-rows are rough. The worst-spot
run was steady (spread 0.0).

Restart A/B runs for the grass agree with `ab1`. Meadow went from 30.7 to
28.4 ms with culling and 27.4 ms with culling plus the LOD. Worst went from
41.1 to 38.8 to 37.5 ms. Range went from 19.0 to 18.2 ms. Of the near-tile
sizes, 8 m beat 12 m by 0.3 to 0.9 ms.

**Disturbed runs, not used:** `p4` coast (sd 2.2 ms), `p4m2`, `p4nr` and
`pr1` (stopped part-way). The user was working on the machine (Firefox's
GPU helper, WindowServer busy). Single-sample-per-state runs were not
trustworthy then, which is why `ab1` interleaves its states.

## Flicker and popping (per change)

- **Culling:** proved pixel-exact. In flight the world was frozen five
  times (time scale 0, study off). Each time the frame was drawn once as
  culled and once with every tile shown. At the meadow and the worst spot
  0 pixels differed (`--no-clouds`, because the cloud march jitters each
  frame). A control that hid the near tiles changed 44,000 pixels, so the
  test does see a change. A headless flight with turns found no hidden tile
  holding a tuft within its reach (`scratch/cull_check.gd`). Flicker maps
  of 40-frame bursts, cruising and held still, old against new (second
  difference, `scratch/flick.py`): the same within noise (cruise: mean
  13.62 against 13.67, no spike in the series; still: 2.31 against 2.30).
- **Far LOD:** the frozen A/B between swapped tiles and the morphed lite
  tuft differs in 43 to 62 pixels of 544,000 by more than 6/255 (mean
  0.03). Rounding on the inner edges; no pop. Without the morph it was
  4,800 pixels, which is why the morph exists. Bursts over the far band:
  cruise median 3.47 against 3.56, with no spike in the new run. The old
  run had one spike, from a cloud or a cell standing. Held still: 0.52
  against 0.51. Look against the old lite tuft, frozen at 1,920 px wide:
  2.2% of pixels differ by more than 6/255, as fine blade texture in the
  100 to 230 m band. In a 2x zoom I could not tell them apart
  (`captures/frame_rate/far_lod_pair.jpg`, top old, bottom new). This one
  is a look change, if a tiny one. `--grass-far-lod=0` restores the old
  tuft.
- **SSAO off:** removing it adds no motion. Only the stills were checked
  (`ssao_off_diff_x16.jpg`, the difference x16, at the woods). No burst was
  run for it.
- **Warm:** CPU only. Nothing drawn changes.
- **Trades** (off): stills only. `trade_cloud_half_pair.jpg` (clearly
  softer), `trade_shadow4k_pair.jpg` (barely), `trade_msaa2_pair.jpg`
  (grass edges). No bursts.

## Not verified

- Live play cost. Pinned and live, the frame costs about 2 to 2.5 ms more
  than frozen at the meadow, and almost nothing more at range and coast.
  This is probably the per-frame map redraws (cloud weather and shade, the
  grass react map, which draws in its own SubViewport). It was not split
  out.
- Metal itself (all timings are from Vulkan), full screen, and other
  machines.
- The GPU side of the first-cell hitch: the shader compile on first draw.
  Only the CPU part was fixed and measured (headless).
- The full suite was not run (a prototype round).

## Tests this breaks

None known. Nothing under `tests/` reads the grass cells' node layout.
Cells now hold `Tile_N` holders, with the batches under them; a driver that
walks a cell's children for batches should use
`find_children("*", "MultiMeshInstance3D")`.

## Next steps

- **Trades:** MSAA 2x, cloud half-res and the 4096 shadow map (numbers
  above) are on by default on macOS, the user's call. Together they are
  about 3 to 5 ms, enough for range and coast to reach 60 fps. Not yet
  re-timed together in a rendered run.
- **Clouds** (3 to 5 ms, pixel-bound): a march between full and half
  resolution (for example a checkerboard with the temporal resolve), or
  cheaper valley-fog steps. Judge in motion. `--cloud-steps=80` saved
  nothing, because rays end early anyway.
- **Shadows** (about 2 ms): the land and tree casters cost little (0.1 to
  0.9 ms). Most of the cost is the four 4096 splits and their sampling.
  Try split blending off, or three splits. Both are visible trades.
- **Land** (1.3 to 5 ms, most at coast and range): `endless_ground` works
  out the grass paint for every pixel, even under rock and sand. Branching
  that is pixel-exact only where no implicit derivatives are taken inside
  the branch. Measure land against resolution first (`half+no_land` in
  `gpu_spot.gd --exp=ab` was in the stopped run).
- **Live cost:** split the 2 ms. Try the react map's SubViewport update
  mode, and the weather and shade every 2 frames.
- **Near grass** (2.5 to 3.6 ms after culling) is vertex-bound in
  `reference_surface.gdshader`, about 4 times the cost per vertex of the
  far tuft. That shader belongs to the tree session. A grass-only
  cheaper vertex path there would help most.

## Notes for the tree follow-up

These are tree costs on current main, after spruce rounds 4 and 5. Trees
are now the biggest item wherever there is forest. At the worst spot, near
trees cost 13.1 ms of 41 (34.6 after this round, so about 38%). In the
woods they cost about 11 ms, and in the stopped `pr1` run about 20 ms of
39 (that run was disturbed, so only roughly).

- **Distance crowns, 80 to 200 m (`Far_N` tiles):** 6.2 ms at the worst
  spot, 2.6 at range and coast. These are the most expensive per tree on
  screen. They are worth a lighter mesh or shader. Or cull their tiles to
  the band the way the grass tiles are now culled to their rings: the
  tiles have no visibility range set, so tiles nearer than 80 m may still
  run the vertex shader at zero size.
- **Full crowns, 0 to 80 m (`Detail_N`):** 4.3 to 6.9 ms (woods). They are
  costly per vertex, as the near grass is: `reference_surface`'s vertex
  function. A lighter crown vertex path, or fewer sprays per crown past
  about 40 m.
- **Family crowns and trunks:** about 1 to 2 ms each. The audit's "near
  edge" idea (skip trees under 200 m) is worth checking again now that the
  family crown starts at 200 m.
- **Mid crowns, far crowns, shade casters and forest floor:** each under
  0.5 ms. Not worth work.
- Measure with `scratch/see_further/gpu_spot.gd --exp=ab --states=new,no_tree_detail,no_tree_farcrown,...`
  (interleaved states hold up under load), run through
  `scratch/see_further/q.sh TAG "worst woods" "<driver args>"`. Needs
  `override.cfg` with `[display] window/size/mode=0`. Delete it after.

## Files

- `scripts/endless/endless_grass.gd`: culling, sub-tiles, far LOD swap,
  warm, flags.
- `scripts/grass_tuft_mesh.gd`: `build_far`, `build_lite_morph`
  (additive).
- `shaders/endless_tuft_far.gdshader`: `far_morph`.
- `scripts/endless/endless_look.gd`: SSAO default and the trade flags.
- Stills in `captures/frame_rate/` (the few referenced above are
  committed).
- Drivers (git-ignored `scratch/`): `see_further/gpu_spot.gd` (with
  `--exp=ab` states), `see_further/q.sh`, `see_further/spots.sh`,
  `see_further/sum.py`, `see_further/sumab.py`, `flick.gd` (`--mode=ab`,
  `burst`, `lookab`), `flick_ab.sh`, `flick.py`, `flick2.py`, `trades.gd`,
  `trades.sh`, `cull_check.gd`, `hitch_probe.gd`.
