# Spec: the ground query in C++ (loop `ground-native`)

## Why

A flown log (`scratch/f2.csv` in the main checkout, 2026-11-02, Mac) puts
the GDScript tick at 4.3 ms mean, with the camera, near-miss, landing,
plane figure and tree-knock parts (~1.3 ms mean together, camera spikes to
26 ms) dominated by one thing: asking for the ground in GDScript dozens of
times a frame. The base height is already native (`ZenScapeLandField`), but:

- `LandField.height`/`sample` (`scripts/endless/land_field.gd:1133` and
  `sample` below it) carves ponds, tunnels, halls, splits, the Peak and the
  isles over the native sample in GDScript whenever any of those are on.
- `plane_ground` (`studies/endless_flight.gd:1130`) wraps it in arches,
  rocks, trees, halls, tunnels, ice, coast, stair and doors `ground` calls;
  `floor_at`, `eye_floor`, `_solid`, `_sight` and `_blocked` (same file,
  just below) chain the same owners' `land_y`/`inside`/`dry`/`sight`.
- Callers per frame: the chase camera (`scripts/glide_camera.gd` `_clear`,
  12 probes + an 18-entry dodge list, and `_sight`'s 10 steps), NearMiss
  `measure` (`scripts/endless/near_miss.gd:340`, ~5 `plane_ground` + 5
  `field.height`), manual landing (`floor_at` 1–4 a frame, `edge_margin`
  up to 320 probes on a stop), plane figure (1), `knock.before`'s 18
  `trees.tree_in` (`scripts/endless/tree_knock.gd:110`,
  `scripts/endless/land_trees.gd:1436`), the grass react's `_grass_at`,
  `sea_height`.

## Done looks like

The game flies, lands, threads tunnels and halls and knocks trees exactly
as on main, and a flown log of the same kind of flight shows the camera,
near, landing, figure and knock_before parts (and their p99) clearly lower.
The user judges by playing and by `tools/frame_report.py` side by side.

## Rules

- The pattern of the existing kernels (`native/terrain_kernels/README.md`,
  `docs/design/endless-flight/native-land-handoff.md`): GDScript stays the
  reference and the fallback when the library is missing or stale; a flag
  forces GDScript (`--ground-native=0`, and `--gdscript-kernels` turns it
  off too). Native must give the same answers as the reference: the
  carving shapes the land (co-op needs the same land on every machine), so
  `LandField` carve layers must match bit for bit as the land field does
  (land_math.h, no contraction); the query-only layers (camera, near
  misses) must match to float rounding at least. Each stage ships a
  scratch comparison over many points (random and along a real flight
  path, near every site kind) reporting 0 mismatches, run by the agent.
- Sites hand their data to C++ as packed arrays when they stand / drop
  (publish on change, not per query). Keep site owners' GDScript code paths
  intact; add a native mirror, don't delete.
- Port only what is stable. If a layer is clearly mid-prototype (recent
  churn in its git log), leave it in GDScript, say so in Notes.
- Thread safety: LandField is read from worker threads; the native side
  must be safe for concurrent reads while the main thread publishes (copy
  on write / swap a snapshot).
- Rebuild the library on the Mac (SConstruct in native/terrain_kernels).
  Note in the handoff that the PC needs a rebuild (`docs/desktop-builds.md`);
  bump `NATIVE_VERSION`-style staleness checks so a stale PC library falls
  back to GDScript cleanly rather than crashing or mismatching.
- Measure before and after each stage with a headless driven check through
  the real play loop (`tools/drive.py`) flying low through the wilderness
  (seed 1) near tunnels, halls, arches, rocks and trees, timing the ground
  calls (FrameLog parts). Headless numbers are a guide; the real judgement
  is the user's flown log at the end.
- Prototyping rules hold: smoke checks plus throwaway scratch checks, no
  new committed tests, no full suite.

## Stages (the trunk; no lanes, each needs the one before)

1. Baseline: count and time ground calls per frame per caller in a driven
   low flight; record the numbers in the commit. Pick the order of the
   stages below by what the numbers say.
2. `LandField.sample` carve layers native (ponds, tunnels, halls, splits;
   the Peak is already `ZenScapePeak`, isles if stable), one call.
3. `plane_ground` / `floor_at` / `eye_floor` / `_solid` composite native:
   one `ZenScapeGround` object holding every owner's published site data,
   with batch calls for the camera's probe march and `_sight` (one call
   per march, not per probe).
4. `trees.tree_in` / `inside` native (bucket lookup), used by knock.before
   and `_blocked`.
5. Handoff doc beside this spec: what's native, the flags, how to compare,
   the before/after numbers, and the PC rebuild note.

Smoke check every iteration: `studies/endless_flight.tscn` via
`tools/smoke.py`. Iteration cap and budget: the skill's default.

## Notes (2026-11-03, trimmed for the PR)

- Stage 2 (the carve in C++, `ZenScapeCarve`, 64c685b1) was built, then
  axed by the user's choice: a tiny gain for a duplicated copy of the
  carve's maths that would drift silently from the GDScript. LandField
  `sample` is main's GDScript again. What ships: the GroundTally counter,
  stage 3's broad phase (`ZenScapeGround`, with the ice layer and stage 5's
  per-owner republish) and stage 4's tree solid (`ZenScapeTreeSolid`).
- The stage parity checks are one committed tool:
  `python tools/ground_parity.py` (`--break` for the control).
- The PC needs a native rebuild (`docs/desktop-builds.md`); until then it
  runs the GDScript for both layers. Handoff: ground-native-handoff.md.
