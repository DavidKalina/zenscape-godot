# Native isles, round 1 (2026-10-14; handoff, stopped early)

> On `perf/native-isles`, with `roguelike` (edfc5395) merged in. Pushed and
> not merged. Replaces `native-isles-round1-wip.md`. The round was stopped
> when the user needed the machine. The re-measure matrix is half done (see
> "What's left"), and the tests and stills were not run.

## Play it

Mac:

    godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
    godot --path . res://studies/run_layer.tscn -- --no-title --shape=ring --seed=1
    # the GDScript fallback (identical isles, slower)
    godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2 --gdscript-kernels

Windows (PowerShell, repo root, after the DLL steps below):

    & $env:GODOT --path . --rendering-method forward_plus --windowed --resolution 1440x900 studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
    & $env:GODOT --path . --rendering-method forward_plus --windowed --resolution 1440x900 studies/run_layer.tscn -- --no-title --shape=ring --seed=1

After merging into a checkout, rebuild the native library there. A stale
library fails the version check (2), so the game falls back to GDScript.

## Launch to playable (rendered, windowed, `tools/bench_loading.gd --no-stills`)

M5 Pro, display awake. Load average 2.3-4.8: my own runs, plus other
sessions now and then. Read the times as ±10 %.

- **Before:** `roguelike` edfc5395 (isles built one at a time in GDScript).
- **After:** this branch at 45ad3bae.
- **Threads:** set with `override.cfg` `threading/worker_pool/max_threads`.
- **Cold:** `user://fixed_cache` emptied before the run.
- **Warm:** after one priming run.

| Sprawl 2 | all (18) | 8 | 6 | 2 |
|---|---|---|---|---|
| before, cold | 39.8 s | 41.5 s | 45.7 s | 46.3 s |
| before, warm | 39.1 s | 37.6 s | 38.6 s | 37.9 s |
| after, cold | 18.5 s | 17.7 s | 18.9 s | 20.1 s |
| after, warm | 16.5 s | 16.1 s | 16.0 s | not run |

| Ring 1 | all | 8 | 6 | 2 |
|---|---|---|---|---|
| before, cold | 32.9 s | 34.5 s | 35.0 s | 33.6 s |
| before, warm | 25.3 s | 25.3 s | 25.8 s | 25.4 s |
| after | not run | | | |

So sprawl 2 went from 38-46 s to 16-20 s. Ring 1 "after" was not run. The
WIP note's rough figure was 23-28 s, before this round's fixes. The GDScript
fallback (library removed) was 34.8 s on sprawl 2. Raw logs:
`/tmp/ni/load/mx-*.log` and `/tmp/ni/matrix.txt`.

### One thread: an engine deadlock, in the base too

A run with `max_threads=1` hangs at the start. Seen with a symbol build of
Godot:

- The pool's only worker runs the layer-plan task. It calls
  `mesh_surface_get_arrays` (through `Shape3D.get_debug_mesh` in
  `KitMotif.piece_block`), which waits for the main thread to flush the
  renderer.
- The main thread is drawing the loading screen and waits in
  `WorkerThreadPool::wait_for_task_completion` for a canvas pipeline compile.
- That compile is queued behind the busy worker, so neither moves.

Two threads load fine (20.1 s). The real fix is the same as the next perf
step: no renderer readbacks in worker tasks.

## Profile (where the time went)

I sampled the main thread (macOS `sample`) on a Godot 4.7.2 build with
symbols (`/tmp/ni/gsrc/godot/bin/godot.macos.editor.arm64`, built with scons
`target=editor production=yes debug_symbols=yes vulkan=no`, about 4 minutes).
I also used per-frame rows from `bench_loading.gd --frames`.

After the WIP, the about 11 s "main-thread wall" was mostly not GDScript in
stand, flora or life:

1. **The bench's own stills.** `Image.save_png` of the loading-screen stills
   blocked about 1.2 s each, inside the time measured. This was 3-5 s of every
   earlier measurement, the WIP's and round 2's included, on both sides. Use
   `--no-stills` now.
2. **Jolt rebuilt a body's whole compound shape for every held shape put
   back** (`LateShapes.drain`). That's quadratic per body: about 2.3 s on
   sprawl 2. Fixed (below): stand went from about 2.5 s to 0.35 s for the
   8 isles.
3. **GPU readbacks.**
   - `surface_get_arrays`, `Mesh.get_faces` and `Shape3D.get_debug_mesh` each
     wait for every frame in flight (`RenderingDevice::_stall_for_frame`).
     They cost about 11 % of the main thread.
   - A worker's readback is run at the main thread's flush, so it stalls the
     main thread too.
   - Fixed: the plant meshes' triangle counts (one readback per multimesh
     batch).
   - Still there:
     - `KitMotif.piece_block` → `get_debug_mesh` (about 1.5 s, only with a
       cold fixed cache);
     - the roost's `_scorch`, `RoostDress.Faces.add_mesh` and `_sooted_mesh`
       (on its worker build);
     - `DragonRoost._gather_skin`.
4. **The stage stall.** `run_layer._stand_layer` is one 3.3-3.5 s frame:
   - `DragonRoost.setup` → `_settle`: 15 passes × 5,537 hide points of
     `Roost.ground`, about 1.75 s;
   - the stage setup, 0.6 s;
   - the enemies, 0.3 s.

   It runs alongside the isle builds. The longest build is the roost
   (3.2 s, also mostly `Roost.ground`), so both must shrink to gain.
5. **Flora (about 4 s over 8 isles)** splits as:
   - motifs' path-wear callables 1.2 s;
   - rays 1.0 s;
   - drawing 0.9 s, now with fewer readbacks;
   - meadow kinds 0.4 s;
   - edge index 0.3 s.
6. **GDScript compiling** the game's scripts on first load: about 2-2.7 s,
   engine-side, the same on both sides.

What didn't help: drawing the world under the loading screen only every 4th
frame. There was no gain, so it was reverted.

## What was ported, and changed

From the WIP (unchanged this round), in `native/terrain_kernels/`
(`ZenScapeIsleKernels`), loaded by `scripts/native_isle_kernels.gd`, with the
GDScript kept as the fallback:

- `RuinKit Build.finish` (ivy, fringes, curtains, moss, erosion,
  `RuinGrowth.emit`);
- `Build.solid` (classic and eroded looks);
- `RuinLod` growth levels and shadow chunks;
- `KitLand.edge_distance`, `Build.thickness` and `LateShapes._cut`.

Also from the WIP: side-by-side isle builds on high-priority workers
(`--isle-builds=N`, default threads less 2), and the water-material fix.
The engine's float rules are mirrored op for op. Details are in git history:
`native-isles-round1-wip.md` at 7f65f9a9.

This round (commit 45ad3bae):

- **`scripts/late_shapes.gd` `drain`.** A body leaves the physics space
  (`body_set_space(rid, RID())`) while a slice of its held shapes goes back,
  then returns. Jolt builds its compound once, not once per shape. The same
  shapes in the same order.
- **`scripts/kit_isle/kit_flora.gd` prober: plant rays now deterministic**
  (placed motif isles only; the base isle and the studies are unchanged).
  - **Turf wins a tie** (`_turf_at_tie`, within 1 mm). Where a cliff's cap
    lies exactly on the turf, Jolt's closest hit is whichever body it visits
    first, so the outcome depended on creation order and so on load timing.
    The tie check keeps the bodies already looked past excluded.
  - **Enemies and traps are looked past** (`MotifIsle._neighbour`,
    `EnemyField`/`TrapField`). Their bodies are StaticBody3Ds moved by
    script.
- **`KitFlora._mesh_triangles`** is cached per mesh (no readback per batch).
- **Quits mid-load.** `MotifIsle._forget` and `NextRegionLoader._exit_tree`
  drain their tasks with `FixedCache.drain` (they flush the renderer while
  waiting), as `run_layer` does. Rendered `--quit-after 2/60/160` all exit 0.
- **`FixedCache.LOOSE_FLAGS`** gained `--no-stills`, `--frames`,
  `--isle-builds=` and `--flora-records`. Every flag outside it is part of
  the cache key, so measuring flags evicted the cache.
- **`tools/bench_loading.gd`** gained:
  - `--no-stills`;
  - `--frames` (per-frame CSV, with `tools/frame_probe.gd`);
  - per-isle `flora` count lines;
  - `--flora-records`;
  - `--raygrid` lines written to files.

## Identical output

- **The 38-isle dump** (`tools/native_isles_bench.gd --mode=dump`): sprawl 2,
  ring 1, sprawl 5, ring 4 and `--all`, 46 files in all. The base (edfc5395,
  GDScript), this branch native, and this branch `--gdscript-kernels` are
  byte-identical (`diff -rq`, `/tmp/ni/d_{base,nat,gd}`).
- **Plants, sprawl 2, tufts per isle in isle order:**

  | | Gorge | Colonnade | Stair clouds | Colonnade | Stair clouds | Bell spires | Gorge | Roost |
  |---|---|---|---|---|---|---|---|---|
  | Base (9 runs) | 8375 | 4279 | 2031 / 2201 | 4281 | 3114 / 3185 | 4155 | 8363 | 7107 |
  | After (every run) | 8383 | 4286 | 3389 | 4288 | 3332 | 4155 | 8363 | 7107 |

  The after counts are identical over 12+ runs at every thread count, cold
  and warm, and in the much slower GDScript-fallback run. Every plant's
  counts are hashed. The base itself varies (the stair isles; ring 1's third
  isle gave 2033/2085/2350 over 9 base runs).

  **This is visible.** The first stair-clouds isle has about 1,200 more
  tufts and the second about 200 more. On the base, the cliff caps usually
  won the ties there. Round 2 recorded about 3,289 on that isle before
  shapes were held back, so this is close to the older look.

  The opposite rule (cliff wins ties) was tried once: 4255 / 2005 / 4240 /
  2061 / 4150, fewer than the base everywhere. If the user prefers the
  sparser stair isles, that's the rule to switch to. Ring 1 "after" counts
  were not taken.
- **The base isle's plants:** 9,890 tufts, as on the base.
- **The collision probe (`--raygrid`; plants not involved).** 1,600 downward
  rays per isle, each recorded as height to the millimetre plus the collider
  class, then hashed per isle.
  - rg-base and rg-after have the same hit counts on all 8 isles but
    different hashes on 7. The differing lines are single 1 mm roundings:
    the same colliders hit, with heights micrometres apart that round to
    the other side of 0.5 mm.
  - **Nothing moved; it's the order.** The base also differs from itself
    run to run (12 and 2 lines on two isles), and this branch is stable run
    to run.
  - Both the WIP's parallel standing order and the new drain contribute
    (they were attributed by putting the old drain back). Jolt builds a
    compound in a different local frame when shapes arrive in a different
    order or all at once, and convex ray casts are iterative, so hit points
    move by micrometres.
- **Stills:** not taken this round.

## What's left

1. Finish the matrix (`/tmp/ni/matrix.sh`, which stops on `/tmp/ni/STOP`):
   after sprawl 2 warm at 2 threads, all of ring 1 after, and ring 1 plant
   counts. Run each side's warm runs together, because the sides evict each
   other's fixed cache (one `user://fixed_cache` for every worktree).
2. Rendered stills of the same spots before and after
   (`tools/bench_run_layer.gd --stills`), especially the far ruin growth and
   the stair isles' grass.
3. Tests: `test_run_layer` and the tests near ruin kit, LOD, late shapes, kit
   land, kit flora, kit water and the motif sky. Not run. Known failures on
   the base: `test_aqueduct_isle_look`, `test_aqueduct_isle_sky`,
   `test_motif_sky`, `test_layer_sprawl`, `test_broken_ring_isle`,
   `test_motif_families`. A test that pins plant counts on placed stair or
   colonnade isles will break (more tufts now). None was checked.
4. Next speed-ups, in order:
   - **Readbacks:** `piece_block` on a cold cache; the roost's mesh
     re-reads, which also fix the one-thread deadlock.
   - **A bit-exact native `Roost.ground`:** the roost build, 3.2 s, and the
     dragon's settle.
   - **The motifs' path wear** (1.2 s of flora).
5. Windows: run it there (below).

## Windows DLLs

Cross-compiled on the Mac with Homebrew `mingw-w64`, after the last native
source change, so they're current:

    python3 tools/build_native_kernels.py --godot <Godot> --godot-cpp ~/.cache/zs-plate-maps/godot-cpp --scons ~/.cache/zs-plate-maps/sc/bin/scons --platform windows [--target template_release]

They import only KERNEL32 and the UCRT, export `zenscape_kernels_init`, and
are not run on Windows yet. Copy these three files from this Mac's worktree,
`/Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/native-isles/`,
to the same paths in the PC's checkout of `perf/native-isles` (all are
gitignored):

- `native/terrain_kernels/bin/zenscape_kernels.windows.template_debug.x86_64.dll` (sha256 26206b6a…)
- `native/terrain_kernels/bin/zenscape_kernels.windows.template_release.x86_64.dll` (sha256 b0449990…)
- `native/terrain_kernels/zenscape_kernels.gdextension`

Then run `& $env:GODOT --headless --editor --path . --import` and play as
above. Without them, the game runs on the GDScript fallback.

Building on Windows instead:

1. Install VS Build Tools (C++) and Python 3.
2. `py -m pip install scons==4.8.1`.
3. Check out godot-cpp at commit 6cceaf6a.
4. Run `py tools/build_native_kernels.py --godot $env:GODOT --godot-cpp <path> --scons scons`, for both targets.

## Gotchas

- Fixed-cache keys hash every script and every launch flag outside
  `LOOSE_FLAGS`. After any edit, or with a new flag, the next launch is
  cold.
- Headless benches of worker builds: don't block the main thread in
  `wait_for_task_completion`, because a worker's renderer call needs its
  flush.
- Bit-exactness rules for the kernels: see the WIP note in git history
  (7f65f9a9).
