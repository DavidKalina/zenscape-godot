# Stutter: shader compiles and growth spikes

September 30, 2026; Godot 4.7.2, Apple M5 Pro, Metal, windowed 1440×900 on the
Retina display. Measured with `tools/profile_play_session.gd`, which plays the
cozy worlds scene through its real input: two Modeller pinches and a groove,
three rim springs kept, three water pours, three sowings (wildflower, oak,
dandelion), twenty seconds of growth, then slow and fast orbits.

The complaint was hitching while interacting: springing ranges, then sowing,
"starts to chug". Headless, the main thread held the 120 fps cap almost
throughout (worst frame about 25 ms). The stutter was on the rendered side.

## What stalled

1. **Pipeline compiles.** The first time a material draws in a given pass
   and vertex layout, the GPU builds a pipeline for it, on that frame. On a
   machine that had never compiled a shader, each new shader cost about a
   second: 1.0–1.4 s freezes on the first water pour and the first oak and
   dandelion sowings. With macOS's own Metal cache warm, the same compiles
   cost 20–120 ms. About 129 compiles happened during play.
2. **Growth refreshes.** Every emergence step (0.75 s while plants arrive)
   ran the full refresh. Its content stage freed every plant batch and made
   new ones, wrote every instance one call at a time, and bumped
   `instances_revision`, so the live water's reflection copied the scene
   again. Anchors and the skirt were re-lifted though the heights had not
   moved.
3. **Land life's survey** ran on the main thread in 1.2 ms slices, but some
   stages (`_find_bodies`, `_bucket_objects`) do their whole job in one call:
   up to 8.6 ms in a frame, once 25 ms. Starting a survey read the live
   water's still mesh back from the GPU.

## What changed

- **Pipeline warm-up** (`scripts/pipeline_warmup.gd`), under the loading
  veil: every plant and prop part in GardenView's registry drawn as
  GardenView batches it, then every entry of a recorded manifest
  (`scripts/pipeline_manifest.gd`, `assets/pipeline_warmup/`), then the live
  water's reflection view built once through its own code
  (`LiveWaterReflection.warm`), so each clip shader draws in that view too.
  The stand-ins are 1 cm across, half a metre before the lens. `--no-pipeline-warmup` turns it off.
- **Recording the manifest.** A pipeline is fixed by the shader, the vertex
  layout, how the geometry draws (mesh, multimesh with colours or custom
  data, particles) and the pass (shadows, transparency). The recorder writes
  exactly that for everything the main view draws in a played session, and
  stores built-in materials (whose shader follows their flags) with 1-pixel
  textures. Rerun it after adding effects, materials or kinds of geometry:

      godot --headless --path . -s res://tools/profile_play_session.gd -- --modeless --no-title --record-manifest

- **Instance publication** (`GardenView._rebuild_instances`): the worker that
  samples instances also packs each part into one MultiMesh buffer (20
  floats per instance). The main thread keeps each part's batch node and
  assigns its buffer; `instances_revision` bumps only when a part appears or
  goes away. The reflection's copies share the batches' MultiMeshes, so they
  follow without copying.
- **Anchors and skirt** are lifted only when the heights, the blank state,
  the open sides or the void state changed since they were last lifted.
- **Land life's survey** runs whole on a worker, on a private copy of the
  heights, cover, records and streams. The still water's triangles are kept
  on the CPU when the view builds them (`WaterFlowView.still_triangles`).

## Results

Compiles during play fell from about 129 to 8–14. The one-second freezes on
the first water pour and the first oak and dandelion sowings are gone. On a
cold Godot cache (with macOS's Metal cache warm), the worst compile frame
fell from about 120 ms to 59 ms. The warm-up costs nothing once loaded.

Headless, the main thread holds the 120 fps cap almost everywhere. Publishing
a growth step takes at most 0.9 ms on the main thread, and the emergence step
at most 3 ms.

Rendered, warm Godot cache, runs alternated. A is the baseline (7837253),
B is this branch, and C is this branch without the instance publication
change. Times are in ms, over the played phases.

| Run | p50 | p95 | p99 | max | >25 ms per min | compiles | growing, median |
|---|---|---|---|---|---|---|---|
| A1 | 17.7 | 26.9 | 32.3 | 48.8 | 200 | 134 | 17.5 |
| A2 | 17.6 | 25.2 | 30.2 | 62.7 | 171 | 126 | 18.7 |
| B1 | 16.1 | 21.0 | 27.5 | 36.7 | 58 | 8 | 17.5 |
| B2 | 20.1 | 30.6 | 35.6 | 49.0 | 460 | 8 | 21.3 |
| C1 | 17.8 | 24.8 | 32.3 | 45.3 | 159 | 12 | 17.7 |
| C2 | 17.2 | 28.6 | 33.8 | 44.8 | 337 | 12 | 22.2 |

Every configuration lands at either about 17 or about 22 ms while growing,
and a slow run is slow from the springs onward, before growth begins, so
that spread is between runs, not between changes. The instance publication
does not slow growth.

What remains is the GPU. A rendered frame here costs 14–19 ms, right on the
60 fps line; the main thread is 1–2 ms of it. With every optional feature
off the floor is about 10 ms, and half-resolution 3D saves about 4.5 ms. Any
extra work tips a frame to 25–40 ms.

## Measuring

- Cold-cache runs: move the project's `user://shader_cache` and `vulkan`
  folders aside for the run, and put them back after. The macOS Metal cache
  stays warm, so a first-ever launch is slower than any cold run here.
- `--track-shaders` names the first surfaces drawn near each compile.
- Runs vary a lot: springs and sowings are random, so the grown worlds
  differ. Compare alternated runs, never one run against another day's.
- Rendered numbers are wall frame intervals; another Godot process running
  at the same time doubles them.
