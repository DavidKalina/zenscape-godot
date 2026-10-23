# Endless flight: what limits how far we see (audit)

The ask: find what limits draw distance and streaming speed in endless
flight, and whether porting more code to C++ would pay. This round only
measured. No game code changed. The drivers are in `scratch/see_further/`
(git-ignored, this worktree only).

Machine: MacBook Pro, Apple M5 Pro (6+12 CPU cores, 20-core GPU), macOS,
Godot 4.7.2, seed 1, main at `374e19d4` (native land on). Weaker machines
will be slower. The GPU numbers scale roughly with GPU size, so a base M1 or
M2 (8 to 10 GPU cores) would take about two to three times as long.

## The answer in short

1. **The GPU is the limit, and it is already over budget.** The frame takes
   21 to 42 ms of GPU time at the four spots (24 to 48 fps). That is with the
   3D drawn at only 714 lines and scaled up. Near trees (4 to 17 ms) and grass
   (1 to 12 ms) are most of it. Both are geometry-bound: drawing at a lower or
   higher resolution, or without MSAA, does not change their cost. Every
   metre of extra grass or tree range adds to this.
2. **Building new land is fast, except the grass.** Land chunks (2.5 ms) and
   tree blocks (20 ms) keep up even at 4x cruise. A grass cell takes 511 ms
   (near) or 93 ms (far) on one thread. At today's ranges the grass keeps up
   at cruise. At 2x cruise the near carpet has bare cells in 43% of frames.
   With the grass range 1.5x and 2x cruise, it has them in 98% of frames.
3. **Per-frame script work is small.** The study's tick takes 1.4 to 2.6 ms
   of main-thread time. One hitch: the first grass cell stood after a start
   without grass takes 90 to 106 ms.

So C++ helps one thing, the grass grower. It does not help the frame, which
is GPU work. The first round should cut GPU geometry. The second can port the
grass grower so the grass can reach further at a faster plane.

## What bounds the view today

| What | Reach | Where |
|---|---|---|
| Camera far plane | 7,904 m (the haze's end x 1.04) | `studies/endless_flight.gd:256` |
| Haze (fog) | starts at 120 m, all sky by 7,600 m, curve 0.75 | `scripts/endless/endless_look.gd:56-58` |
| Land | 3 x 3 root chunks of 8,192 m round the eye (8 to 12 km out) | `scripts/endless/land_stream.gd:28-31` |
| Land detail | a chunk splits while nearer than 1.3 x its size: 1 m quads to about 166 m, 2 m to 333 m, 4 m to 666 m, 8 m to 1.3 km, 16 m to 2.7 km, 32 m to 5.3 km, 64 m to 10.6 km, 128 m past (the eye's height over sea + 20 m counts in the distance) | `land_stream.gd:33`, `_distance` at `:169` |
| Land colliders | finest chunks within 70 m | `land_stream.gd:42` |
| Grass near ring | full to 16 m, gone by 30 m, led ahead (x1.45 ahead, x0.55 behind: 43 m ahead, 16 m behind). Its tiles draw to 81.5 m | `scripts/endless/endless_grass.gd:90`, `:109` |
| Flowers | thin out from 22 to 55 m | `endless_grass.gd:161` |
| Grass far ring | grows in from 16 to 30 m, full to 150 m, gone by 230 m (333 m ahead). Its tiles draw to 371.5 m | `endless_grass.gd:90` |
| Grass with height | the rings shrink past 20 m over the ground: the near ring is gone by about 39 m up, the far ring by about 164 m up | `endless_grass.gd:115-116` |
| Past the grass | the painted ground alone | `shaders/endless_ground.gdshader` |
| Near trees | 256 m blocks. Full crowns to 150 m, far crowns 150 to 200 m, family crowns to 430 m (fade 40 m) | `scripts/endless/land_trees.gd:49-51`, `:90-93` |
| Mid tree crowns | 190 m to 1,500 m | `land_trees.gd:52` |
| Far tree crowns | 1,380 m to 6,200 m (sink over 900 m), 1,024 m cells | `land_trees.gd:53`, `scripts/endless/tree_plan.gd:47` |
| Tree colliders | 70 m | `land_trees.gd:68` |
| Arches | 2,600 m, 480 m cells | `scripts/endless/land_arches.gd:30`, `arch_plan.gd:32` |
| Sun shadows | 900 m, four splits at 27, 108, 360 and 900 m | `endless_look.gd:67`, `:157-161` |
| Clouds | marched to 7,800 m, slab top 1,250 m | `scripts/endless/endless_clouds.gd:59-60` |
| Cloud shade map | 6 km square | `endless_clouds.gd:64` |
| Valley fog map | 12 km square, drawn to 4,400 m, rebaked every 1,400 m | `endless_clouds.gd:88-91` |
| Sea mesh | rings out to 9 km | `scripts/endless/endless_sea.gd:251` |
| Sea depth map | 4,096 m square, rebaked every 900 m | `endless_sea.gd:22-24` |
| 3D resolution | the player's saved cap, here 720 lines (scale 0.42 of a 1,700-line window), upscaled by MetalFX or FSR | `scripts/render_resolution.gd:18-38` |
| Plane speed | cruise 16.1 m/s, boost 25.3 m/s, hard cap 30 m/s | `scripts/sky_plane.gd:57-70` |

`scripts/far_trees.gd` (1,600 m) is only used by the sky islets. The land
uses only its crown proxy.

## 1. GPU: the frame

How it was measured: a window of 2,880 x 1,700 pixels, Forward+, the 3D at the
saved cap (scale 0.42, so 1,210 x 714), MSAA 4x. Each spot is held still (the
plane is pinned while the streams settle). Then 120 frames are timed with
everything on, and again with each part hidden. Each sample ran twice; the
two runs agree within 0.2 ms. On Metal the viewport's GPU time reads 0, so
these runs use Vulkan (MoltenVK), which reports it. At one spot, Metal's
wall-clock frame was within 6% of Vulkan's. The frame's wall time equalled
its GPU time in every run: the GPU is the limit, not the CPU.

Stills of each spot, as it looks now (for a before and after):
`captures/see_further/meadow.jpg`, `woods.jpg`, `range.jpg`, `coast.jpg`.

| Spot (launch flags) | GPU ms | fps | draws | triangles |
|---|---|---|---|---|
| Meadow, low (`--at=1640,580 --heading=0 --alt=14`) | 35.3 | 28 | 1,017 | 12.2 M |
| Woods and meadow by a river (`--at=-704,-2450 --heading=0 --alt=30`) | 42.3 | 24 | 1,106 | 12.0 M |
| Mountain range (`--at=-700,-300 --heading=66 --alt=90`) | 20.8 | 48 | 701 | 4.4 M |
| Coast (`--at=-770,1900 --heading=0 --alt=40`) | 28.9 | 35 | 660 | 3.9 M |
| Woods in valley fog (`--at=-700,-1900 --heading=0 --alt=45`) | 29.4 | 34 | 879 | 6.9 M |
| Worst seen: low in grass by a wood (that last spot after 25 s of flight) | 48.1 | 21 | 1,265 | 14.5 M |

What each part costs (ms of GPU time saved by hiding it):

| Part | Meadow | Woods | Range | Coast |
|---|---|---|---|---|
| Near trees (all) | 7.1 | 17.1 | 3.9 | 10.9 |
| - family crowns (the batch per block, to 430 m) | 5.8 | 10.8 | | |
| - full crowns (to 150 m) | 0.0 | 3.8 | | |
| - far crowns (150 to 200 m) | 0.6 | 1.9 | | |
| - trunks | 0.6 | 1.7 | | |
| Grass (all) | 12.3 | 7.9 | 2.3 | 1.0 |
| - near ring | 5.0 | 1.6 | | |
| - far ring | 4.8 | 5.1 | | |
| - flowers | 1.8 | 1.2 | | |
| Clouds (the march) | 4.9 | 5.5 | 3.1 | 4.7 |
| Sun shadows | 3.0 | 3.6 | 1.8 | 2.3 |
| Land | 3.1 | 3.9 | 3.0 | 5.7 |
| Arches | 0.5 | 1.4 | 0.6 | 0.0 |
| Haze, sea, far tree crowns | under 1 each | | | |
| Mid tree crowns | hiding them costs 0.5 to 4 ms more (they hide what is behind them) | | | |
| Everything above hidden | 1.2 ms left (sky, plane, upscale) | | | |
| 3D at half the scale (0.25) | saves 6.2 | 7.6 | 4.8 | 6.0 |
| 3D at the window's resolution (scale 1.0) | costs 23.1 more | 23.8 | 21.5 | 27.2 |
| MSAA off | saves 8.8 | 11.1 | 4.7 | 7.5 |

The sub-rows come from a second run at the same spots, so they add up to the
whole within about a millisecond.

Resolution against part (the worst spot, low in grass by a wood):

| 3D scale (lines) | Near trees | Grass | Clouds |
|---|---|---|---|
| 0.25 (425) | 21.4 | 13.4 | 2.2 |
| 0.42 (714, the saved cap) | 20.5 | 13.7 | 3.0 |
| 1.0 (1,700) | 19.9 | 13.6 | 10.6 |
| 0.42, MSAA off | 21.4 | 13.2 | 3.0 |

What this says:

- **Trees and grass are geometry-bound.** Their cost does not change with
  resolution or MSAA. It comes from how many vertices run their shader. Both
  draw with `shaders/reference_surface.gdshader`, an 1,100-line shader with
  a 370-line vertex function (wind, bend, tread, season, char, rings, cloud
  shade and more).
- **The family crowns are the costliest tree part.** Each block draws a
  family crown for every tree in it, out to 430 m. For trees nearer than
  200 m the shader collapses it to a point (`lod_band`,
  `reference_surface.gdshader:400-402`), but the vertex shader still runs.
  The full and far crowns work the same way. So a tree under 150 m runs the
  crown vertex shader three times.
- **The near grass is drawn further than it shows.** Its tiles draw to
  81.5 m, but the ring has no tufts past 43 m ahead and 16 m behind. Tufts
  past the ring run the vertex shader at zero size. Loaded at the meadow:
  305,000 near tufts (54 triangles each, 16.5 M triangles) and 337,000 far
  tufts (33 triangles, 11.1 M).
- **Clouds are pixel-bound**: 3 to 5 ms at the 720-line cap, 10.6 ms at full
  resolution. They are cheap only because of the cap.
- **Pixel work is small at the cap.** Everything that scales with pixels is
  about 6 ms. At 1,080 lines (the default on Apple GPUs) it would be about
  13 ms.

What more range would cost on the GPU, if nothing else changes (estimates):

| Change | Extra GPU ms |
|---|---|
| Grass far ring x1.5 (to 345 m) | far ring x2.25: +6 |
| Grass far ring x2 (to 460 m) | far ring x4: +14 |
| Near trees to 645 m (x1.5) | family crowns x2.25: +7 (meadow) to +13 (woods) |
| Far crowns, mid crowns, land rings further | small: each is under 1 to 4 ms today |

## 2. Building new land (CPU, on workers)

Each item timed alone on one thread, with the streams stopped
(`scratch/see_further/grow_profile.gd`, `tree_profile.gd`, `maps.gd`):

| Item | Size | One thread | Workers in flight | Where |
|---|---|---|---|---|
| Land chunk | 64 x 64 quads, any level | 1.9 ms | 2.3 to 2.9 ms | worker, up to 16 at once |
| Grass near cell | 64 m: 38,300 tuft and 13,900 flower tries, 18,500 kept | 511 ms (444 to 606 by spot) | 260 to 800 ms (mixed with far cells) | worker, 6 slots shared with far cells |
| Grass far cell | 64 m: 7,400 tries, 3,100 kept | 93 ms | | same 6 slots |
| Tree block | 256 m, 0 to 270 trees | 20 ms (11 to 34) | 33 to 40 ms (blocks and far cells mixed) | worker, 3 slots |
| Tree far cell | 1,024 m, 35 to 340 crowns | 16 ms | | same 3 slots |
| Tree block or cell, stood | | 0.1 ms | | main thread |
| Grass cell, stood | | up to 1.5 to 4 ms | | main thread, 1.5 ms a frame |
| Sea depth map | 512 x 512 over 4 km | 463 ms | | worker every 900 m (first one on the main thread at load) |
| Valley fog map | 384 x 384 over 12 km | 783 ms | | worker every 1,400 m (first at load) |
| Cloud ground map | 160 x 160 over 20 km | 34 ms | | worker every 1,800 m |

Where a grass cell's time goes (mean of 32 cells at 4 spots, ms):

| Part | Near cell | Far cell | What it is |
|---|---|---|---|
| Land grid (native) | 3.2 | 3.2 | `LandField.grid`, 73 x 73 at 1 m |
| Drift grid | 15.3 | 13.0 | `EndlessPatch.bloom` on a 33 x 33 grid |
| Grass tries | 263 | 26 | KitFlora `Grow.step` phase 0: random points, noise, tussock and seed-head variety, a dictionary per kept tuft. 72,000 probe calls a near cell (22,000 rejected), about 107 ms of it |
| Flower tries | 63 | 0 | phase 1: meadow kinds, drifts, forms |
| Records to buffers | 119 | 17 | `KitFlora.Draw`: `Samples.add_item` per record (copies the item dictionary, builds an anchor dictionary), tiles, ring split, `batch_buffer` |
| Tint grid | 30 | 31 | `LandField.colour` + `EndlessPatch.tint` on a 33 x 33 grid |
| Tint applied | 3.8 | 1.8 | per tuft |
| **Total** | **511** | **93** | |

Two things stand out. The drift and tint grids (45 ms) are made twice for
each 64 m square, once for its near cell and once for its far cell. And the
`Draw` step builds dictionaries the plain (endless) path never reads.

How much must be built, flying straight (from the measured one-thread costs):

| Stream | Wanted at once | New per second at 16 m/s | Thread ms per second at 16 m/s | at 32 m/s |
|---|---|---|---|---|
| Grass far cells | 56 (113 at range x1.5, 190 at x2) | 1.8 (2.7, 3.6) | 170 (250, 335) | 340 (500, 670) |
| Grass near cells | 7 to 8 | 0.43 | 220 | 440 |
| Land chunks | 231 to 255 | about 4 | about 10 | about 20 |
| Tree blocks | about 150 | 0.73 | 15 | 30 |
| Tree far cells | about 145 | 0.19 | 3 | 6 |

All of it fits in the workers on paper. What fails is the grass's latency
and its 6 slots. A near cell takes half a second to a second, and it waits
behind far cells already running. It is asked for about 80 m ahead, which is
2.5 s at 32 m/s. Turns and dives also ask for many cells at once: the whole
far disc is 56 cells today (5.2 thread-seconds) and 190 cells at range x2
(17.7 thread-seconds).

Streaming measured in real time, headless at 60 fps
(`scratch/see_further/stream.gd`). The plane is pushed to k times its speed.
A "gap" is a cell inside a ring that should show tufts (near: within 30 m;
far: within 150 m) but is not stood yet, so bare painted ground shows there.
"Land lag" is a finest chunk within 250 m not built yet. The coarser parent
draws there, so there is no hole.

| Run (40 s from the meadow) | Near grass gaps (frames, most cells) | Far grass gaps (frames, mean, most) | Land lag (frames, most chunks) | Near tree gaps |
|---|---|---|---|---|
| Cruise, 16 m/s | 0%, 1 | 0% | 2%, 8 | 0 |
| 2x, 32 m/s | 43%, 4 | 0% | 27%, 13 | 0 |
| 4x, 64 m/s | 49%, 4 | 54%, 12, 27 | 57%, 22 | 0 |
| Held turn, cruise | 0% | 28%, 0.4, 4 | 1%, 4 | 0 |
| Dive from 220 m at 12 m/s | 11%, 4 | 9%, 0.3, 8 | 10%, 12 | 0 |
| Grass range x1.5, cruise | 20%, 2 | 4%, 0.4, 17 | 6%, 8 | 0 |
| Grass range x1.5, 2x | 98%, 6 | 98%, 26, 49 | 63%, 18 | 0 |
| Grass range x2, cruise | 58%, 3 | 13%, 2.7, 48 | 9%, 8 | 0 |
| Grass range x2, 2x | 93%, 5 | 73%, 12, 45 | 26%, 8 | 0 |
| Grass range x2, held turn | 0% | 100%, 13, 49 | 1%, 4 | 0 |
| Grass range x2, dive | 33%, 8 | 15%, 3.2, 46 | 11%, 8 | 0 |
| Woods in valley fog, 2x | 20%, 4 | 0% | 12%, 11 | 0 |

Pop-in comes first in the near grass at 2x cruise, then in the far grass at
4x cruise or at a longer range. Land and trees never fell behind.

## 3. Per frame on the main thread

The study's tick, part by part, headless at 60 fps over 40 s
(`scratch/see_further/stream.gd`, which runs the tick's own calls with
timers):

| Part | Mean ms (cruise) | Mean ms (all runs) | Worst ms |
|---|---|---|---|
| Look (sun, sky, haze, sea step, clouds step) | 0.46 | 0.38 to 0.86 | 1.5 to 5 |
| Grass react and eddies | 0.50 | 0.22 to 0.55 | 0.8 to 20 |
| Plane, landing, figure | 0.26 | 0.18 to 0.39 | 0.8 to 13 |
| Trees step | 0.11 | 0.08 to 0.20 | 3.3 to 10.5 |
| Land step | 0.09 | 0.04 to 0.25 | 1.4 to 8 |
| Camera | 0.07 | 0.06 to 0.12 | 0.3 to 1 |
| Grass step | 0.06 | 0.05 to 0.36 | 2.4 to 10 (90 to 106 in three runs) |
| Arches step | 0.02 | 0.01 to 0.04 | 1.5 to 3.6 |
| **Tick** | **1.57** | **1.36 to 2.58** | |

The renderer's own CPU time (measured in the rendered runs) was 0.3 to
0.9 ms. So the main thread has about 15 ms of slack at 60 fps. The one real
hitch: the first grass cell stood after a start with no grass near (from
220 m up, or over woods) takes 90 to 106 ms. Its materials and meshes are
made then, on first use.

## What C++ would save

Speed-ups from last round: 8x on one thread for the land, 20 to 35x on busy
workers. The grass grower is dictionary- and closure-heavy GDScript, where
GDScript is slowest, so 8 to 15x on one thread is a fair guess.

| Item | Today (one thread) | In C++ (estimate) | Saved | Cost to port | Worth it? |
|---|---|---|---|---|---|
| Grass grower, near cell | 511 ms | 35 to 60 ms | about 460 ms a cell; latency under 0.1 s | A new native grower used only by `endless_grass.gd`, about 1,200 to 1,500 lines of C++. It covers `grow_cell` (180 lines), the parts of KitFlora `Grow` and `Draw` the carpet uses (about 400), the record-to-buffer path of `Samples.add_item`, the meadow kinds and forms it reads, and `EndlessPatch` (280). | **Yes**, once the grass should reach further or the plane fly faster. It is the only CPU item that limits streaming. |
| Grass grower, far cell | 93 ms | 6 to 12 ms | about 85 ms a cell | (same grower) | (same) |
| `EndlessPatch` grids alone | 45 ms of every cell | 2 ms | 43 ms a cell | about 300 lines | A cheap first step (or share the grids between layers, below) |
| Land chunk | 1.9 ms | (done) | | | Done last round |
| Tree block, far cell | 20 ms, 16 ms | 2 to 3 ms | 15 ms a second at cruise | `tree_plan.area` and `far_cell` (about 200 lines). Tree files are being changed in another session. | No. Trees keep up at 4x. |
| Sea depth and valley fog maps | 463 ms, 783 ms | about 40 and 80 ms with a native batch call (as `LandField.grid`) | about 1.1 s of load (they run first on the main thread), and worker time | small: a batch call for heights and floors | Cheap, but only load time gains |
| Per-frame scripts | 1.4 to 2.6 ms in all | | under 1.5 ms | spread over 9 parts | No |

**Shared-code risk.** KitFlora also grows the aqueduct isle and the motif
editor's flora. A port must leave them building as before. So the native
grower should be a new class used only by the endless grass, with KitFlora
left as it is. It cannot match KitFlora's placement bit for bit without a
great deal of work (the order of its random draws, Godot's
`RandomNumberGenerator` and `FastNoiseLite` calls). It does not need to: no
save keys on where a tuft stands. It should be repeatable for a seed on every
machine, by last round's rules (no C runtime maths, no fused multiply-add).
The GDScript grower stays as the fallback, behind a flag such as
`--grass-native=0`, for A/B looks.

## Alternatives that beat C++

GPU (the frame), biggest first. Each estimate is for the spots above.

- **Family crowns only where they show** (trees; another session is changing
  them now). Give the family crown batch a near edge (its tiles'
  `visibility_range_begin` at the far cut, as the full and far crowns already
  stand in tiles), so trees under 200 m skip it. A lighter shader for the
  family crown would help too. Estimate: 3 to 8 ms back in woods.
- **The grass's near tiles drawn only as far as the ring.** Cut their range to
  the ring's real reach in the view's direction, with smaller tiles at the
  edge. Estimate: 2 to 3 of the near ring's 5 ms.
- **A cheaper far ring.** Past about 150 m, a tuft of 8 to 12 triangles (or a
  crossed card) in place of 33, and fewer of them with distance. Estimate: 2
  to 3 of the far ring's 5 ms. This is what makes a 1.5x or 2x grass range
  affordable.
- **Grass placed on the GPU.** A compute shader can write the MultiMesh
  buffer directly (`RenderingServer.multimesh_get_buffer_rd_rid` exists in
  4.7). That removes the CPU grow, and could cull per frame. It is a larger
  job, but the whole carpet would then cost no CPU at all.

CPU (streaming), in GDScript, before any C++:

- **Share the drift and tint grids** between a square's near and far cells
  (cache by key): 45 ms off one of each pair.
- **A plain fast path in `Draw`** for the endless carpet, skipping
  `Samples.add_item`'s dictionaries: about 90 ms off a near cell, 13 off a far
  one (estimate). Endless-only; KitFlora's other users keep the old path.
- **Schedule near cells first**: keep two of the 6 slots for near cells, and
  split a near cell into four 32 m jobs. This fixes the near gaps at 2x
  cruise, without C++.
- **Make the grass materials and meshes at setup**, so the first cell stood
  in flight no longer takes 90 to 106 ms.

Together these make a near cell about 25% faster and a far cell about 50%
faster. The grass tries loop (263 ms a near cell) stays. Only C++ or the GPU
removes that.

## Recommended next rounds

**Round 1: a GPU and grass-scheduling pass (GDScript and shaders, no C++).**

- Grass: near tiles cut to the ring, a cheaper far ring past 150 m, flowers'
  tiles cut to their fade.
- Trees: the family crown's near edge and a lighter crown shader. Agree this
  with the session working on spruce sprays first, since it owns those files.
- Grass streaming: near cells first, shared grids, the `Draw` fast path,
  warmed materials.
- Expected: about 7 to 14 ms of GPU back at the meadow and woods spots (a
  quarter to a third of the frame). The near grass should have no gaps at 2x
  cruise. Then
  the grass far ring can go to 1.5x (345 m) at today's frame time.
- Risks: looks change at the ring edges (judge in stills and in play). The
  tree work overlaps another session.
- Prove it by rerunning `scratch/see_further/gpu_spot.gd` and `stream.gd` (or
  copies) at the same spots, and smoke the scene.

**Round 2: a native carpet grower (C++).**

- `grow_cell`'s work in one native call: the probe, tries, variety, flowers,
  drift and tint grids, and the buffers out. GDScript fallback behind a
  flag. KitFlora unchanged.
- Expected: grass cells about 10x faster (near 511 to about 50 ms, far 93 to
  about 9 ms on one thread). No pop-in with the grass range 2x at 2x cruise:
  that needs about 0.1 thread-seconds a second, and the whole 190-cell disc
  rebuilds in under half a second on 6 workers.
- Risks: placement differs from the GDScript grower, so the carpet looks a
  little different (it should read the same). It must stay repeatable across
  machines. The aqueduct isle and the motif editor must build as before:
  smoke a kit motif and an `editor_*` one.

Going further than that needs both rounds. The GPU sets how much can be on
screen, and the grower sets how fast it can change.

## Not measured, and why

- **Other machines.** Only this Mac. No Windows PC, no weaker GPU.
- **Metal's GPU time.** Metal reports 0 for it, so the GPU runs used
  Vulkan (MoltenVK). One spot checked on Metal by wall-clock came within 6%.
- **Full-screen at the window's own resolution.** The game opens full screen
  (3,024 x 1,898 here). These runs used a 2,880 x 1,700 window (86% of the
  pixels), because the full-screen window stopped drawing when another space
  was in front. At the 720-line cap only the upscale and the HUD depend on
  the window size.
- **Grass react, sea foam and the valley fog's share of the cloud pass** were
  not hidden on their own. Hiding clouds also hides the valley fog.
- **Night, other moods, other hours, weather.** The default mood at load only.
- **Long-run heat.** Each GPU run lasted 4 to 6 minutes.
- **Load time** (priming land, trees, grass and maps) was not timed as a whole.
- **Render-thread CPU in detail.** The per-frame breakdown is headless.
  Rendered runs report the renderer's CPU time only as a total (0.3 to
  0.9 ms).
- **Contention.** Another session ran its own rendered timing windows during
  this round. The GPU runs waited for a quiet machine and were redone if
  another window opened during them (`scratch/see_further/gpu_clean.py`).
  The headless streaming runs did not wait (load average 1.4 to 2.5).
- **Trees under change.** Tree numbers are main's at `374e19d4`. Another
  session is changing the spruces now.

## How to rerun

All in `scratch/see_further/` (git-ignored; copy them to keep them).

- `gpu_spot.gd`, a rendered driver: the frame at one spot, then each part
  hidden. `--pin` holds the plane; `--exp=fine` splits grass and trees;
  `--exp=scale` crosses resolution and MSAA with parts. Run by
  `gpu_clean.py NAME [args] -- [scene flags]` (Vulkan, waits for a quiet
  GPU). It needs `override.cfg` with `[display] window/size/mode=0` in the
  worktree root, so the window is not full screen. Delete it afterwards.
- `stream.gd`, a headless driver: the tick timed part by part, and the
  stream gaps, at `--k=` times the plane's speed or `--move=turn|dive`.
- `grow_profile.gd` (a grass cell broken down), `tree_profile.gd`,
  `maps.gd`, `mesh_tris.gd` (triangles loaded per batch kind).
