# Background work and consistent frame times

For the current requirement-by-requirement status, see
[Threading acceptance record](threading-acceptance.md). This file preserves the
measurement and implementation history; later sections supersede earlier results.

September 9, 2026; Godot 4.7.2, Apple M5 Pro, native Forward+/Metal.

The objective is responsive editing, world formation and destruction, with room
for more physics and richer visuals. Core utilization is a means to that end.
A useful first acceptance target is consistent 60 Hz presentation (16.67 ms),
with CPU and GPU headroom during interactions, not just a high idle average FPS.
That target is proposed, not yet achieved or validated across target hardware.

## Inherited first step (before the dedicated implementation)

Live terrain recipe preparation now runs through WorkerThreadPool. A job owns
its recipe, copied settings and input arrays, and computes height, face-gradient
and optional pond-height tables. The main loop polls completion and joins the
finished task before publishing the tables together. Loading and undo retain
the synchronous path. Generation checks discard superseded recipe results;
recipe callers stop before applying stale heights or dressing stale terrain.

The inherited implementation used one background worker per preparation, not an 18-core parallel scan.
The editor's existing formation transaction prevents competing interactive edits.
The helper requires finite data-only callables; it does not cancel computation,
coalesce an arbitrary request queue, or make scene/physics APIs thread-safe.
Abandoned work is joined on helper destruction. A larger job system will need
explicit queue limits and owner-lifetime handling before broad adoption.

The recipe arithmetic, sample positions, precision and resulting visual detail
are unchanged. Mesh/texture creation, scene updates and physics remain on the
main thread. Rendering and physics settings were not changed.

## Measurements

The CPU-only regression fixture drives the actual `_set_recipe` path with
4,225 vertex positions and 8,192 face positions. It deliberately creates no
renderer. Before the change, foundation live sampling took 1.21–2.12 seconds
versus about 0.25 seconds synchronously; range live sampling took 4.84–8.16
seconds versus 1.36–1.38 seconds synchronously. Cooperative frame scheduling
accounts for much of the completion delay.

With workers, the final fixture run measured:

| Recipe | Synchronous | Live worker |
| --- | ---: | ---: |
| Foundation | 246 ms | 252 ms |
| Mountain range | 1,316 ms | 1,319 ms |

These are local CPU timings with variable frame scheduling, not a displayed FPS
claim or an all-core throughput speedup. The worker removes the frame-budget
scheduling penalty and keeps the main loop available while sampling.

The native Open Meadow integration test completed foundation in 40–41 frames
(previously 107–111) and range in 77 frames (previously 333–347). Its final run
measured 541 ms and 815 ms of total formation time respectively. The remaining
maximum gaps were 70.3 ms and 33.8 ms. Foundation still fails the existing 50 ms
responsiveness threshold. Earlier baseline foundation runs saw 1,112.8 ms and
65.5 ms gaps; first-use and run-to-run effects prevent claiming that this patch
has fixed the worst hitch. Remaining synchronous work needs stage profiling.

The existing native `profile_explosions.gd` scenario, unchanged by this patch,
created 100 debris bodies per trial. Detonation/max-frame intervals were
216.6 ms, 135.3 ms and 132.3 ms; frame medians were about 16.0 ms and p95 values
16.9–17.8 ms. This makes burst destruction work the strongest measured next
priority. Metal reported zero GPU time, which is unavailable evidence rather
than proof of zero GPU cost. This is a baseline, not a destruction improvement.

## Validation

- `test_threaded_recipe.gd`: passes. Actual worker execution, synchronous
  fallback, main-loop progress, byte-identical height/gradient tables, exact
  float64 pond grid, connected/inland recipes and superseded public formation.
- `test_native_refresh_incremental.gd`: passes all sculpt, paint, prop, water,
  undo/redo and full-rebuild equivalence checks.
- `test_native_range.gd`: passes imported-reference geometry, variation,
  undo/redo and save/reopen checks; maximum reference error 0.000000954.
- `test_formation_responsiveness.gd`: mesh/map equality, edit exclusion,
  animation/world progress and undo/redo pass. The foundation timing assertion
  still fails. The test now accumulates animation progress because the actor's
  `_age` resets on state transitions; it is not a lifetime clock.
- `git diff --check`: passes. CPU tests emit the existing macOS certificate
  warning in the sandbox.

Reproduce CPU correctness (no rendered scenes):

```sh
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . \
  --log-file /tmp/zs-recipe-test.log --script res://tests/test_threaded_recipe.gd
```

Append `-- --benchmark` to enable the relative completion-latency assertion.
Run the three native tests above graphically, one at a time, with
`--rendering-method forward_plus --script res://tests/<name>.gd`.

## Next steps toward the quality target

1. **Close the formation hitch.** Time recipe submission/publication, terrain
   arrays, map pixels, content rebuild and collision publication separately.
   Move the measured pure-data bottlenecks to private jobs; keep final scene
   changes small. Snapshotting and publication must be measured too.
2. **Make destruction a bounded transaction.** Use `profile_explosions.gd`
   to separate fracture/collapse computation, refresh, collision-shape work,
   body creation and simulation. Prepare geometry from snapshots, preserve
   collision consistency at publication, reuse debris resources where useful,
   and limit activation work per frame. Threading computation alone cannot
   remove a large synchronous body/scene publication cost.
3. **Recover navigation promptly.** Snapshot terrain, water and obstacle data;
   build a complete replacement map off-thread and reject stale generations.
   The Bigfoot Life clearance callback queries `direct_space_state`; it cannot
   simply move into the same worker. Keep physics queries at an appropriate
   physics boundary or replace that part with a validated data representation.
4. **Create physics headroom.** Evaluate the existing Jolt work separately with
   repeatable debris/body-count stress cases. Audit direct-space queries before
   changing physics-thread settings. Compare simulation cost and frame tails,
   including collisions, sleeping, explosions and actor recovery.
5. **Spend saved time deliberately.** Benchmark a small worker group only after
   isolating independent output chunks. Keep capacity for engine tasks. Reduce
   unnecessary scene rebuilds and allocation churn. For visual upgrades, use
   the existing rendering multiplier profiler to find GPU headroom; CPU workers
   do not directly reduce shading, foliage overdraw, shadows or fog cost.

Use a fixed scenario suite: repeated sculpting, a populated-world edit, connected
world formation, repeated blasts and Bigfoot roaming through changes. Record
completion latency, frame p50/p95/p99/max, physics time and result correctness.
Include warm and first-use cases, native resolution, both Balanced and Beauty,
and the intended Windows GPU. Tune against these experiences, not CPU graphs.

Godot's rendering thread-model setting is explicitly experimental, with known
crashes and possible synchronization jitter; it is not the first reliability
improvement to make. See the official
[ProjectSettings documentation](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html#class-projectsettings-property-rendering-driver-threads-thread-model).
Completed worker tasks must be joined to reclaim their resources; see
[WorkerThreadPool](https://docs.godotengine.org/en/4.7/classes/class_workerthreadpool.html).

## Dedicated implementation acceptance stages

1. Preserve exact recipe, probe, mesh/map and undo/redo results; test worker
   cleanup, supersession and private ownership before expanding job use.
2. Remove the first-use probe stall from destruction with off-thread topology
   preparation during formation. Compare native blast and formation frame tails.
3. Bound destruction computation/publication and navigation rebuild queues;
   require repeated blast maxima below 50 ms as an intermediate target, then
   measure progress toward 16.67 ms. Preserve collision publication ordering.
4. Benchmark independent recipe work at 1/2/4/8 workers, recording completion
   and main-loop/frame tails; reserve engine capacity and select the smallest
   concurrency with a useful measured latency improvement.
5. Validate the interaction suite and document platform/quality limits. Windows,
   Balanced/Beauty and future physics headroom remain unvalidated until measured.

The dedicated worktree reproduced the September baseline: 217.8/133.6/133.3 ms
blast maximum gaps. Refresh cost 128.3/49.0/49.2 ms; carve/collapse 29.9/27.0/26.6
ms; collision publication 5.5–5.7 ms; launch 16.1–16.5 ms. The profiler now reports
stage costs and p99. GPU timers remain unavailable on Metal. Baseline CPU recipe
regressions passed (foundation 248.7/250.4 ms sync/worker, range 1355.2/1351.4 ms).

## Current dedicated implementation results

Recipe sampling now supports 1–8 independent contiguous partitions, each with
its own recipe/noise state and detached inputs. The helper joins its group before
publication and uses a mutex for shared result slots. Four workers is the current
default for large live recipes, capped at `max(1, logical CPUs - 2)` and eight;
small inputs stay on one worker. Synchronous loading/undo stays synchronous.

Three CPU trials per configuration, range plus float64 pond grid:

| Workers | Median completion ms | Main-loop maximum ms (range) |
| --- | ---: | ---: |
| 1 | 1434.6 | 10.34–10.42 |
| 2 | 1026.2 | 10.18–10.31 |
| 4 | 866.6 | 10.07–10.15 |
| 8 | 907.8 | 9.96–10.28 |

These are headless pure-data loop gaps, not GPU presentation measurements. Every
trial matched sequential height, gradient and water bytes exactly. Run the recipe
fixture with `-- --workers` to reproduce the sweep.

The native Open Meadow formation fixture accepts `-- --workers=N`. Local range
results (one run per setting, two for four workers):

| Workers | Completion ms | Maximum gap ms |
| --- | ---: | ---: |
| 1 | 816.4 | 22.1 |
| 2 | 621.6 | 31.8 |
| 4 | 528.6–534.7 | 20.4–31.4 |
| 8 | 547.8 | 30.1 |

The four-worker choice improves completion without a demonstrated frame-tail
penalty relative to two/eight. More repeated native runs and target Windows
hardware remain necessary for a portable tuning claim. All native runs preserved
mesh/map equivalence, edit exclusion and undo/redo. Foundation still failed the
50 ms assertion at every worker count: 62.5–81.9 ms maximum gaps. It is not fixed.
Refresh timers include cooperative waits (`*_elapsed`); they are not CPU totals.

Fixed topology face probes now prepare on a detached worker-owned terrain object
during live formation. Publication appends resolved triangles and float64 weights
without overwriting live cache indices. A differential fixture checks the exact
weights and cache preservation. This removed about 67 ms from the first native
blast: 150.9 ms versus 217.8 ms. Repeats stayed 133.6–133.9 ms. Collision, bodies,
visual geometry and simulation settings were unchanged. Destruction is still
synchronous and still fails the intermediate responsiveness target.

Recipe admission now permits one active task/group per terrain owner. Superseded
waiters return before pool submission; only the latest generation follows the
finite active job. Results are rejected on generation mismatch, including after
probe preparation. The group is bounded to eight partitions. Cleanup joins both
individual and group tasks; shutdown may wait for finite work. There is no global
cross-world admission limit, preemptive cancellation, or proven teardown stress
coverage yet. Navigation and physics query paths have not yet been ported.

Next implementation priorities are bounded destruction/refresh publication,
private mesh/map calculation, and a navigation snapshot whose clearance phase
keeps live physics queries on the main physics boundary. Do not interpret the
first-blast improvement as completion of the overall goal.

## Destruction and instance preparation (dedicated continuation)

Live remote detonation now computes ordered carve/collapse/rupture arithmetic on
one worker-owned terrain snapshot. It returns packed chunk arrays, terrain and
cover tables. Charge order and the relaxation pass order are unchanged; these
steps have data dependencies, so a 1/2/4/8 charge-level parallel sweep would change
the simulation. This workload intentionally uses one worker. Mesh, material,
body, collision and scene publication remain on the main thread.

Interactive edits are excluded with the existing formation transaction gate.
There is one in-flight blast per remote, with no queued repeated requests. A clear
or owner data replacement invalidates the generation; late results are discarded
and the finite worker is joined. Scene bodies remain owner children. Staged
bodies freeze until the transaction finishes, retaining their impulses for the
first eligible physics step. Ground collision refresh precedes their release.
Direct `detonate()` keeps the synchronous fallback; the interactive route uses
`detonate(true)` and completion is `requested == false && firing == false`.

Garden instance calculation also uses a detached terrain snapshot and private
catalog/pose/tint dictionaries. RNG order, transforms, source records and colors
are unchanged. Main-thread batch construction checks the 2 ms budget; hidden
staging nodes belong to the live view for teardown, and old visible batches stay
until the replacement set is ready. Source indices and batches swap together.
A generation check rejects superseded instance builds. The generic snapshot is
limited to triangle-ground/instance/blast queries; it is not a complete clone of
recipe, water, renderer or physics state.

The initial staged blast experiment reduced maximum gaps to 54–56 ms but fixed
per-frame body counts extended completion to about 620 ms. More detailed timers
then exposed a new GPU readback scheduling problem: uploading and immediately
reading each chunk mesh across many frames took roughly 456 ms. The engine's
[cleaned convex-shape operation](https://github.com/godotengine/godot/blob/4.7/scene/resources/mesh.cpp#L495-L529)
reads mesh vertex arrays before cleaning the hull. The adopted implementation
uploads the bounded chunk set together and then invokes that same engine method,
reducing this phase to about 12 ms. A proposed raw-vertex collider failed exact
hull equivalence and was removed; collider cleaning is preserved.

Latest fixed horn/alpine native trials (100 bodies):

| Trial | First effect observed ms | Complete ms | p95 ms | p99 ms | Max ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | 32.8 | 356.2 | 17.9 | 55.2 | 59.1 |
| 1 | 31.3 | 349.6 | 18.3 | 54.7 | 58.6 |
| 2 | 31.2 | 343.2 | 17.7 | 54.1 | 58.5 |

This is a frame-tail improvement over the inherited 133–218 ms stalls, with a
longer total completion time. Flash/dust begin during preparation. The largest
remaining gaps are in refresh and the first completed-world frame. Mesh work and
surface maps still use cooperative main-thread loops; their elapsed time includes
frame waits. The 50 ms intermediate target and 16.67 ms long-term target remain
unmet. A maximum of 48 mountain chunk resources is prepared for publication;
this batch took ~12 ms locally but is not a portable hard time bound. Terrain
changes and debris currently become visible during multiple refresh stages;
visual timing still needs a captured-frame review and tighter publication.

Validation added: `test_threaded_destruction.gd` compares surface, buried and
ordered salvo terrain/cover bytes, chunk mesh arrays and motion parameters with
the original sequential path. `test_threaded_instances.gd` compares complete
MultiMesh buffer bytes and source dictionaries across sequential and worker
paths. A run with `--reference=/tmp/zs-garden-view-before-threading.gd` additionally
matched the pre-change GardenView implementation exactly. The optional reference
file is a local audit artifact, not needed for normal test execution.

The native remote suite passes damage, collision, actual body motion, save/load,
undo/redo, expiration, repeated-request exclusion and clearing a pending worker.
The mountain-collapse suite passes four landscape families, volume conservation,
physical falling, pause, save/load and exact undo/redo. Further lifecycle stress,
legacy-scene coverage, navigation workers, mesh/map workers, first-use formation,
and Windows/quality-level coverage remain open.

Final continuation checks also pass Bigfoot explosion/recovery, eight landscape
families plus original-fidelity migration/fallback collision, native tunnels,
full incremental refresh, cleaned collider point bytes, and six-way instance
request supersession. Instance admission now coalesces requests to one active
worker per view; small gardens use synchronous calculation to avoid a worker
round trip. Final formation checks still pass all structural/undo assertions but
fail the foundation 50 ms gate: latest foundation 693.5 ms complete / 87.5 ms max,
range 548.4 ms complete / 20.1 ms max. These are separate native runs with first-use
variation, not proof of a foundation improvement. Next work should isolate those
first-use and refresh frame gaps before widening concurrency, while implementing
the still-missing navigation snapshot path.

## Navigation computation and publication

Live Fidelity and Bigfoot rebuilds now use contiguous grid partitions on private
terrain providers. Each provider owns its mutable triangle lookup cache. Imported
ground, water triangles and static solid bounds are copied before submission;
workers never query a Mesh, scene node or physics space. Only the explicitly
snapshotted Fidelity `clear_at` callback runs in a worker. Arbitrary clearance
callbacks and moving-body checks stay on the main thread, with a 2 ms validation
slice. Bigfoot advances this phase at its existing physics boundary, after the
replacement terrain collision is visible to physics.

The complete replacement node/index tables publish together. Route planning
remains suspended during rebuilding, and runtime motion checks still query live
ground and clearance. Repeated edits retain one active finite group per navigation
owner and replace only the pending generation. A late group joins and discards
its output before submitting the latest request. Synchronous `rebuild()` and
providers without `navigation_snapshot()` retain their previous API; a synchronous
request that supersedes a worker must wait for that finite worker to finish.

The shared helper now supports start/poll/finish as well as coroutine awaiting.
Input callable arrays are copied at submission, result writes are mutex-protected,
and every completed or abandoned task/group is joined. Early testing found that
a method Callable alone did not retain its scanner; submission now binds the
RefCounted scanner as an explicit argument. Teardown joins are inlined in
`NOTIFICATION_PREDELETE`, where calling another script method on the dying helper
is invalid. The navigation owner-drop regression passes without a leaked owner
or stale publication. Finite work is not preemptively canceled; shutdown can wait.

Native pond/stream/slope fixture, three trials per configuration:

| Workers | Median completion ms | Maximum validation/submit slice ms |
| --- | ---: | ---: |
| 1 | 158.1 | 2.024 |
| 2 | 91.4 | 2.019 |
| 4 | 58.1 | 2.018 |
| 8 | 58.1 | 2.022 |

The same warm cooperative fixture took 110.3 ms in this run (85.8 ms in the prior
run). Private worker lookup caches start cold, so one worker can be slower than
the cooperative baseline. This is native geometry without the full scene render;
its loop gaps are not gameplay FPS evidence.

The fully rendered Open Meadow fixture then measured the actual habitat refresh,
including setup, snapshot submission, worker polling and actor reconciliation.
Geometry refresh was excluded and scene simulation was manually controlled.
All three trials at each count matched the synchronous map exactly:

| Workers | Median completion ms | Maximum refresh slice ms | Maximum frame gap ms |
| --- | ---: | ---: | ---: |
| 1 | 181.3 | 1.657 | 16.297 |
| 2 | 112.5 | 1.881 | 14.229 |
| 4 | 83.8 | 2.238 | 14.376 |
| 8 | 70.3 | 3.344 | 15.184 |

Four is the default, capped by `min(8, max(1, processor_count - 2))`. Eight saves
about one displayed frame in this scene but doubles snapshot submission from
roughly 1.4–1.6 ms to 2.5–2.8 ms and provides no gain in the simpler native fixture.
Snapshot construction and a single clearance callback are not preemptible; the
2 ms slice is a checkpoint target, not a portable hard deadline. Twelve immediate
live edits also pass exact latest-map and actor suspension checks, with a largest
setup/update call of 35.1 ms. First-use preparation remains outside the warm
benchmark result.

Validation: `test_threaded_navigation.gd` passes byte-identical nodes and indices
at 1/2/4/8 workers, real physics clearance, imported Fidelity water/solids, eight
superseding edits with no queued groups, main-thread callback assertions and owner
destruction. `test_live_edit_navigation.gd`, `test_creature_navigation.gd`, and
the generic cooperative `test_navigation_budget.gd` pass. Shared-helper regression
runs of threaded recipe, instances and destruction pass. The full Bigfoot blast
suite also passes flight, pause, habitat rebuilding, recovery, undo, off-island
respawn and held-actor behavior with worker navigation enabled.

Per-owner queues are bounded, but multiple concurrently active worlds still have
no global admission limit. Cross-world stress, mesh/map computation, first-use
formation stalls, final destruction publication/visual timing, and Windows and
quality-level coverage remain open. These navigation results do not satisfy the
overall formation/destruction frame-time acceptance gate.

## Surface-map row workers and formation timing isolation

Large live surface-map updates now rasterize disjoint row stripes on workers.
Each partition owns a height-only terrain snapshot, CPU Images, pond vertices,
and imported stream triangle samplers. Stream Mesh/Node reads happen before
submission on the main thread; texture updates happen only after all stripes
join and merge. Original pixel expressions, triangle order, image formats and
stream channels are unchanged. The retained sequential loops are the independent
reference used by the differential fixture. Patches smaller than 256 pixels
finish synchronously without yielding while mutating the live map cache.

Snapshot construction initially copied thousands of irrelevant object records;
a dedicated height-only snapshot reduced four-worker submission from 8–9 ms to
about 1 ms. Sources and outputs are private CPU Images. An editor permits one
active map group, coalesces newer live requests, and rejects old results after a
new synchronous refresh or data replacement. Stale tasks still finish and join.
The worker helper and snapshot data do not retain the scene owner.

Final native-water fixture, with the populated scene rendering and three trials:

| Workers | Median completion ms | Maximum submission ms | Maximum frame gap ms |
| --- | ---: | ---: | ---: |
| 1 | 94.3 | 0.366 | 20.923 |
| 2 | 75.8 | 0.576 | 21.717 |
| 4 | 58.6 | 1.024 | 22.407 |
| 8 | 58.9 | 1.849 | 23.385 |

Four is the default under the same hardware cap as recipe/navigation work. Eight
has no useful completion gain. The imported unchanged-ground case is only about
1 ms of single-worker pixel computation; more workers increase overhead, so this
case is not a scaling win. Warm-scene fixture timings include presentation and
texture publication; the populated world's 21–23 ms frame gaps are not all CPU
map work and still exceed the long-term 16.67 ms target.

`test_threaded_surface_maps.gd` passes exact base/ground/stream bytes for imported
terrain and the populated native pond/stream world at 1/2/4/8 workers, incremental
stripe/full repaint equivalence, six superseding live requests plus synchronous
replacement, and destruction of a scene with a map job pending. The existing
`test_native_refresh_incremental.gd` again passes all terrain, paint, prop, water
removal/movement and undo/redo checks after the stream sampler extraction.

Formation profiling now records frame phases and supports `--warm-scene` to
advance rendering **and normal simulation** for 60 frames before the first
formation. Rendering alone did not eliminate the initial spike: foundation still
hit 57.2 ms. Warming both produced 16.9 ms maximum before the map change. This
isolates a first-simulation/startup contribution without declaring it fixed; the
default cold test and its 50 ms assertion remain intact.

With workers for surface maps, the warmed formation test passes every structural,
exact-output, animation and undo/redo assertion:

| Action | Before map workers: complete / max ms | After: complete / max ms |
| --- | ---: | ---: |
| Foundation | 607.2 / 16.9 | 290.8 / 16.2 |
| Range | 547.5 / 20.2 | 528.9 / 19.9 |

Foundation's map phase fell from 341.2 ms to 32.2 ms. These are paired local runs
with normal variation, not a cross-hardware guarantee. Mesh shading arithmetic
remains on the main thread with checkpoints. Whole-world publication still spans
terrain, instances, surface maps and collision phases; captured-frame visual
acceptance and global cross-world admission remain unfinished.

The subsequent fixed native blast run (100 bodies) measured completion of
370.7 / 346.9 / 344.5 ms, first effects at 30.9 / 32.0 / 31.3 ms, p95 gaps of
17.8 / 18.3 / 19.5 ms and maximum gaps of 53.8 / 54.2 / 53.5 ms. p99 gaps were
51.8 / 51.5 / 51.2 ms. Surface-map publication now takes roughly 40 ms elapsed,
with ~1 ms snapshot submission, but the largest refresh/first-completed-world
gaps remain above 50 ms. The map change is a clear first-foundation completion
win, not a demonstrated blast completion win.

Map publication also compares captured heights, blank-state and water revision
against the live owner after joining. A direct terrain mutation without a newer
map request rejects both old pixels and old cache metadata; its regression passes.

The final default (cold) formation run still fails only the foundation timing
assertion: foundation 292.5 ms complete / 75.5 ms max; range 544.1 ms / 15.9 ms.
The first manually driven scene simulation call costs 41.4 ms, contributing to
the following 75.5 ms frame interval. This confirms a substantial startup
simulation cost, while leaving the remaining render/presentation contribution
unattributed. Exact mesh/maps, actor/world progress and undo/redo still pass.
The native explosives suite also passes after map integration, including real
debris motion, crater collision, save/load, exact undo/redo, repeated-request
exclusion, pending-job cancellation and world replacement.

Next measured targets: isolate that first simulation call; move remaining mesh
arithmetic and water/content work off the main thread where ownership permits;
capture the terrain/debris transition and narrow whole-world publication; audit
cross-world admission and teardown under simultaneous owners. Windows and quality
levels remain unverified and must not inherit these Mac acceptance claims.

## Mesh workers and reflection/publication diagnosis

Live mesh updates now use a finite pipeline per terrain owner. A detached provider
computes the ordered shoreline flood/distance field on one worker; independent
face shading then runs in contiguous partitions with private providers and output
buffers. Heights, normals, authored colors, sculpt gradients, snow, shore tint,
UV2 and custom channels retain the sequential arithmetic and precision. Only the
merged arrays reach `ArrayMesh` creation on the main thread. Small direct/synchronous
edits retain the original builder as the independent reference.

Generation changes and direct input changes reject late results, including cache
metadata. A new synchronous build supersedes pending live builds. The editor
checks the returned mesh and terrain owner before assignment. One active pipeline
per owner coalesces later requests; every finite stage joins. Fixed topology probe
preparation still appends resolved weights without replacing live cache indices.

`test_threaded_mesh.gd` passes exact mesh array bytes, source format/material,
shoreline/mask bytes, incremental/full equivalence, seven superseding requests and
direct mutation rejection. Its heavier sculpted alpine-water fixture measured:

| Shading workers | Median complete ms | Median summed shading CPU ms |
| --- | ---: | ---: |
| 1 | 42.0 | 8.4 |
| 2 | 33.1 | 11.9 |
| 4 | 33.1 | 15.4 |
| 8 | 33.4 | 16.4 |

The ordered preparation stage is about 21 ms in every configuration. Two is the
default under the existing hardware cap; more workers do not shorten completion
and increase total CPU work. Imported-cover and foundation shading are only
3–4 ms on one worker and do not show a useful multiworker completion win. This
fixture uses native geometry but does not render the complete game.

In the real blast scene, mesh elapsed time fell from 93–104 ms to 49–52 ms. Initial
snapshot submission took about 0.35 ms, shading snapshots about 0.5–0.6 ms,
merging below 0.14 ms and mesh publication about 0.15–0.25 ms. Blast completion
fell to 302–318 ms, but the 54 ms maximum frame remained. More detailed water
timers showed only ~1.6 ms for streams and ~6.7 ms for pond sampling, so moving
those stages would not explain or solve that frame.

A temporary scene-process trace identified planar reflection synchronization at
39–53 ms. The temporary instrumentation was removed after the run. Water geometry
revisions discarded identical clipping shaders and compiled them again. Reflection
refresh now retains compiled shaders for unchanged source shaders and pond levels,
recompiles if source code changes, and prunes every unused cache entry. It does not
change reflection resolution, MSAA, clip planes, geometry or water materials.

The playable-visual regression passes three reflected pond levels, transforms,
visibility, material edits, shader identity across full water refresh, save/load,
landscape switching, growth controls and cache release when ponds disappear. Its
fixture now waits for asynchronous Diorama setup and refreshes its material
reference after its explicit disable/enable capture step. Rendered terrace and
reflection images are available in `/private/tmp/zs-playable-enhanced.png` and
`/private/tmp/zs-playable-reflection.png`; these verify the reflection scene, not
the temporal terrain/debris transition.

Retaining reflection shaders removed the large refresh-frame spike, leaving a
final frame that accumulated post-map publication, collision and chunk resources.
Publication checkpoints now separate those phases; the resident kick follows
resource preparation and staged debris stays frozen until completion. The first
two-checkpoint experiment measured blast maxima of 38.1 / 38.7 / 39.2 ms with
completion 315.7 / 318.9 / 319.8 ms. Its p95 rose to about 24 ms as the work was
spread across more frames. A further checkpoint now separates collision from
resource upload; final validation follows below. The 16.67 ms goal is still open.

Final three-checkpoint blast measurements, 100 bodies in every trial:

| Trial | First effect ms | Complete ms | p95 ms | p99 ms | Maximum ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | 31.1 | 336.8 | 26.7 | 32.6 | 37.2 |
| 1 | 31.3 | 341.3 | 25.6 | 31.3 | 32.1 |
| 2 | 31.4 | 341.7 | 24.7 | 31.4 | 32.0 |

All three meet the local 50 ms intermediate frame-tail gate. This is a reduction
from the inherited 133–218 ms stalls and this continuation's 54 ms starting point,
with longer completion than the original synchronous blast. The lower observed maximum
costs more frames above the idle interval; p95 is not a blanket improvement.
Separating render/resource phases also increases observed convex-resource work
from ~12 ms to ~27 ms through readback scheduling. That engine call remains a
finite unsliced batch and a limit on reaching a 16.67 ms target.

The native explosives suite passes after final publication ordering, now checking
actual debris displacement after the next eligible physics boundary. Its old
immediate velocity assertion depended on whether a physics tick happened between
coroutine completion and the process-frame observation. The Bigfoot blast suite
also passes launch, pause, airborne habitat rebuilding, landing/recovery, exact
undo, off-island recovery and held/distant actors.

Final mesh cleanup removes even the shared read-only recipe reference from face
jobs; only an explicit recipe-presence boolean is passed. A dry/no-recipe mesh
skips the empty shoreline task entirely. Final 1/2/4/8 differential mesh checks
still pass, including shoreline bytes and stale-result/cache rejection.

Final warmed formation passes all checks at foundation 306.1 ms complete /
16.5 ms max and range 546.0 ms / 20.1 ms. Compared with the surface-map-only
continuation, the multi-stage mesh pipeline adds about one displayed frame to
these lighter operations; its demonstrated benefit is the heavier sculpted blast
mesh. Empty shoreline work is skipped, but existing pond/stream records still
require their preparation even when a newly formed surface leaves them dry.

The final default cold run still fails the startup frame gate: foundation
315.8 ms complete / 78.2 ms max, with 41.2 ms in its first scene simulation call;
range is 542.5 ms / 18.4 ms. All exact-output, animation and undo assertions pass.
Retaining shaders fixes recompilation on later geometry revisions, not their
initial creation. Initial reflection/material setup, temporal blast capture and
whole-world publication, and multi-owner queue/teardown stress remain open.
The current changes therefore satisfy the measured warm native blast intermediate
gate, not the complete goal or a portable 60 Hz guarantee.

## Overlapping owners and temporal debris publication

`BackgroundWork.statistics()` now reports submitted jobs and partitions awaiting
their joins, plus their high-water marks. These are ownership diagnostics, not
counts of executing CPU threads. Both ordinary completion and PREDELETE decrement
the counters after joining; destruction keeps the engine waits and accounting
inline to avoid calling methods on a dying script instance.

The native lifecycle fixture starts four recipe owners, four mesh owners and four
navigators, then issues seven requests per owner without yielding between burst
replacements. The 84 requests peak at 12 submitted jobs / 40 partitions. Replacing
pending generations does not grow those counts. All final recipe tables, mesh
arrays and navigation nodes/indices match the sequential results exactly; the
overlap completes in 1,066.7 ms and drains to zero jobs and partitions. Scene
deletion during recipe, mesh and map preparation also releases the scene/editor
immediately, then releases retained terrain inputs when the finite tasks join.
Dropping a navigator exercises immediate RefCounted teardown separately.

This establishes bounded submission per owner for the tested overlap. It does
not introduce a global admission limit: creating additional independent owners
can still increase submitted partitions, while the engine pool bounds executing
threads. The current defaults remain four recipe/navigation/map partitions and
two mesh shading partitions, individually capped to available hardware. A global
queue policy remains a requirement before scaling to arbitrarily many worlds.

`tools/profile_explosions.gd -- --capture` now saves rendered stage images and a
JSON timeline under `/private/tmp/zs-blast-transition`. This mode is separate from
timing runs: image readback and PNG encoding materially inflate elapsed time.
The initial capture exposed a real visual discontinuity: the damaged terrain
appeared at rendered frame 4, but debris did not appear until frame 11. The
mountain cap disappeared and was subsequently reconstructed by its frozen chunks.
Those initial images remain in `/private/tmp/zs-blast-transition-before-staging`.

Destruction now prepares hidden, frozen bodies before refreshing terrain. A small
main-thread publication hook in `NativeChunkEditor.refresh` reveals mountain
chunks at the terrain mesh swap, ordinary props at the content swap, and landmark
props at the landmark swap, before the corresponding stage yields. Collision
layers/masks remain zero throughout staging. After refreshed ground collision is
ready, the transaction completes and the next eligible physics tick enables body
collision and applies the stored impulses/velocities.

The corrected rendered capture shows all 32 mountain chunks in the first frame
with replaced terrain; all 100 bodies exist beforehand but are hidden. Scenery
copies appear with their source replacements. No body moves before collision
publication. The native explosives regression additionally checks this visibility
boundary, collision exclusion during staging, actual displacement after release,
crater collision, cancellation and exact undo/redo.

Correcting the visual gap costs more than the earlier visually inconsistent
32–37 ms maximum. The first reordered run had maxima 50.9 / 44.1 / 46.2 ms.
Separating scenery capture from resource upload with a publication checkpoint
then measured the following (100 bodies in every trial):

| Trial | First effect ms | Complete ms | p95 ms | p99 ms | Maximum ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | 31.8 | 394.7 | 27.3 | 32.3 | 48.4 |
| 1 | 31.2 | 386.3 | 26.5 | 31.8 | 44.4 |
| 2 | 31.2 | 385.4 | 26.0 | 32.4 | 44.9 |

The corrected visual sequence still meets the local 50 ms intermediate gate in
these three trials. It does not meet 16.67 ms. Chunk-resource calls remain about
27 ms, and the largest remaining displayed gap occurs during refresh. Cold
initialization remains open; the previous 78.2 ms cold foundation result has not
been fixed by this change. Mesh, water and collision still publish in ordered
stages rather than a whole-world atomic swap, although disappearing debris is now
paired with the visual source that replaces it.

Final validation after the publication changes passes both native explosives and
Bigfoot explosions, including pause, landing/recovery, held/distant actors and
exact undo. The expanded lifecycle fixture also deletes a scene with blast bodies
already staged and a terrain worker pending: the editor and bodies are destroyed,
the finite task joins, and terrain inputs are released. Its final overlap run
completes in 1,099.2 ms with the same 12-job / 40-partition peak and zero remaining
jobs after every teardown. `git diff --check` passes.

## Budgeted initial reflections and cold formation

The next cold trace measured 32.3 ms in initial planar-reflection synchronization,
out of a 45.4 ms first scene update; the following displayed interval was 73.8 ms.
More detailed tracing found only 0.8 ms in reflected pool geometry, but 22.4 ms in
copying the reflected scene, including 6.2 / 5.1 ms when assigning its two newly
generated clipping shaders. The temporary traces were removed.

Initial live reflection setup now starts on the following process frame and
traverses geometry with the existing 2 ms cooperative budget. Individual engine
calls remain indivisible. Reflection viewports stay disabled and reflected pool
surfaces stay hidden until every level is prepared. The original water material
continues drawing during that short startup interval. Completed setup publishes
the same pool meshes, clipping code, materials, MSAA, resolution and view cameras.
Warm revision changes continue to reuse compiled shaders synchronously.

The optional frame-tree argument is used by the live scene. Explicit synchronous
callers retain immediate setup and can supersede an unfinished live setup. A
generation rejects cancelled continuations before they can clear a newer result;
`clear()` now invalidates both revision fields. Source content/object revisions
are rechecked after yields. Traversal skips freed source nodes, and setup never
accepts water geometry that disappeared while it was waiting.

The native playable-visual suite passes initial staging visibility, byte-exact
pool geometry against synchronous setup, three-level publication, cancellation
after resource creation, synchronous supersession, material/transform/visibility
updates, save/load, growth, landscape changes and cache cleanup. Final terrace
and reflected-view captures were inspected at `/private/tmp/zs-playable-enhanced.png`
and `/private/tmp/zs-playable-reflection.png`. The lifecycle fixture additionally
replaces source batches during preparation and deletes the owning scene while a
new setup is pending. These checks pass with a real native pond; no worker jobs
or terrain inputs remain after teardown.

Scene-cold formation results with the retained process-frame staging:

| Run | Foundation complete ms | Foundation max ms | Range complete ms | Range max ms |
| --- | ---: | ---: | ---: | ---: |
| Initial | 312.0 | 39.2 | 545.1 | 16.9 |
| Repeat 1 | 329.7 | 42.1 | 556.5 | 17.3 |
| Repeat 2 | 299.3 | 50.4 | 522.2 | 11.0 |

Exact mesh/map output, animation progress and undo/redo pass in every run. The
first scene update falls to 12.7–16.8 ms. The strict 50 ms cold gate is **not yet
consistently satisfied**: the third run narrowly fails. These are scene-cold runs
with the existing Godot shader cache, not clean-install shader-cache measurements.

Two experiments were removed. Adding clipping controls to main scene shaders
reduced CPU setup but still produced a 61.8 ms scene-cold interval after a much
slower first shader-compilation run, and changed the main rendering path. Waiting
for the initial draw before preparation measured 46.2 / 52.9 / 61.4 ms maxima,
which did not improve the retained scheduling and introduced a render-signal
dependency. Shader files are unchanged, and the retained implementation waits
only on process frames. Cold presentation/engine scheduling and remaining warm
refresh costs still need investigation; none of these results establishes 60 Hz
acceptance or Windows/other-quality performance.

The final warmed blast recheck retains 100 bodies per trial and measures maxima
45.2 / 44.7 / 45.2 ms, with completion 381.3 / 385.5 / 373.0 ms and p95
27.6 / 27.0 / 27.4 ms. Thus the initial-reflection staging preserves the warm
blast intermediate gate. The final lifecycle run passes all five teardown phases
(recipe, mesh, maps, staged blast and reflections), including replacement of
reflection source batches while preparation is pending. The cold gate remains
the documented partial result above.

## Desert geology joins recipe preparation

An audit of remaining terrain consumers found another main-thread computation:
the 128x128 desert rock/salt mask in `WorldVisuals.sync`. A native regression that
prepares a salt-basin recipe through `_set_recipe(..., tree)` and then advances
the real scene reproduced a 299.4 ms update. The minimized trace attributes
295.1 ms to mask sampling and 0.15 ms to texture upload. This was independent of
the cold reflection issue. The temporary trace was removed.

Geology rows now run inside the existing recipe partitions. Each partition owns
its recipe/genome and a disjoint CPU image stripe; after the group joins, the main
thread blits those stripes into one image. `NativeTerrainData` publishes the image
and its settings signature alongside the matching recipe, heights, gradients and
water table. The scene only uploads the prepared image. No extra pool group or
per-world request queue is introduced. Small terrain providers still select
parallel preparation because the geology workload itself contains 16,384 pixels.

The scene-update regression falls from about 299 ms to 3.3 ms. All seven desert
families produce byte-identical RGBA8 pixels against the retained original
`WorldVisuals` loop at 1/2/4/8 workers. Three-trial median map-preparation latency
in the rendered native fixture is:

| Family | 1 worker ms | 2 workers ms | 4 workers ms | 8 workers ms |
| --- | ---: | ---: | ---: | ---: |
| Desert | 188.4 | 152.9 | 118.0 | 118.0 |
| Dunes | 189.3 | 153.7 | 106.4 | 117.9 |
| Tablelands | 223.7 | 199.8 | 141.0 | 141.7 |
| Buttes | 318.5 | 271.4 | 188.7 | 188.8 |
| Monuments | 223.4 | 164.9 | 117.8 | 118.0 |
| Salt basin | 307.2 | 247.8 | 177.4 | 177.0 |
| Desert mountains | 189.4 | 153.5 | 117.8 | 117.8 |

Four remains the default recipe concurrency, capped to available hardware. Eight
does not provide a useful additional reduction, while summed worker CPU cost
increases. The four-worker map sweeps have a maximum measured frame gap of 12.2 ms.
These figures isolate map computation with native rendering; they do not claim
that a full inland formation completes in those times.

The new regression also proves that a newer ordinary recipe discards pending
desert images, seven queued requests publish only the latest generation, and
live/synchronous preparation agree. Undo restores the exact document and map;
redo releases the desert map, and the scene clears its texture state. The map is
derived data, not a new save-file field. A completed map occupies 65,536 CPU bytes;
all worker stripes together occupy the same amount during preparation, followed
by a temporary merged image. The existing per-owner admission and finite joins
cover this work as well.

Cached images carry their recipe-settings signature, so direct replacement of a
recipe cannot reuse a map from different settings. Hand-constructed providers
without a matching prepared image retain the original synchronous fallback. The
canonical native recipe path supplies the image before scene publication.
Offline loading/undo retain synchronous computation; moving that work into recipe
preparation is not a claim that those APIs are now asynchronous.

The existing CPU recipe suite passes after the extension. Native world integration
also passes formation, sculpt edits, extra object placement, save/load and saved
atmosphere settings for massif, valley and salt-basin landscapes. This removes a
separate measured 300 ms live scene stall; the remaining cold presentation limit
and broader platform/quality acceptance described above are still open.

## Instance publication ownership audit

A native regression exposed a gap in instance cancellation: changing object
records, heights, blades, meadow density or the data provider while a worker was
pending still allowed its old result to publish. A direct object edit could also
leave the next ordinary rebuild reusing stale buffers. The initial regression
reported six failures. After adding input validation, a remaining failure showed
that synchronous builds had retained live object dictionaries in visible source
records, allowing those records to change independently of their transforms.

Instance preparation now validates the provider, sampled terrain/cover/object
inputs, catalog metadata and native environment signature before GPU staging and
again before publication. The environment check prevents an object-only rebuild
from marking newly changed water or cover state as already rendered. Rejection
preserves visible batches and cache signatures, and invalidates the cache so an
ordinary rebuild repairs the current state. Source object dictionaries are
detached in synchronous builds and object previews as well as worker builds.

Every rebuild request, including a cache hit or in-place lift, supersedes older
preparation. Provider replacement, cache invalidation and object previews also
cancel it. Superseded GPU staging releases its temporary nodes at the next budget
checkpoint. Small native gardens and generic gardens still calculate on the main
thread, but use private inputs whenever GPU publication is allowed to yield.
There is no new worker group or admission queue.

The expanded native instance suite checks direct mutation during sampling,
mutation during hidden GPU staging, provider and tint replacement, cache-hit and
preview supersession, repair by an ordinary rebuild, and cache publication across
an object/environment change. Generic garden staging also preserves exact
buffers and rejects a mutation. Complete buffers and source bytes still match
the original pre-threading renderer. Native selection passes picking, preview,
undo and save checks after source detachment.

The lifecycle suite now tears down a scene during instance preparation too.
All six scene phases (recipe, mesh, maps, instances, blast and reflections) release
their terrain inputs and drain submitted jobs and partitions to zero. The
overlapping-owner fixture remains at 12 peak submitted jobs / 40 partitions and
completes in about 1.06 seconds in this run. Those counters describe work awaiting
join, not simultaneous CPU execution. This closes the audited instance ownership
gap; it does not change the documented cold-frame or global admission limits.

## Refresh completion and debris release

The next ownership regression found a caller-level gap: after `GardenView`
rejected changed inputs, `NativeChunkEditor.refresh` still announced content and
landmark publication. A native test reproduced that false event before the fix.
`GardenView.rebuild`, surface-map updating and editor refresh now return explicit
success. Rejected stages stop the refresh before their publication hook or later
scene updates. A newer refresh invalidates older instance/map work immediately,
and a refresh generation plus detached document inputs are checked across stage
boundaries. An old continuation cannot overwrite a newer refresh's completion
status or keep updating its scene.

Refresh remains staged: terrain or other earlier stages can already be visible
when a later stage rejects. A blast therefore keeps its bodies staged and retries
a rejected refresh before rebuilding collision or releasing physics. Cancellation
or provider replacement is checked before another retry. This reuses the same
finite worker and per-owner admission paths, rather than accumulating retry jobs.

`test_threaded_refresh.gd` checks rejected content and maps, ordered publication
hooks, ordinary repair and synchronous supersession. It also deliberately rejects
a blast's content stage: debris stays frozen with zero collision masks throughout
the retry, enters physics only after successful publication, and undo restores
the exact pre-blast document. The six-phase lifecycle suite still drains every
job and releases the original terrain inputs after scene deletion.

A separate boundary check changes an object inside the content publication hook.
Refresh rejects the remaining stages and invalidates the content cache, including
for direct edits that do not bump object revisions, so the next ordinary refresh
repairs it. The established native explosion suite also passes placement,
camouflage, save/load, exact crater collision, actual debris motion, visual-source
timing, undo/redo, input exclusion and cancellation with the completion guards.

Three native warm-blast benchmark trials retain 100 bodies each and measure
maximum frame gaps of 44.9 / 44.6 / 44.9 ms, with completion times of
393.5 / 370.0 / 375.6 ms. Refresh input snapshots cost about 0.08 ms per trial;
all boundary comparisons together cost 0.38–0.46 ms. These measurements preserve
the warm 50 ms intermediate gate and do not establish the 16.67 ms quality target.
The largest warm gap remains in refresh; cold presentation and global admission
limits remain as described above.

## Cold initialization and per-recipe concurrency

Fresh native formation runs confirmed that the remaining cold gaps occur before
terrain publication. A temporary first-scene trace attributed about 10 ms to
ambient audio. A narrower trace found 5.6 ms fetching the freshly uploaded pond
mesh's vertices and only 0.02 ms choosing the nearest emitter position. The pond
builder already retains the exact CPU vertices, so water audio now uses those
instead of reading the GPU buffer. The isolated initial lookup falls from
0.92 ms to 0.04 ms; the larger in-scene readback depends on renderer scheduling.
First-scene CPU time falls to roughly 6–8 ms in subsequent runs. All temporary
traces were removed.

`test_water_audio_positions.gd` compares every cached vertex and its order with
the published mesh, then verifies exact nearest emitters across camera movement,
water transforms and content rebuilding. Obsolete cache entries are released.
The existing ambient suite passes imported/authored emitters, deleting water,
pause, mute and mix behavior. Audio remains synchronous; this tiny nearest-point
calculation does not justify another worker job. Rendering quality is unchanged.

The readback fix alone did not close the cold gate: a four-worker run still
reached 62.1 ms. Alternating cold one- and four-worker runs then isolated a useful
concurrency tradeoff. Three one-worker foundation runs peaked at 37.0 / 39.3 /
42.0 ms, completing in 342.1 / 339.3 / 346.6 ms. Three four-worker runs peaked at
62.1 / 73.0 / 43.5 ms, completing in 354.4 / 311.6 / 300.6 ms. Meanwhile, range
formation took roughly 813–825 ms with one worker versus 532–562 ms with four.
This supports preserving startup headroom for the simpler foundation recipe
while retaining parallel sampling for expensive terrain.

The automatic recipe setting is now zero: it selects one worker for foundation
and up to four for other recipes, still capped by available CPUs minus two and
the existing eight-worker maximum. Positive `recipe_workers` values remain
explicit overrides for 1/2/4/8 experiments. `last_recipe_workers` records the
concurrency of a successfully published recipe (zero for synchronous work).
This supersedes the earlier blanket four-worker default in this history.

Three final native runs with automatic concurrency and production reflections
enabled pass the cold 50 ms gate and all exact mesh/map, animation, edit-exclusion
and undo/redo checks:

| Trial | Foundation complete ms | Foundation max gap ms | Range complete ms | Range max gap ms |
| --- | ---: | ---: | ---: | ---: |
| 1 | 346.3 | 39.6 | 540.6 | 32.4 |
| 2 | 314.8 | 43.0 | 520.0 | 14.5 |
| 3 | 343.8 | 43.5 | 540.9 | 29.3 |

These are scene-cold runs with the existing Godot shader cache on the same Mac.
They establish the local intermediate gate for this fixture; they do not prove
16.67 ms presentation, fresh-install shader compilation, quality-mode coverage
or Windows behavior. A diagnostic run with reflections disabled helped attribute
startup cost, but no production reflection setting was changed.

## Inherited scene and frame-wait ownership

The broader sculpt audit exposed shutdown warnings that the Fidelity-only
lifecycle fixtures did not cover. An idle Bigfoot Life scene reproduced them
with zero outstanding jobs: 36 ObjectDB instances and associated GPU resources.
Verbose orphan reporting identified planar water, world visuals, redwood mist,
leaf litter and waterfall drips. Inherited PackedScenes replace the base script
during instantiation, abandoning Node objects allocated by its member initializers.
Fidelity now constructs these five helpers in `_ready()`, before their existing
setup/parenting sequence. Base-scene disposal before tree entry and inherited
Bigfoot Life/Open Meadow teardown leave no orphan nodes.

Early scene deletion also exposed a suspended `FrameWorkBudget.checkpoint` on a
freed helper, followed by a reflection traversal attempting to resume on its
freed node. Checkpoints now return a signal, using a one-shot callback to retain
only the budget until its clock resets. An optional signal source allows planar
setup to await its own node's frame signal rather than the longer-lived tree.
Deleting the node discards pending reflection waits. The regression checks both
abandoned-budget ownership and the fresh budget after a yielded frame.

Native inherited-scene, playable-reflection, refresh-retry and six-phase worker
lifecycle tests pass without errors. A repeat of the original 30-dab Bigfoot Life
sculpt fixture also exits without the prior leak/coroutine warnings. Its timing
is still poor: at 3024×1898 the maximum gap is 94.0 ms and p95 72.5 ms; refresh
peaks at 46.8 ms and collision callbacks at 22.8 ms. This resolves the reproduced
ownership defects but leaves the combined sculpt/physics/render stall open.

## CPU collider geometry and first GDExtension experiment

User direction broadens the working objective to multicore CPUs and mainstream
GPUs. Windows testing is no longer a prerequisite for the next optimization;
Mac/Metal remains the available measurement environment. No portable FPS claim
is made. The updated acceptance record has the current sequence and results.

The remaining frame-budget failure was a test-observation error. A minimal native
probe saw process-frame signal counts advance 0→1 while the engine frame counter
remained 0→0. The checkpoint waited and reset correctly. The regression now counts
signals and verifies a fresh slice, while retaining inherited-scene lifetime and
abandoned-budget ownership checks. Native run: `/tmp/zs-lifecycle-signal-count.log`,
zero failures and no teardown warnings.

The sculpt harness used to request its size before Fidelity startup maximized
the window. It now applies windowed mode/size after startup and verifies the
physical viewport after warmup. It records p99, frames over 16.67 ms, actual
editor refresh stages, and collision substage timings. The controlled baseline
at 1440×900 is `/tmp/zs-sculpt-collider-before.json`: maximum 82.192 ms,
p95 67.186 ms. This is a new baseline, not an equivalent-resolution comparison
to the older 94 ms full-window result.

`NativeTerrainData.play_collision_faces()` retains CPU geometry and reproduces
Godot 4.7's `TriangleMesh::create` 0.0001 vertex snapping. It avoids fresh renderer
readback and the redundant triangle-mesh BVH needed by `create_trimesh_shape()`.
Tunnel clipping keeps its existing cached faces. Returned arrays are duplicated
so caller mutation cannot damage either cache; the new test caught this aliasing
before the final implementation. `NativePlayCollisions` sets those exact faces
on a ConcavePolygonShape3D. Median collision preparation is now about 0.285 ms
for CPU faces plus 1.066 ms for physics shape setup, versus 14.718 ms for the old
shape path. Whole-frame sculpt maximum falls to 67.115 ms, p95 56.923 ms in
`/tmp/zs-sculpt-collider-after.json`. Thirty frames still exceed 33 ms.

For blast hulls, further instrumentation separated mesh upload (~0.35 ms), all
hulls (~23.2 ms), and the slowest hull (~12.8 ms). A private `Mesh` subclass supplies
CPU vertices directly to the engine's existing `create_convex_shape(true,false)`.
It never renders or uploads data, and physics-resource creation remains on main.
This avoids replacing the hull algorithm or relaxing exact-point tests. The
surface/buried/salvo differential suite passes; all hull work now totals
1.1–1.3 ms. `/tmp/zs-blast-collider-stages.log` and
`/tmp/zs-blast-cpu-hulls-after.log` contain the paired three-trial traces.
Blast completion improves, while the largest frame remains in refresh (~45–47 ms).
Native tunnel, explosive and Bigfoot explosive integration suites pass, including
actual movement, grounded collision, pause, undo, redo and abandonment.

The optional C++ GDExtension lives in `native/terrain_kernels`. The build helper
uses the installed editor's dumped API and an external official godot-cpp
checkout; README records the revision, dependencies, commands and untested
platform/export limits. Generated API files, libraries and extension descriptors
are local ignored build outputs. `--native-kernels` opts into the experiment;
ordinary runs preserve GDScript. Scalar double / Vector and Color float operation
ordering is retained, with compiler floating-point contraction disabled.

One-worker median shading work from isolated three-trial CPU sweeps:

| Fixture | GDScript ms | C++ ms |
| --- | ---: | ---: |
| Imported terrain with cover | 3.046 | 0.309 |
| Foundation with tint | 3.459 | 0.287 |
| Sculpted alpine with water | 8.504 | 0.464 |

Logs: `/tmp/zs-mesh-gdscript-isolated.log`, `/tmp/zs-native-mesh-sync.log`.
These are kernel work timings, not whole-game speedups. Both backends passed
exact mesh comparisons for synchronous builds, 1/2/4/8 workers, incremental
updates and stale requests. Automatic native dispatch shades up to 8,192 faces
inline (~0.5 ms in the rendered fixture), avoiding a worker/frame round trip;
larger meshes retain workers and explicit positive counts remain available.
Automatic GDScript dispatch still uses two workers. Native mesh and refresh
regressions pass with the reference explicitly forced to GDScript.

Isolated native automatic blast validation at 1440×900:
`/tmp/zs-blast-native-auto-isolated.log`: completion 299.716 / 269.782 / 298.880 ms,
maximum frames 46.688 / 44.955 / 45.458 ms; p95 23.117 / 21.282 / 22.308 ms.
Mesh-stage elapsed time is ~26 ms instead of ~38 ms, but other refresh work still
determines the maximum. Small-brush sculpt with native shading still peaks at
67.239 ms (p95 57.560); its mesh stage is already only 0.82 ms median.
`/tmp/zs-sculpt-native-stages.json` identifies remaining stage medians of anchors
8.89 ms, content 7.05 ms, landmarks 5.99 ms (maximum 15.81 ms), surface maps
1.13 ms and post-map work 1.82 ms. Those are the next investigation targets.
The 16.67 ms target, cold Beauty initialization and global multi-owner admission
remain open. No commits or pushes were made.

Final native lifecycle run `/tmp/zs-lifecycle-native-final.log` passes all six
teardown phases and the four-owner/seven-request overlap stress: jobs and
partitions drain to zero in 1.036 s. The test explicitly requests two mesh workers
for pending-job coverage; debris and reflection staging need not have a worker
pending once computation has joined. Frozen staged-body and owner-release checks
remain in place. The native experiment therefore preserves both pending-job and
pending-publication teardown coverage. `git diff --check` passes.

## Default native selection and PR readiness

User approved enabling beneficial native work by default. The loader now selects
built mesh kernels on ordinary launches; unbuilt checkouts retain GDScript.
`--gdscript-kernels` forces the reference for comparisons. `--native-kernels`
requires the library and exits nonzero when unavailable; conflicting flags also
fail. Generation of build binaries/descriptors remains local, so source-only
CI/export runs use the fallback until native artifacts are built and included.

No-flag mesh validation reports `MESH_BACKEND native`; forced fallback reports
`MESH_BACKEND gdscript`. Both exact-output suites pass. Selection probes using
an unavailable class/descriptor confirm default fallback exit 0, explicitly
required native exit 1, forced fallback exit 0, and conflicting flags exit 1.
After updating to main's heavy-walk change, default-native refresh, threaded
lifecycle, live explosives and inherited-scene lifecycle suites all pass.

Independent Standards and Spec reviews each found one issue: missing ARM64
Linux/Windows descriptor entries, and native-required profilers accepting
fallback. Both fixes were re-reviewed as resolved. No remaining findings were
reported on either axis. Build API dumps now carry `.gdignore` so editor imports
do not treat generated API data as game content. Remaining performance limits
are unchanged and are recorded in the current acceptance report.
