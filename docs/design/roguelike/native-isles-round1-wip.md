# Native isles, round 1: work in progress (paused 2026-10-14)

> On `perf/native-isles` (from `perf/loading-screen`). Not merged. Paused
> when the user needed the machine; the final doc
> (`native-isles-round1.md`) is not written yet.

## What works

The motif isles' number crunching runs in C++ in the existing extension
(`native/terrain_kernels/`, class `ZenScapeIsleKernels`), and the isles of a
layer build side by side on the worker pool. GDScript fallbacks are kept.
Output is byte-identical (see Proof).

Ported (all in `native/terrain_kernels/isle_math.h`, `isle_finish.h`,
`isle_solid.h`, `isle_kernels.h`; loader `scripts/native_isle_kernels.gd`):

- `RuinKit Build.finish` from `_ivy` to the end of `_draw`: the ivy, fringes,
  vine curtains, moss cushions, eroded-look `_erode`/`_covered`/`_hidden`,
  `RuinGrowth.emit`, the stone and growth arrays (`ruin_finish`). This was 56 %
  of the build. Falls back to GDScript for a ground callable, shelter, a bend,
  or a carved look.
- `RuinKit Build.solid` for the classic and eroded looks (`ruin_solid`): `_wear`,
  `_polys`, `_unique`, `_dial`, `_shade` (its random draws and noise), tops,
  solids, hull, `thickness`, floating blocks. Clean looks stay in GDScript.
- `RuinLod`: growth groups, levels, index, shadow chunks (`growth_levels`,
  `growth_chunks`).
- `KitLand.edge_distance`, `Build.thickness` (`hull_thickness`),
  `LateShapes._cut` (`cut_faces`).
- The engine's own float rules are mirrored op for op: float vs double
  narrowing, PCG32 RNG from `rng.state`, Godot's `SortArray` (for
  `sort_custom` ties), `compute_convex_mesh_points`, contraction off. sin, cos,
  atan2 and `srgb_to_linear` come from libm on macOS (the engine's own) and
  from the engine's own functions elsewhere (`--engine-math` forces that path
  on a Mac too; also verified identical).
- The loader checks `version()` (2); a stale library is left unused, with a
  warning, and the game builds in GDScript.

Also on the build path:
- `scripts/kit_isle/motif_sky.gd`: `build_width` isles build at once
  (`--isle-builds=N`, 0 = all; default worker threads less 2), as
  high-priority tasks. Low-priority tasks only get 30 % of the pool (1-2
  threads on a 6-8-thread PC).
- `scripts/kit_isle/kit_water.gd` `material()`: copies the base material's
  stored properties instead of `duplicate()`. On a worker, `duplicate()` asked
  the renderer for each shader parameter and waited one frame per parameter:
  about 37 frame waits in the sundered gorge, 19 s at 2 fps and 2 s at 15-20 fps.
  Same material.
- `RuinKit Build.materials()`: dresses the shared stone material only when
  the look changes (concurrent builds used to write it at once).
- `motif_isle.gd`: `timings.worker`, `queued`, `built_at` and `up_at` in
  `--loading-trace`.

## Profile (headless, sprawl 2, one isle at a time, M5 Pro)

Before: 19.4 s for the 8 isles. By self time:

| Function | Share |
|---|---|
| `Build._inside` | 20.9 % |
| `_polys` (and its sort lambda) | 17.2 % |
| `RuinGrowth.emit` | 9.2 % |
| `KitLand.edge_distance` | 6.4 % |
| `solid` | 5.6 % |
| `_solid_at` | 3.5 % |
| `_unique` | 2.9 % |
| `ruin_lod._groups` | 2.7 % |
| `KitLand.surface` | 2.6 % |
| `thickness` | 2.3 % |

`Build.finish` was 10.9 s of the 19.4 s in total. Object creation is small,
as round 2 said.

Per isle, build + LOD + held shapes (ms):

| Isle | Before | After |
|---|---|---|
| Sundered gorge | 2086 | 549 |
| Colonnade spine | 3403 | 862-908 |
| Stair clouds | 2765 | 672-709 |
| Bell spires | 1346 | 251 |
| Dragon roost | 1198 | 769 |
| Broken ring | 1315-1648 | 197-248 |

What GDScript is left in a build: `KitLand.surface` and the motifs' own
callables, `leveled_mesh` (mostly engine SurfaceTool/ImporterMesh), LateShapes
`defer_body`, the motif-specific art.

Headless, workers (old low-priority bench, before `solid`/`cut` were ported):
8 isles in 7.3 s one at a time, 2.6 s side by side.

## Proof of identical output

`tools/native_isles_bench.gd --mode=dump` dumps each isle node by node
(round 2's dump: properties, metas, mesh `_surfaces` bytes and kept arrays,
shapes, materials, all hashed). The baseline is the unchanged code
(`perf/loading-screen`).

- 28 isles: sprawl 2, ring 1, sprawl 5, ring 4. All the same as baseline,
  native.
- Sprawl 2 + ring 1: also the same with `--engine-math` and with
  `--gdscript-kernels` (the fallback after the GDScript edits).
- `--all`: cloister tarn, drowned nave, hollow keel, broken ring (default,
  11, 222, 3333), colonnade (11, 222, 3333): all the same.
- Stills (`tools/bench_run_layer.gd --stills`, sprawl 2, `/tmp/ni/stills/`):
  the same isles, ruins, curtains and far growth. The differences are the
  airship, the cloud tower and sway.

## Launch to playable (rendered, windowed, 1080p cap; not a quiet machine)

Load average was 2-4 (another agent's runs). Read times as ±15 %. Threads are
set with `override.cfg` `threading/worker_pool/max_threads`; the after runs
use `--isle-builds` = threads.

| Threads | Sprawl 2 before | Sprawl 2 after | Ring 1 before | Ring 1 after |
|---|---|---|---|---|
| all (18) | 50.2 s | 33.9 s | 43.2 s | 25.5 s |
| 8 | 50.6 s | 36.8 s | 40.7 s | 28.1 s |
| 6 | 47.8 s | 31.4 s | 37.1 s | 23.3 s |
| 1 | timed out (400 s) | timed out | timed out | timed out |

The one-thread runs hit the 400 s alarm in both builds, so that cap starves
something (probably the plan or the loading flow waiting on a busy worker).
Not investigated; it should be noted, or measured with 2 threads instead.

Where the after time goes (sprawl 2): boot to screen about 5.5 s, "laid"
(base isle, plan, stage, the dragon) about 8 s, isles about 12-17 s,
material warm-up 4-6 s. With side-by-side builds, every isle is built before
the main thread looks: `built_at` was the same frame for all 8. The isles
phase is now the main thread's stand + flora + life, one isle after another
(about 11 s of main-thread work). Builds are off the critical path.

Raw logs: `/tmp/ni/load/{before,after}-<shape>-<seed>-t<threads>/log.txt`
(per-isle `timings` lines in each).

## Windows

The DLL is cross-compiled on this Mac with Homebrew `mingw-w64` (GCC 16.2):

    python3 tools/build_native_kernels.py --godot <Godot> --godot-cpp <godot-cpp> --scons <scons> --platform windows [--target template_release]

Built in `native/terrain_kernels/bin/`, gitignored:
- `zenscape_kernels.windows.template_debug.x86_64.dll` (sha256 26206b6a…)
- `zenscape_kernels.windows.template_release.x86_64.dll` (sha256 b0449990…)

They import only KERNEL32 and the UCRT `api-ms-win-crt-*` (libstdc++ static)
and export `zenscape_kernels_init`. The SConstruct drops MinGW's `lib` prefix
so the names match the descriptor. To use them, copy both DLLs into
`native/terrain_kernels/bin/` and `native/terrain_kernels/zenscape_kernels.gdextension`
into the Windows checkout. Not run on Windows (no machine, no Wine).

Building on Windows instead: VS Build Tools (C++), Python 3, `py -m pip
install scons==4.8.1`, godot-cpp at commit 6cceaf6a, then
`py tools/build_native_kernels.py --godot $env:GODOT --godot-cpp <path> --scons scons`
(both targets).

## Not done / next

1. The final doc `native-isles-round1.md` and the summary.
2. Re-measure on a quiet machine. Replace the 1-thread row (2 threads, or find
   why it hangs). Run the headless scaling with high-priority tasks: the bench's
   `--mode=par` still uses low priority, which caps it at 5 threads here.
3. Smoke checks not yet run on the final code: headless import, run_layer
   sprawl 2 and ring 4 for 400 frames (run once mid-round, clean), a
   rendered run per shape (the matrix runs played), a run with the library
   removed, `test_run_layer` and the tests touching ruin kit, LOD,
   late shapes, kit land, kit water and the motif sky.
4. Plant counts in the rendered runs: compare `(placed): flora {...}` before
   and after. Parallel builds change the main thread's timeline, and round 2
   found plant rays timeline-dependent. The `perf/load-safe` agent owns plant
   placement.
5. Optional: port `KitLand.surface`'s loop (it calls motif callables), stand
   the base isle off the main thread, speed up the main-thread
   stand/flora/life (now the wall).

## Gotchas

- After merging, the main checkout's library has no isle kernels until it is
  rebuilt. The game still runs (version check, GDScript).
- `build_profile.json` is unchanged. Noise is called through `Object::call`, so
  godot-cpp needs no new classes.
- Bit-exactness: GDScript widens Vector2/Vector3 components to double before
  scalar maths (`WOBBLE.y-WOBBLE.x` is a double subtraction). An identity
  `Basis * v` can turn -0 into +0, so the identity product is computed, not
  skipped. `sort_custom` must be Godot's introsort.
- Headless benches of worker builds: don't block the main thread in
  `wait_for_task_completion` (it deadlocks), and cap the fps (frame-synced waits).
- Second worktree `.claude/worktrees/native-isles-base` (detached at
  `perf/loading-screen`) holds the before builds; remove it when done.

## Verify

    Godot --headless --path . -s res://tools/native_isles_bench.gd -- --layers=sprawl:2,ring:1 --mode=dump --out=/tmp/a
    Godot --headless --path . -s res://tools/native_isles_bench.gd -- --layers=sprawl:2,ring:1 --mode=dump --out=/tmp/b --gdscript-kernels
    diff -r /tmp/a /tmp/b
    # timings: --mode=time; profile: Godot --headless -d --profiling ... --mode=profile, then tools/native_isles/agg.py
    # rendered loads: tools/native_isles/run_load.sh <worktree> <tag> sprawl 2 all [--isle-builds=N]
