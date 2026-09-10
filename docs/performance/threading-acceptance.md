# Threading acceptance record

September 9, 2026. This is the current acceptance audit, not a declaration that
all interaction targets are met. Detailed measurements and the sequence of fixes
are retained in [background-work.md](background-work.md).

## Revised working objective

User direction, September 9: improve interaction performance across multicore
CPUs and mainstream GPUs, preserving visual quality, terrain results, undo/redo
and physics behavior. Mac/Metal is the available measurement environment, not
the intended hardware model; Windows validation is not a prerequisite for the
next improvements. Report hardware limits without making unmeasured portability
claims. Reduce total computation and expensive engine calls as well as spreading
work across cores. Evaluate a small C++ GDExtension behind the existing packed-array
worker boundaries before committing to additional kernel ports.

The frame-budget assertion, collider readback changes and first C++ mesh-shading
experiment are now implemented and validated below. Next: reduce the remaining
anchor, content and landmark refresh costs; pool debris if allocation remains
a measured bottleneck; investigate cold initialization using compilation evidence. Compare p95/p99 and frames over 16.67 ms alongside
completion latency. Additional hardware measurements should guide concurrency
defaults when available, rather than block this sequence.

## Scope and evidence

| Requirement | Current evidence | Status |
| --- | --- | --- |
| Terrain formation uses private worker computation | Recipe heights, gradients, water grid, face probes and desert geology run on detached inputs. Recipe/geology differential suites compare synchronous results and 1/2/4/8 partitions. | Verified for the tested recipes and fixtures |
| Destruction computes away from the main thread | Ordered carve/rupture/collapse preparation runs in one finite worker. Native destruction tests compare terrain bytes, chunk arrays, cleaned collider points and motion recipes. | Verified; ordering prevents charge-level parallelism |
| Navigation scales while physics queries stay safe | Private native/Fidelity snapshots, partitioned sampling, bounded main-thread validation, complete-map publication and live clearance checks. Native and rendered 1/2/4/8 sweeps preserve exact maps. | Verified for the tested providers |
| Publication is bounded and preserves visuals | Cooperative 2 ms checkpoints; hidden instance/debris staging; matching source/debris publication; collision preparation before physics release. | Partial: individual engine calls remain unsliced, and sustained sculpting still has large frame gaps |
| Undo/redo, save/load and physics behavior are preserved | Formation, world integration, native explosions, selection and Bigfoot explosion suites cover exact state restoration, real movement, collision geometry, pause and recovery. | Verified for those scenarios |
| Ownership, supersession and teardown are audited | Recipe, mesh, map, instance and refresh input guards; latest-generation publication; six scene teardown phases; direct navigation-owner destruction. | Verified for tested lifetimes; finite work can delay destruction |
| Queues and hardware capacity are bounded | One admitted finite job/group per stage owner; at most eight partitions per group; CPU-minus-two cap; newer requests coalesce before submission. | Per-owner bounds verified; no global cross-world admission limit |
| Applicable worker configurations are benchmarked | Recipe, geology, shading, surface-map and navigation sweeps cover 1/2/4/8. Ordered destruction and small instance work retain one worker. | Verified with fixture-specific limits |
| The broader interaction suite is responsive | Local formation and repeated blast intermediate gates pass in their stated configurations. Sustained sculpting and cold Beauty initialization fail broader frame-time targets. | Incomplete |
| Platform and quality limits are explicit | Native Forward+/Metal on Apple M5 Pro; Balanced and Beauty cases measured below. | Windows, fresh shader caches and additional physics capacity remain unverified |

## Selected concurrency

- `NativeTerrainData.recipe_workers = 0` selects one worker for foundation and
  up to four for heavier recipes. Positive values are explicit overrides.
- `mesh_workers = 0` automatically selects two GDScript workers. When built, the default
  C++ kernel shades up to 8,192 faces inline (about 0.5 ms in this fixture),
  avoiding a worker round trip; larger meshes retain workers. Positive values
  explicitly select worker counts. Ordered shore preparation remains one.
- Surface maps and navigation default to four workers.
- Parallel groups are capped at eight and available logical CPUs minus two,
  with a minimum of one. Engine scheduling still determines actual execution.
- Destruction preserves sequential dependencies between charges. Instance
  recipes use one worker for substantial native inputs; small inputs retain
  synchronous sampling with staged publication when requested.

Earlier three-trial median completion measurements, in milliseconds:

| Fixture | 1 worker | 2 workers | 4 workers | 8 workers |
| --- | ---: | ---: | ---: | ---: |
| Recipe range plus water, CPU-only | 1434.6 | 1026.2 | 866.6 | 907.8 |
| Sculpted alpine-water mesh | 42.0 | 33.1 | 33.1 | 33.4 |
| Populated native surface maps | 94.3 | 75.8 | 58.6 | 58.9 |
| Native navigation geometry | 158.1 | 91.4 | 58.1 | 58.1 |
| Rendered Beauty navigation, current audit | 181.0 | 110.8 | 84.8 | 73.6 |

These fixtures have different workloads and measurement boundaries; their times
must not be added together or treated as game FPS. The Beauty navigation sweep
excludes geometry refresh, manually controls scene simulation and includes actor
reconciliation. Its maximum measured worker-loop frame gaps were 12.6–13.1 ms.
The seven desert-geology families have their own complete sweep in the history.

## Current interaction measurements

The blast profiler now waits for macOS window restoration, sets a 1440×900
physical viewport and verifies it after warmup. Both quality modes use native
Forward+, render scale 1.0 and the project's MSAA setting. Each trial retains
100 debris bodies. The controlled comparison is:

| Quality | Maximum frame gaps, ms | Completion times, ms | Frame p95 range, ms |
| --- | --- | --- | --- |
| Balanced | 46.3 / 45.6 / 45.4 | 363.5 / 337.9 / 321.3 | 23.7–26.3 |
| Beauty | 47.5 / 45.9 / 46.5 | 387.4 / 353.6 / 356.7 | 25.0–26.9 |

Both pass the repeated-blast 50 ms intermediate gate at that viewport. Earlier
runs exposed asynchronous window restoration and cannot support a direct quality
comparison when their viewport sizes differ. The new configuration output makes
this explicit. Metal GPU timers return zero and remain unavailable evidence.

The engine physics-process counter is also sampled. It includes engine/game
physics processing and is not an isolated solver profile. It does not prove spare
capacity for more bodies, larger worlds or future physics features.

Three Balanced cold Open Meadow runs with automatic recipe concurrency passed
the 50 ms gate: foundation maxima 39.6 / 43.0 / 43.5 ms, range maxima
32.4 / 14.5 / 29.3 ms. Exact mesh/maps, animation, edit exclusion and undo/redo
passed. These use an existing shader cache.

Beauty cold initialization remains a limit: a run reporting an initial
3024×1898 viewport reached 130.9 ms during foundation startup; range peaked at
25.0 ms. After warming the scene, Beauty foundation/range peaked at
18.9 / 20.6 ms. All geometry/map and undo assertions passed. This separates cold
initialization from ongoing formation; it does not waive the cold failure.

The 30-dab Bigfoot Life sculpt profile exposed a further unresolved case. At the
reported 3024×1898 physical size, individual refreshes peaked at 48.0 ms, while
full frame intervals peaked at 93.5 ms with p95 73.2 ms. Idle p95 was 17.1 ms.
The fixture calls the actual synchronous dab/refresh path with live navigation
and collision work. Smaller navigation-only slices cannot prove this combined
interaction responsive. This is the next profiling target.

The initial run also reported 36 leaked ObjectDB instances and rendering resources,
even after explicit scene destruction. Those warnings are now resolved: inherited
scene script replacement stranded five visual helpers allocated in Fidelity's
member initializers. They are now constructed in `_ready()`. Reflection waits also
use their node's signal so tree shutdown cannot resume a freed coroutine.
The new inherited-scene lifetime regression and a full sculpt replay exit cleanly.
The later frame-budget assertion is also resolved. The first native frame signal
can fire while `Engine.get_process_frames()` is still zero. The regression now
counts actual signal emissions, verifies the exhausted-budget wait and fresh
slice, and passes with the lifetime checks. No helper timing change was needed.
That replay still peaks at 94.0 ms (p95 72.5 ms), with collision callbacks reaching
22.8 ms, so resolving ownership has not resolved the sustained interaction stall.

## Collider readback and native-kernel follow-up

The sculpt harness now applies its window size after study startup (which
maximizes the window), then verifies 1440×900 after warmup. These new timings are
comparable with each other; they are not a direct percentage comparison with the
earlier 3024×1898 runs.

| Sculpt fixture | Maximum frame ms | Frame p95 ms | Frames over 33 ms |
| --- | ---: | ---: | ---: |
| Before collider change, verified 1440×900 | 82.2 | 67.2 | 30/76 |
| CPU collision faces, same viewport | 67.1 | 56.9 | 30/77 |
| CPU collision faces + C++ shading | 67.2 | 57.6 | 30/77 |

Terrain collision preparation drops from a median 14.7 ms for the old shape path
to about 0.3 ms for CPU faces plus 1.1 ms for physics shape construction. The CPU
path reproduces Godot's triangle snapping, with byte-identical collider faces
across imported terrain, edits, undo/redo, worker meshes and tunnel transitions.
The tunnel, native explosive and Bigfoot explosive integration suites pass.

Blast hulls now feed retained CPU vertices into Godot's original convex cleaner
through a private, never-rendered Mesh adapter. Shape creation remains on main.
The exact cleaned-point comparison still passes for surface, buried and salvo
fixtures; no hull-equivalence requirement was relaxed. The hull batch falls from
23.2–23.6 ms to 1.1–1.3 ms; the slowest single hull drops from about 12.8 ms to
0.07–0.14 ms. With both collider changes, three Balanced 1440×900 blasts complete
in 308.4 / 283.9 / 288.6 ms, with p95 22.9 / 21.5 / 22.2 ms. Maximum frames remain
46.8 / 45.2 / 45.2 ms during refresh. Readback was expensive, but was not the sole
cause of the maximum frame.

The GDExtension in `native/terrain_kernels` ports the mesh-shading loop.
Ordinary launches select it automatically when built. Unbuilt checkouts retain
the GDScript fallback; `--gdscript-kernels` forces that fallback for comparisons.
`--native-kernels` requires the native library during validation. Build instructions and the pinned godot-cpp revision are in
that directory's README. Synchronous output, explicit 1/2/4/8 partitions,
automatic dispatch, incremental meshes and stale results match the retained
sequential reference exactly. Native refresh retry/publication tests also pass. Lifecycle fixtures explicitly
request workers when testing pending-job destruction; staged debris separately
checks resource disposal even when all computation has already joined.
Isolated one-worker shading medians fall from 3.05 / 3.46 / 8.50 ms in GDScript
to 0.31 / 0.29 / 0.46 ms in C++ for imported-cover, foundation-tint and
sculpted-alpine-water respectively. This is a kernel speedup, not game FPS.
Automatic native dispatch reduces the rendered mesh stage from about 38 to 26 ms.
Three isolated native blasts complete in 299.7 / 269.8 / 298.9 ms with maximum
frames 46.7 / 45.0 / 45.5 ms and p95 23.1 / 21.3 / 22.3 ms. Other refresh work
still determines the frame maximum.

Current sculpt stage medians with the kernel enabled are mesh 0.82 ms, anchors
8.89 ms, content 7.05 ms, landmarks 5.99 ms, maps 1.13 ms and post-map work 1.82 ms.
Landmarks peak at 15.81 ms. Small incremental shading was already cheap: its C++
port does not materially improve this sculpt fixture beyond the collider fix.
Anchor/content/landmark updates are the next profiling targets. The frame-budget
and collider changes are enabled normally; built C++ kernels now run by default.

## Ownership and acceptance limits

The final lifecycle run, after automatic foundation concurrency was introduced,
submitted 84 burst requests across recipe, mesh and navigation owners. Peak work
awaiting join was 12 jobs / 28 partitions; it drained to zero in about 1.12 s.
Recipe, mesh, surface-map, instance, staged-blast and reflection scene teardown
also drained to zero and released terrain inputs. These counters describe
submitted work awaiting join, not simultaneous CPU threads.

Outstanding acceptance work:

1. Reduce the remaining combined sustained-sculpt frame gaps, including synchronous refresh,
   navigation/collision notifications and rendering effects.
2. Investigate cold Beauty initialization without reducing visual quality or
   moving the cost outside the measured user experience.
3. Extend fixed-viewport reporting where needed before comparing resolutions.
4. Measure additional CPU/GPU configurations when available and clean shader-cache
   startup before portable performance claims. Windows-specific acceptance is not
   a prerequisite for the next optimization work. No additional hardware results
   are available in this worktree.
5. Treat 16.67 ms presentation and additional physics capacity as unachieved.
   Add global admission before supporting arbitrarily many simultaneous worlds.

## Reproduction

Use Godot 4.7.2 with `--path . --rendering-method forward_plus --script` for native
tests, one graphical process at a time. Pass test arguments after `--`.

- `tests/test_formation_responsiveness.gd`: `--quality=balanced` or
  `--quality=beauty`; optionally `--warm-scene` or `--workers=N`.
- `tools/profile_explosions.gd`: `--quality=balanced` or `--quality=beauty`.
  `--capture` is visual evidence only: GPU readback changes timing.
- `tests/test_live_edit_navigation.gd`: `--quality=beauty --benchmark`.
- `tools/profile_sculpt.gd`: `--out=/tmp/sculpt.json --dabs=30 --size=1440x900`;
  inspect the reported physical size rather than assuming the requested size.
- `tests/test_threaded_recipe.gd`: CPU-only `--headless`; `--workers` enables
  its three-trial 1/2/4/8 sweep.
- `tests/test_threaded_mesh.gd`, `test_threaded_surface_maps.gd`,
  `test_threaded_navigation.gd`, `test_threaded_geology.gd`: `--benchmark`.
- `tests/test_threaded_instances.gd`, `test_threaded_refresh.gd`,
  `test_threaded_destruction.gd`, `test_threaded_lifecycle.gd`: correctness,
  publication and ownership checks.
- `tests/test_native_collision_faces.gd`: exact CPU collision geometry and cache
  ownership across edits, history and tunnel transitions.
- `tests/test_inherited_scene_lifecycle.gd`: base-scene disposal before `_ready`,
  inherited Bigfoot Life/Open Meadow teardown, and frame-budget wait ownership.
