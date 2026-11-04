# Handoff: a land chunk's build past the field in C++

Branch `claude/frametime-analysis-flight-77218b`, 2026-11-03. Goal: the
chunk builds on the workers stop running GDScript (which, with 6+ in flight,
made the main thread's GDScript ~5x slower in flights: 20-50 ms frames), and
get faster.

## What a build was (measured, headless, one thread)

`scratch/chunk_cost.gd` times one `_build` piece by piece (ms, mean of 3;
seed 1, the default doors world). `bore` is the burrower's bore (4950,4500),
`bore_w` its west end (4560,4420), `plain` by the Peak (-700,-300), `plain2`
open wilderness (1640,580). `b_chunk` is the native field's `build_chunk`;
every other column was GDScript.

| chunk | total | b_chunk (C++) | tunnel pass | river frame | rock shape | portal holes | Peak (C++) | other |
|---|---|---|---|---|---|---|---|---|
| bore L0-2 | 33-34 | 4.0 | 8.7-10.9 | 7.9-8.6 | 5.7-9.4 | 0.8-1.4 | - | Field.new 0.8 |
| bore L3-6 | 38-49 | 5-8 | 2.8-10.6 | 7.9-9.8 | 6.4-8.5 | 6.1-6.4 | - | ponds 0.7 |
| bore_w L0-2 | 37-51 | 5.5 | 17.9-32.2 | 0.2 | 8.3-12.0 | 0.4 | - | |
| plain L0-3 | 24-28 | 3.4-6.9 | - | 0.2 | 6.0-9.5 | - | 9.3-13.5 | |
| plain2 L0-4 | 12-29 | 5.5-12.6 | - | 0.2-7.3 | 4.4-7.5 | - | - | |
| L5-7 (first ask) | 37-187 | 6-8 | 0.2-7.9 | 8-89 | 6-11 | 6 | 6-12 | sites 12-118 (once a world), isles 9-12 |

What `build_chunk` called back into GDScript for: LandField's layers.
`build_chunk` finds the ponds, halls, tunnels and splits over the box (the
sites are made once a world and cached), runs the native field, then each
layer's `apply_chunk` in GDScript (Ponds, Tunnels, Splits; the Peak's is
C++ but read colours through the blend), each reading `field.height` for
the normals past the chunk's edge. `_river_frame` sampled LandField 536
times (~12 us each through the layers: the tunnel carve `carve_m` 8.5 us of
it), `RockShape.grid` read 12 rings through LandField `grid` (3-8 ms of
its 5-11), `_portal_holes` walked 8,192 triangles. A near chunk was ~85%
GDScript; ~4-7 ms of it was C++.

## What went native (`native/terrain_kernels/chunk_pass_bind.h`)

- **ZenScapeTunnelCarve**: one tunnel site's `carve_m`, `sunk_cut`,
  `trench_under` and everything they read (`local`, `top`, `_massif_q`,
  `_shelve`, `_smax`, `_trench`, `_pit`, `_bowl_cut`, `_bowl_e`, the three
  FastNoiseLites). `tunnel_sites.gd` packs a site once when it is made
  (`go_native`, `native_pack`; tunnel_sites.gd:495) and `carve_m`,
  `sunk_cut`, `trench_under` hand off to it (tunnel_sites.gd:1478,
  :795, :1544). So LandField's `sample`/`height` near a tunnel, every
  apply_grid and the chunk passes all carve in C++.
- **ZenScapeChunkPass** (`scripts/endless/chunk_native.gd` makes it):
  - `tunnel_chunk`: Tunnels.apply_chunk whole (land_field.gd:1199 `_tunnel_chunk`).
    Colours off the region's own native field where a near chunk lies in one
    region (`_colour_impl`, land_field.gd:1190; the blend's colour there is that
    field's), else through the blend.
  - `river_ring` + `river_frame`: land_stream `_river_frame` (land_stream.gd:397).
    The ring is read off the native field with the tunnels and ponds cut in
    where nothing else shapes the land there (`ChunkNative.plain_in`, chunk_native.gd:80: no
    hall, split, Peak or isle; the ponds by their square as `_pond_for`).
  - `grid_heights`, `rock_layer`, `rock_finish`, `any_steep`: RockShape.grid
    (rock_shape.gd:123), its rings off the native field plus ponds and
    tunnels where plain.
  - `portal_tris`: `_portal_holes`' triangles and faces (land_stream.gd:522).
- The Peak's chunk pass gets the region's native field too (land_field.gd:1178), so its colours
  are read in C++ (it already was C++, but read them through LandField
  `colours`).
- Fallback, and the reference: `--chunk-native=0`, `--land-native=0`,
  `--gdscript-kernels`, no library or a stale one (`ChunkNative`
  CARVE_VERSION / PASS_VERSION, new classes at 1). The GDScript is kept as
  `carve_m_gd`, `sunk_cut_gd`, `trench_under_gd`, `_river_frame_gd`,
  `grid_gd`, Tunnels.apply_chunk and `_portal_holes`' loop.

## What stayed GDScript, and why

- **LandField's facade `sample`/`height`** (the layers' glue, the ponds',
  halls', splits' and isles' per-point carve). Only the tunnel carve went
  C++. A chunk's rings fall back to it where a split, hall, the Peak or an
  isle reaches the ring (most L4+ chunks; the Peak's near chunks). Porting
  Splits.cut (kinds, strata, benches), CoastIsles.apply and the blend's band
  is the next step for a fully native field; each must match bit for bit.
- Ponds.apply_chunk, Splits.apply_chunk, CoastIsles.apply_chunk (0.5-0.8 ms,
  0.5-0.9 ms, 6-12 ms on L6-7 only), Tunnels.portal_mask and the ice
  tunnel's hole mask (~1 ms), `_tops_of`, `_crest_cut` (0.2 ms), Field.new
  (0.8 ms a job: reusing fields across jobs would carry the carve's lattice
  caches, which `last_floor` depends on).
- Site finding (tunnels, ponds, splits): 12-118 ms the first time a square
  is asked, once a world (cached), GDScript sampling the field.
- The Peak's pass (`ZenScapePeak.apply_chunk`) is C++ already: 6-14 ms a
  near Peak chunk, the biggest piece left there.

## Equality

`scratch/chunk_check.gd` (throwaway, git-ignored):
`python tools/godot.py --script res://scratch/chunk_check.gd -- --points=3000 --seed=1`
(and `--seed=11`). Native on, then every native off, in one run:

- The carve: 15,000 points round the 5 sites of seed 1 (3 sunk, 2 with
  shafts, 2 with shelves: along the bores, the mouths, the trenches, the
  bowls, 2,874 of them moved by the carve) and 3,000 on seed 11 (1,307
  moved); `carve_m`, `sunk_cut` and `trench_under` at steps 0, 1, 2, 8, 32:
  **0 mismatches**.
- LandField `sample` (height, meadow, `last_river_r`, `last_river_w`) at
  the same points: **0 mismatches**.
- Whole chunks as the stream builds them (`_build`, every array byte for
  byte: verts, normals, colours, carved, river, heights, frame, shape,
  indices, faces, tops): 422 chunks on seed 1 (levels 0-5 round the bore,
  every site's mouths and middle, the Peak's side, 25 ponds; 372 rings read
  natively, 225 with ponds, 236 with tunnels; 94 with portal holes) and 315
  on seed 11: **0 mismatched**.
- `python tools/land_hash.py --seed 1`: exact
  `9ceaddb3af0672cb7cc9a50f79be9f48a15588ea1e4613921eac20e9fcb3c4e8` native,
  with `--land-native=0` and with `--chunk-native=0`. (It names the field
  "gdscript" in the doors world: the facade is the blend, its regions are
  native; unchanged by this round.)
- pow, atan2 and sin in the sunk carve and the ponds are land_math.h's
  (fdlibm), as the native field's; GDScript uses the C runtime's. They gave
  the same bits at every point here; on another machine the native carve
  keeps the seed's land the same where GDScript might not.

## Timings, old vs new (headless, one thread, ms a chunk)

| chunk | old | new |
|---|---|---|
| bore L0 / L1 / L2 | 148* / 33 / 34 | 127* / 8.1 / 8.5 |
| bore L3 / L4 | 43 / 38 | 14 / 11 |
| bore_w L0 / L1 / L2 | 47 / 51 / 37 | 11 / 12 / 11 |
| bore_w L3 / L4 / L5 | 33 / 38 / 37 | 15 / 11 / 14 |
| plain2 L0 / L1 / L2 / L3 / L4 | 12 / 12 / 22 / 29 / 21 | 11 / 11 / 15 / 20 / 13 |
| plain (by the Peak) L0 / L1 / L2 | 24 / 32 / 28 | 21 / 25 / 27 |

\* first ask of the bore's square: 118 ms is the site being made, once.

A near bore chunk went from ~33-51 ms (85% GDScript) to ~8-12 ms, of which
4-5.6 ms is the native field and ~1.5-2.5 ms is still GDScript (Field.new,
the layers' lists, the portal mask). An open wilderness chunk: 12 to 11 ms
(it was mostly the native field already). Chunks by the Peak gain least:
the Peak's own C++ pass and its rings through LandField.

## Contention check (headless)

`scratch/contend.gd`: the main thread loops `field.height` at 400 points
over the bore, a Dictionary/alloc loop and an arithmetic canary, while N
`_build`s of bore chunks (levels 0-2) run on the WorkerThreadPool; 3 s
each, run twice (same both times within 0.5 us):

| builds in flight | field.height old / new (us) | dict+alloc old / new (us) | canary old / new | builds/s old / new |
|---|---|---|---|---|
| 0 | 14.0-14.7 / 10.6-10.7 | 0.32-0.34 / 0.30-0.33 | 0.037 / 0.036 | - |
| 3 | 19.7-19.9 / 13.9-14.0 | 0.47-0.48 / 0.43-0.44 | 0.047 / 0.044 | 68 / 219 |
| 6 | 20.8-21.3 / 14.4-14.9 | 0.47-0.49 / 0.45-0.47 | 0.048 / 0.046 | 95-98 / 358-365 |
| 14 | 20.4 / 14.2-14.4 | 0.46 / 0.45-0.47 | 0.047 / 0.046 | 94-95 / 377-381 |

Headless does not reproduce the flights' 5x: with builds in flight every
main-thread loop, the canary too, is 1.3-1.45x slower old and new alike
(the CPU shared, not GDScript's). What changed: the same chunks take a
quarter of the worker time (95 to 380 builds a second), so the land's
bursts after a turn or a dive are a quarter as long; the main thread's
`field.height` over the bore is 25% cheaper (the tunnel carve, 14 to 10.7
us). Whether the flights' everything-slow frames came from GDScript on the
workers (the VM's shared locks, allocator) or from the CPU itself, only a
flight tells.

## Tests and checks

- `python tools/smoke.py studies/endless_flight.tscn`: PASS (native), with
  `-- --land-native=0` and `-- --chunk-native=0`: PASS; also at the bore
  (`--at=4900,4480 --alt=30`) and on seed 11 (`--at=4700,4385`). 
  `studies/burrower_study.tscn`, `flight_study.tscn`: PASS.
- No committed test covers LandField, LandStream, the tunnels or
  RockShape (grep of tests/); `test_native_collision_faces.gd` (the rebuilt
  library): PASS. `test_cloud_shade_steady.gd` is GPU-only, not run. None
  broken that I know of; the full suite was not run.
- `tools/ground_parity.py` not run: no ground owner or broad-phase
  publishing changed.

## Native build

Built on this PC (template_debug and template_release, MSVC, godot-cpp at
`<main>/builds/godot-cpp`, SCons from the Python 3.11 user scripts);
`tools/native_stamp.py`: current. The DLLs are only in this worktree's
git-ignored `bin/`: copy them to the main checkout's
`native/terrain_kernels/bin/` once merged (not done). The Mac needs its
own build; until then it runs the GDScript, same land.

## What the next flight must confirm

Fly the bore low and fast with `--frame-log` (as f7/f14), once as is and
once with `--land-tasks=3`, and read them side by side with
`tools/frame_report.py`:

- The everything-slow frames (grass, near, react, figure, landing spiking
  together; the canary flat) while the land streams: fewer and shorter than
  f14's without `--land-tasks`, ideally as few as with `--land-tasks=3`.
  If they stay, the cause is the CPU shared, not the GDScript: then the cap
  (`--land-tasks`) is the lever, and with builds 4x faster a low cap costs
  little.
- The land must look and collide exactly as before (it is the same bytes).
- Not covered: the GPU, a Mac, the Peak's near chunks (their C++ pass
  stays the cost there), worlds with slot halls (halls fall back to
  LandField's sampling).
