# Loading screen, round 2: a faster load (2026-10-13/14)

> On `perf/fast-load` (from `perf/loading-screen`, round 1). Not merged.

The goal was to cut the generator's loading-screen wait from 40-49 s to under
15 s on this Mac (M5 Pro, 6 performance + 12 efficiency cores, Metal).
**Not reached.** Sprawl 2 went from 43.4 s to about 20.5 s launch to
playable with the isles in the store (27.6-28 s on the first launch after a
code change), display on, in the evening. The display slept from 23:27 and
the later runs (both builds) ran 1.5-2.5x slower and noisier; they are in the
tables as a like-for-like check. Where the rest goes, and why more cores
don't help, is below.

## Play it

```sh
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
godot --path . res://studies/run_layer.tscn -- --no-title --shape=ring --seed=1
# as round 1 (every isle built in the game, nothing kept)
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2 --no-isle-store
```

Windows (PowerShell, from the repo root, per AGENTS.md "Running on Windows"):

```powershell
$env:GODOT = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $env:GODOT --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
```

The first launch after any change to a script builds the isles afresh (with
helper processes, see below) and keeps them; later launches load them.

Flags: `--no-isle-store` (build everything in the game, as before),
`--forge-procs=N` (helper processes at once; 0 none), `--forge-ahead`
(build the next layer's isles during play; off by default, see 7), `--shader-warmup` (the
full sweep on macOS), `--no-shader-warmup`, `--loading-hide-world` (see
"What's left"), `--loading-trace` (the stage marks and per-step times when
the screen drops).

Measure (rendered, windowed, vsync off, 1080p cap):

```sh
Godot --windowed --path . -s res://tools/bench_loading.gd -- --no-title --shape=sprawl --seed=2 \
  --secs=30 --loading-trace [--raygrid] [--change-after=45] --out=/tmp/zs-load
# the store gives back the very isle a build makes (headless, a few minutes)
Godot --headless --path . -s res://tools/isle_store_check.gd -- --layers=sprawl:2,ring:1 --all --base
```

## 1. The diagnosis: GDScript runs one thread at a time here

Round 1 found three isles built at once took as long as one. Measured this
round (`tools/diag_isle_builds.gd`, throwaway; rendered, Metal):

| Sprawl 2's 8 isles | Wall | Sum of isle builds |
|---|---|---|
| One at a time on a worker | 19.0 s | 19.0 s |
| All 8 at once, 8 workers | 19.8 s | 124.7 s |

Each build stretched 7-8x when run together. The LOD pass (C++, meshoptimizer)
did not stretch (163 -> 190 ms). A `sample` of the 8-at-once run shows the
build workers spending 33-69 % of their samples in `os_unfair_lock` waits and
wakes (on Apple, Godot's `SpinLock`; its `Mutex` would show as
`psynch_mutexwait`, which was rare). The symbols are stripped, so which spin
lock is not named; micro-benchmarks, same work per thread, ms each:

| Work | 1 thread | 2 | 4 | 8 |
|---|---|---|---|---|
| Builtin math (`sin` in a loop) | 39 | 39 | 39 | 45 |
| A GDScript function calling another (no objects made) | 16 | 92 | 147 | 462 |
| A method call on an object | 4 | 20 | 39 | 83 |
| Making 10,000 nodes | 4.6 | 36 | 66 | 191 |
| Making 3,000 convex shapes | 3.7 | 22 | 36 | 91 |
| `ArrayMesh` from arrays | 16 | | | 19 |
| A `surface_get_arrays` readback | 318 (waits a frame each) | | | |

So the serializing lock is on the GDScript call path itself in this engine
build (Godot 4.7.2 official, the editor binary the game is run from): two
threads running GDScript are each 5x slower than one, and it is not object
or RID creation (an isle makes 16-26 k objects, which costs 0.2-0.4 s of a
2-3 s build even fully contended). Cutting objects (merged collision, fewer
nodes) would save a few hundred ms an isle and change the collision; it was
not done. The worker pool's thread count and its low-priority share are not
the limit (more workers make it slower). Mesh creation from workers scales.

What the first load spent its time on (sprawl 2, round 1's code, display on):
boot and script compile 3.2 s; `LayerPlan.warm` 3.8 s (building kit pieces
to measure their footprints); base isle 4.8 s plus its plants and life 1.2 s;
the stage 3.2 s; the isles 13 s (eight builds of 1.3-5.3 s, serial, plus
their stand, plants and life on the main thread); warm-up 4.1 s.

## 2. What changed

**The isle store** (`scripts/roguelike/isle_store.gd`, new). A built motif
isle (its art as the worker leaves it: built, levels of detail added) is
kept on disk as a binary scene under `user://isle_cache`, with what a scene
file can't hold encoded beside it (the motif's fields, node references in
metas, the live rope bridges' script state, the bell spires' inner-class
node, groups, bound-function callables); its four shared materials (ground,
rock, ruin stone, growth) are tagged and put back as the live ones on load.
Loading is engine work on a worker (50-300 ms an isle headless; about
1.2 s rendered, as it makes the GPU meshes), against 1.3-5.3 s to build.
Keyed by the motif's script, seed, knobs, the stone look, the launch flags a
build reads, the engine and an MD5 of every script and data file: any code
change builds afresh. Least-recently-used past 6 GB; kept out of Spotlight.

**Helper processes** (`scripts/roguelike/isle_forge.gd`, new). An isle not
in the store is built by a headless Godot process (each with its own
GDScript, so they really run in parallel), half the logical cores of them
(2-8), then loaded. The seed-independent isles (gorge, stair clouds, bell
spires, the roost) are asked for at launch, before the plan; the plan's
isles the moment the plan is laid, on the plan's worker. With
`--forge-ahead`, while a layer is played the next layer's isles (the gate's
plan, `NextRegionLoader`) are built ahead by at most 2 helpers in macOS's
background QoS (efficiency cores). Only when the engine is an editor build (an exported game has no
project to point a helper at) and not headless; otherwise, or if a helper
fails, the isle is built in the game as before.

**Repeated motifs** come free: the same recipe is one file, loaded once per
copy (sprawl 2 has the gorge and the stair clouds twice; the two colonnades
differ by seed). Copies share no resources (loaded with
`CACHE_MODE_IGNORE_DEEP`), as two builds don't.

**The base isle** (`studies/aqueduct_isle_base.gd`, new): the aqueduct isle's
art as one build, the same calls in the same order, kept and loaded the same
way (4.3-9.5 s of building -> 0.1 s); the study applies its collision parts
and fields after, in their old order.

**The plan's piece footprints** (`KitMotif.piece_block`, 2-4 s of building
pieces at launch) are kept in the store as a small text file.

**Plants**: the edge test the grass, flowers and undergrowth run per try is
now `KitFlora.EdgeIndex` (each outline's segments filed in 3.5 m cells: the
same distance calls on the nearby segments only, so the very same answer:
checked on 1,000,000 points over five isles, 0 differ; 3-6x faster).

**Order and plants' rays** (`motif_sky.gd`, `motif_isle.gd`): isles stand one
whole before the next, in the order the one worker built them before; a
placed isle's plant rays look past the other motif isles, the Broken Viaduct
(and its stones and updrafts) and anything that moves, and wait two physics
steps after the isle's last shape goes back, so its own collision is all
there. See "Identical isles" for why.

**Warm-up off on macOS** (`LayerLoading.warm_wanted`): the full 31-view sweep
runs only with `--shader-warmup` there; the pilot's own view is still drawn 4
frames under the screen. On by default elsewhere (Windows), as round 1 left it.

**Small**: the roost's tower top is a bound static function, not a lambda
(the same numbers; a lambda can't be kept); loads of one file run one at a
time; trace marks and per-step microsecond timings under `--loading-trace`.

## 3. Before / after

Apple M5 Pro, 1080p cap, windowed 1920x1080, vsync off, `tools/bench_loading.gd`.
"Warm" = the isles already in the store (any launch after the first since a
code change); "cold" = the store empty (the first launch after any code
change: helpers build).

**Display on (evening, load average 1-2).** Sprawl 2; "after" is this
branch minus the last flora rule and with the world not drawn under the
screen (see 8), so read it as about 1-2 s optimistic:

| | Before | After, warm | After, cold | After, `--no-isle-store` |
|---|---|---|---|---|
| Launch to playable | 43.4 s (43.8, 44.3 rerun) | 20.5-22.4 s (5 runs) | 27.6-28.0 s | 41.9 s |
| First 10 s of play, worst frame | (30 s: 38-40 ms) | 38-39 ms | 39 ms | |

Ring 1 before: 37.5 s; not measured after with the display on.

Per stage, sprawl 2 (display on; marks from `--loading-trace`):

| Stage | Before | After, warm |
|---|---|---|
| Boot, script compile | 3.2 s | 3.4 s |
| Plan footprints (`LayerPlan.warm`) | 3.8 s | 0.1 s |
| Base isle art | 4.8 s | 0.6 s (loaded) |
| Base plants, life | 1.2 s | 1.3 s |
| Waiting for the plan (worker) | 0 | 1.6 s |
| Stage setup | 3.2 s | 2.8 s |
| Isles (build or load, stand, plants, life) | 13-23 s | about 12 s |
| Warm-up | 4.1 s | 0.1 s |

**Display off (overnight, both builds, final code).** Every run is slower;
compare columns within the table only.

| | Sprawl 2 before | after | Ring 1 before | after |
|---|---|---|---|---|
| Launch to playable, warm | 91.8 / 104.5 s | 72.9 s (48.9-51.4 s with the world hidden) | 74.6 / 79.7 s | 55.6 s (32.8-43.3 s hidden) |
| Launch to playable, cold | | 67.9 s | | 68.3 s |
| Layer change (the gate, held play) | 89.4 s (to ring) | 62.7 s; 53.9 s with `--forge-ahead` | 93.9 s (to sprawl) | 37.8 s |
| First 30 s: p50 / worst | 55-57 / 65-73 ms | 66 / 84 ms | 44-46 / 72-75 ms | 55 / 141 ms |
| First 30 s: frames over 100 ms | 0 | 0 (12 with `--forge-ahead`) | 0 | 1 |

**Helpers and the worker pool capped** (sprawl 2, display off;
`override.cfg` `threading/worker_pool/max_threads` and `--forge-procs`):

| Cap | Cold | Warm |
|---|---|---|
| none (18 cores, 8 helpers) | 67.9 s | 72.9 s |
| 8 | 81.7 s | 55.0 s |
| 6 | 76.6 s | 62.2 s |

Warm launches don't depend on the core count (nothing is built: loads and
main-thread work; the spread is the overnight noise). Cold launches do,
through the helpers: 6 helpers on this Mac were about 10-20 % slower than 8.
A 6-8-core Windows PC should see the warm figures scale with its single-core
speed and the cold ones a little worse, if its helpers run as here
(unverified: see Unverified).

**Where the gain came from** (sprawl 2, display on, 43.4 -> 20.5 s):
core-count-independent, about 23 s: isles loaded rather than built (and the
repeated gorge and stair clouds loaded twice for free) about 10 s; the base
art loaded 4 s; the plan's footprints kept 3-4 s; warm-up off 4 s; the
edge index about 1 s. Core-count-dependent: the helpers, only on the first
launch after a code change (cold 27.6 s against 41.9 s building in the
game: about 14 s, on 8 helpers).

## 4. Identical isles

- **Geometry, collision, metas, fields.** `tools/isle_store_check.gd` builds
  each motif in-process as the game's worker does (build, levels, held
  shapes), has a helper process build, keep and the game load the same
  recipe, and dumps both node by node: class, script, groups, every stored
  and script property, metas, the motif's fields, and every resource by
  content (mesh surface arrays and levels, shape points and faces, materials
  as shared or by their values, all hashed). Sprawl 2's and ring 1's isles,
  every other motif and the base: **0 of 13 differ** (8,337 to 34,132 dump
  lines each; triangles equal). Auto-generated node names (`@Node3D@2755`,
  from a process-wide counter) are numbered alike first; they differ from
  run to run in the game already.
- **Collision in the stood layer.** `tools/bench_loading.gd --raygrid`: a 40 x
  40 grid of downward rays over each placed isle at playable, static
  colliders only, hits to the millimetre, hashed per isle. Before and after, every isle of sprawl 2 and ring 1:
the same number of hits and the same colliders hit. The hashes (heights to
the mm) vary from run to run in both builds on the isles with something
time-driven on them (the roost's dragon, decks), and so do a few hit counts
(the first stair clouds gave 1,110 and 1,132 hits in two baseline runs); on
the isles without, they are equal.
- **Plants.** Not identical on every isle; this is the one place the output
  moved. Round 1's counts were the same run to run on this machine, but a
  plant's ray reads whatever collision stands when it is cast, and which
  neighbours, viaduct pieces, rides and even which of the isle's own held
  shapes were in the physics space then depended on the load's timeline (on
  a slower or faster machine round 1's counts would differ). Making the load
  faster moved that timeline, so the counts moved. The new rule (look past
  neighbours, the viaduct and anything moving; wait for the isle's own
  shapes) gives, against round 1, sprawl 2:

| Isle (sprawl 2, in order) | Before (3 runs) | After, final run | After, other runs |
|---|---|---|---|
| stair clouds | 2201 | 2201 | 2031-2215 |
| colonnade spine | 4279 | 4279 | 4267-4279 |
| sundered gorge | 8375 | 8375 | 8375 |
| colonnade spine | 4281 | 4281 | 4278-4281 |
| stair clouds | 3114 | 3114 | 2061-3105 |
| bell spires, sundered gorge, roost | 4155, 8363, 7107 | the same | the same |

  Ring 1's six isles: the same as before in the final run. Where runs
  differed, the plants on the second stair clouds are the ones that changed
  most (2,061 against 3,114: about a thousand tufts under its cliff prisms,
  which round 1 grew when its cliffs' held shapes were not yet back; the
  first stair clouds never had them). So: identical in the last runs of both
  layers, within a few tufts on two isles in some runs, and on one isle
  (the second stair clouds) sometimes about a third fewer tufts than round 1.
  That isle is the thing to look at in play.

## 5. Stills

`tools/bench_run_layer.gd --stills`, sprawl 2, the four fixed spots (spawn,
gulf, mid, next), before and after (`/tmp/fl-stills-fast-load-base`,
`/tmp/fl-stills-fast-load`, not committed): **the same isles, ruins, rope
bridges, curtains of growth and grass**. The differences are time-driven:
the wind ribbons, sway, the sky folk's airship (in the mid view it passes
through the before still), the cloud towers. The far ruin growth in the gulf
view reads the same.

## 6. The warm-up call

Off on macOS, on elsewhere. Round 1 measured no gain from the 31-view
sweep on this Mac at a 2-5 s cost; this round's runs with it
(`--shader-warmup`) did not remove the early-play slow patch described in 8,
and its 3-4 s cost is gone from the default. A Windows machine with a cold
shader cache is what it is for; unmeasured there.

## 7. The next layer prebuilt?

No. A layer change is faster (89-94 s -> 38-63 s overnight) because its
isles load or are built by helpers, but the screen still comes up: standing
the isles, growing their plants, the stage and laying the region after next
take the time that is left (in the sprawl-to-ring change, the isles were up
at 24 s and the next region at 36 s). `--forge-ahead` builds the next layer's
isles into the store during play (53.9 s against 62.7 s for that change) but
brought 12 frames over 100 ms into the first 30 s of play, so it is off by
default. Standing a second layer beside the first in the background, within
the play budgets, is the round-1 plan and still too big for this round.

## 8. What's left (where the time goes now)

Sprawl 2, store warm (`--loading-trace` marks, display on, evening):
boot and compile 3.4 s; plan footprints 0.1 s; base load 0.6 s plus its
plants and life 1.3 s; waiting for the plan 1.6 s; the stage 2.8 s (the
roost's dragon 1.35 s of it); the isles about 12 s (main-thread commits
about 7 s: standing parts and putting back about 70,000 held shapes 3 s,
plants 2.5 s, life 0.5 s; about 3.5 s of single long frames where the
physics builds the isles' convex hulls; loads arriving).

Ideas ranked, none done:
1. **The isles' stand and plants** are engine and GDScript work on the main
   thread. Fewer, merged hulls would cut both, but change collision.
2. **The stage** (2.8 s): the roost's dragon is built procedurally each
   launch; it could be kept as the isles are.
3. **The plan** (1.6 s waited): a plan kept per seed would help only
   relaunches of the same seed.
4. **Not drawing the world under the screen** (`--loading-hide-world`) saved
   time but, with the display asleep at least, made a slow patch of 2 s early
   in play (frames up to 150 ms at one camera heading, none when drawn every
   frame). It's off by default. Not tried with the display on.

## Unverified

- **Windows and exported builds.** The helpers use `OS.create_process` with
  the engine's own path and `--headless --path <project>`; not run on Windows
  (no console windows are expected with `--headless`, unverified). An
  exported game runs no helpers (`can_forge` needs an editor build) and, with
  nothing kept, builds every isle in the game as before. The worker-pool
  caps here were set by `override.cfg`; the helpers were capped by
  `--forge-procs`. This Mac's 6 performance cores are not a 6-8-core Windows
  PC: read the cap numbers as a direction only.
- **Final numbers with the display on.** The display slept at 23:27 and the
  final series ran after; both sides of each comparison were run that way.
- **Plants at a low sun / beside the viaduct**: not looked at in play.
- **A walk over each loaded isle in the play loop**: only the ray grids and
  the dumps.
- **Disk**: a cold layer writes about 1 GB (100-165 MB an isle: the meshes
  keep their build arrays for the levels, as before); pruned at 6 GB.

## Tests

No new committed tests (prototyping). Smoke: headless import clean;
`run_layer` sprawl 2 and ring 4, 400 frames headless: 0 script errors.
Ran the 45 tests that touch what changed (`test_run_layer`, the motif and
aqueduct isle tests, the sky, flora, ruin kit, serpent, telescope, ...): 36
pass, 2 pass with a known engine error. Fail on this branch and on the base
alike: `test_aqueduct_isle_look`, `test_aqueduct_isle_sky` (round 2's
first-tuft case), `test_motif_sky`, `test_layer_sprawl`, and
`test_broken_ring_isle` (fails on the base too: "Spiral: isle 2 to 3 by
bridge"; not on round 1's known list). `test_isle_loop_played` and
`test_ruin_kit` failed under load in the batch and pass alone. **Breaks: none
found.**

## Files

New: `scripts/roguelike/isle_store.gd`, `isle_forge.gd`,
`studies/aqueduct_isle_base.gd`, `tools/isle_store_check.gd`. Changed:
`scripts/kit_isle/motif_isle.gd`, `motif_sky.gd`, `kit_flora.gd`,
`kit_motif.gd`, `roost_dress.gd`, `scripts/roguelike/layer_loading.gd`,
`next_region_loader.gd`, `studies/aqueduct_isle.gd`, `studies/run_layer.gd`,
`tools/bench_loading.gd`.
