# Stroke pipeline: painting without hitches

September 26, 2026; Godot 4.7.2, Apple M5 Pro, `--headless` (dummy renderer).
Every number here is a CPU main-loop interval. Nothing below was rendered, so
GPU upload, presentation and the look of a stroke in progress are unverified.

Phase 3 asks that nothing hitch while you paint. Before this change every dab
tick (30 Hz) ran the whole `NativeChunkEditor.refresh()` synchronously.

## What a dab cost

`tools/profile_stroke.gd` opens the cozy product scene, replays the editor's
paint loop for 30 dab ticks (sub-dabs along the pointer path, then one refresh),
releases through `finish_stroke` and records the settle. Dab amounts are fixed,
so the settled world is deterministic and the script prints a fingerprint of it.

The default path (-4,-2.5 to 3,2) crosses a pond. A per-dab breakdown:

- mesh 11 ms, almost all of it the shoreline flood (`_shoreline_field`);
- content 9.5 ms: the stroke reaches water, so streams, falls and the pond were
  rebuilt and `content.revision` bumped on every dab;
- surface maps 15 ms and post-maps 4 ms;
- then about 25 ms more of scene processing in the same frame. The largest
  pieces were `_planar_water.sync` and the leaf litter reseed, which both
  rebuild on every `content.revision` change.

Several suspected hotspots were cheap in this world. `brush()` over its 2,025
vertices takes 0.04–0.1 ms, a mask paint dab under 1 ms, and `end_stroke`'s
snapshot about 1 ms. They were left alone.

## The change

- **Light refresh while painting.** `refresh()` without a frame tree, called
  during a paint stroke, publishes only what the brush visibly moves. It
  rebuilds the terrain mesh for the dirty region, lifts anchors, the skirt and
  plants or props in place (`GardenView.lift_instances`), and moves landmarks
  (`NativeGardenLandmarks.lift`). It skips water, surface maps, atmosphere
  bounds, the encounter ground, display fog and play geometry.
- **Settle at release.** `finish_stroke` starts one yielding `refresh(get_tree())`.
  Every incremental cache still diffs against the last *full* refresh, so the
  settle covers the whole stroke and lands on the same result. A new dab, undo
  or other refresh supersedes it by generation.
- **Shoreline debt.** While painting, `NativeTerrainData.defer_shoreline` shades
  faces against the last water field and records the region in `_shore_debt`.
  The next build that runs the flood grows its region by that debt. If the
  field moved, it reshades every face, exactly as an up-to-date build would.
- **Play systems** hear `play_geometry_changed` on a stroke's first dab, so
  carried props and routes let go, and again when the stroke settles.
- **Pond flood off the main thread.** A yielding `GardenView.rebuild` now floods
  recipe ponds on a detached height copy (`_sample_recipe_water`) before
  touching any water node. `NativeRecipeWater.build` accepts the precomputed
  impacts and colour ramp.
- `erase_objects` bumps `objects_revision` only when it removes a record.

Some strokes keep the full per-dab path, as before: object trails, erasing a
record, Blades (which draws only as instances) and meadow on the source chunk.
Cover painted on a recipe world shows on the terrain faces during the stroke;
its plants fill in when the stroke settles.

## Results

| Stroke (30 ticks) | Before: frame p95 / max, dab median | After: frame p95 / max, dab median | After: settle max |
| --- | --- | --- | --- |
| Raise across the pond | 68.0 / 111.8 ms, 40.4 ms | 9.0–9.2 / 9.2–9.3 ms, 1.4–2.1 ms | 37.8–40.7 ms, one frame |
| Raise, dry path (5,-9 to 10,-5) | 21.8 / 104.0 ms, 18.5 ms | 9.1 / 9.4 ms, 1.9 ms | 39.3 ms, one frame |
| Smooth | 70.0 / 103.0 ms, 41.2 ms | 9.3 / 9.4 ms, 2.1 ms | 40.4 ms, one frame |
| Meadow | 63.5 / 77.3 ms, 42.4 ms | 9.3 / 9.4 ms, 2.6 ms | 22.3 ms, one frame |
| Paint (tint) | 18.9 / 30.0 ms, 15.6 ms | 9.0 / 9.2 ms, 1.8 ms | 13.9 ms |
| Erase | 64.3 / 84.3 ms, 41.9 ms | 63.7 / 83.4 ms, 41.6 ms (full path) | 23.1 ms |
| Blades | not measured | 50.3 / 76.6 ms, 28.1 ms (full path) | 19.8 ms |

Idle frames are 8.3 ms, the project's 120 fps cap. The dry path's settle spike
comes from the recipe's first sculpt, which invalidates the stream probes and
forces one water rebuild. Before this change that cost landed on the first dab.

Each after-run's fingerprint matched its before-run. The fingerprint covers
heights, cover masks, terrain mesh arrays, instance sources and transforms,
pond and stream geometry, both surface maps, the skirt, the play-geometry
signature, the atmosphere summit and undo depth. Runs covered raise (both
paths), smooth, meadow, paint, erase, and a second stroke started three
frames into the first stroke's settle. Undo on the frame after release returned
the world to its initial fingerprint. The headless renderer keeps no MultiMesh
transforms, so the instance hash is computed from batch sources, not read back.

## Still open

- **The settle frame.** When a stroke changes water, one settle frame is still
  about 40 ms. Streams and falls take about 5 ms. `_planar_water.sync`
  (a synchronous re-setup of the reflection views) and `_update_leaf_litter`
  (a reseed) each take 7–18 ms in the same frame, reacting to
  `content.revision`. They are the next targets. Both live outside the refresh.
  *Update, slice 2 (`feature/water-brush`):* reflection views now re-set up
  over several frames, double-buffered, and a rebuild that leaves the water
  inputs alone no longer bumps `content.revision`. The plain's water is built
  on a worker too. See `docs/scenic/water-brush.md` for the numbers.
- Cover plants (meadow, grass) appear at release. A coalesced background
  instance rebuild during the stroke would show them sooner. Erase and Blades
  still pay a full refresh per dab.
- Mid-stroke, the rain, fog and habitat maps, the atmosphere summit and
  navigation lag until release. Whether that reads on screen is unverified.
- The terrain mesh is still a new `ArrayMesh` per dab. The upload is small in
  this world, but a regional `mesh_surface_update_*_region` path is unmeasured.

## Settle hitches (`feature/settle-hitches`, 2026-09-26)

Headless, same machine, shared with other agents. Before is `main` at 53bf016;
after is this branch. Plain runs use `--plain-seed 7 --salt=12345`, so emerged
records compare between runs. Every after-run's fingerprint (heights, cover,
mesh, instances, water, undo) matched its before-run.

| Case | Before | After |
| --- | --- | --- |
| Land stroke, plain, release frame | 19.4–26.0 ms | 0.3–1.3 ms |
| Land stroke, plain, worst settle frame (20 s watch) | 30.2–40.5 ms, 1–2 over 16.7 | 14.4–16.2 ms, 0 over |
| Emergence first plan, plain (no ponds) | 25 ms on one frame | worker, 31–45 ms off-thread; main thread 0.4–1.0 ms to snapshot, 0.02 ms to install |
| Land stroke, seed 184 (a pond), release | 9.4 ms | 0.5 ms |
| Land stroke, seed 184, worst settle frame | 54.3 ms (first plan, pond flood) | 19.0–20.5 ms, 1 over |
| Raise across the pond, seed 184, worst settle frame | 18.2 ms | 18.6 ms (see below) |
| Meadow, plain, worst settle frame | 14.1 ms | 12.6 ms |
| Forest, plain, worst settle frame (35 s watch) | 16.1 ms | 16.3 ms |
| Path, plain, worst settle frame | 13.3 ms | 14.4 ms |
| Forest Shift (clear), 2 passes, settle max | not measured | 9.4 / 9.8 ms; release 4.0–4.4 ms |
| Path Shift (grow back), settle max | 11.4 ms | 9.5 ms; release 2.4 ms |

What moved:

- **Land weathering on a worker.** The land brush's release erosion
  (`land_brush.gd`, `weather_job`) ran on the release frame: 9–25 ms, most of
  it the GDScript sampling around the native erode. It now runs on a detached
  height copy. The stroke's settle refresh starts when it lands, a few frames
  later (`NativeChunkEditor._weather_async`). It lands after `end_stroke`, so
  the undo step still holds the ground from before the stroke, and one undo
  removes both. Anything that opens a transaction first joins it
  (`data.stroke_starting`), so a quick second stroke starts from weathered
  ground. Undo, a regrow or any other height change drops it. A stroke that
  changed nothing is no longer weathered.
- **Emergence plans on a worker.** `emergence.gd` `_plan_async` gives a second
  Emergence (the planner) a detached copy of the ground: heights, provenance,
  ponds, streams, recipe settings and the forest wish. The planner builds the
  live blend, or refreshes a copy of it (`BiomeBlend.copy_onto`), and plans
  every queued region. Pond flooding for the blend runs there too; recipe
  worlds get their impacts and ramp taken up front (`BiomeBlend.live_settings`,
  `LiveGround.recipe_water`). The regions, blend and salt come back and are
  installed on the main thread (`_install`: forget, withdraw, append). Plans
  wait while weathering is in flight (`ground_settling`). Probes that drive
  `advance` in a tight loop keep the synchronous path (`plan_on_worker` is off
  unless the editor turns it on; `--sync-plan` in the profiler).
- **Encounter ground on a worker.** A yielding refresh used to rebuild the
  Bigfoot encounter ground's triangle buckets (`reference_ground.gd`) on the
  main thread: 3.2–3.7 ms in the post-maps stage. `prepare`/`build`/`adopt`
  split it. The worker result is adopted a frame or two later unless a newer
  terrain mesh has been published.

Still over budget (headless):

- **Seed 184, raise or land across the pond: one frame of 18–21 ms.** It comes
  three frames after the settle refresh publishes: a 12–15 ms slice of
  `planar_water.gd` re-setting up its reflection views. It runs in the
  `process_frame` signal through `_advance_setup_frame`, and its first slice
  (SubViewport, environment copy, lights, material duplicates) is not
  budgeted. This is water's area. The settle's other frames are 12–14 ms: the
  main-thread stream geometry (4.2 ms) in the content stage on recipe worlds,
  and the maps texture update.
- The plain land settle's worst frame is now 14–16 ms, with no single cause
  over 5 ms. Frames at 12–15 ms during a watch are emergence steps' yielding
  refreshes (content stage).

Profiler additions: `--shift` (the stroke works the other way), `--then=shift`
with `--shift-passes=N` (Shift strokes back over the first stroke's path, each
printed as a SHIFT line), `--salt=N` and `--sync-plan`. One Shift pass over a
young forest takes its wish only to about 0, above
`forest_brush.CLEAR_BELOW` (-0.25), so nothing is withdrawn. The second pass
withdraws 25 of 38 emerged plants. Whether one pass should be enough is a feel
question.

Run: `godot --headless --path . --script res://tools/profile_stroke.gd -- --mode=raise`
(add `--from=x,z --to=x,z`, `--then=undo|restroke`).
