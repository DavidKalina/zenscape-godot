# Native tree placement

The ask was to move the tree placement to C++, the way the grass moved. This is a prototype round: it was proved with smoke checks, a GDScript-vs-native comparison and real-loop flights, and it adds no committed tests.

## Where the time went (before)

Measured with seed 1 at `--at=-4000,1500 --heading=90` (over forest), flying the real input about 30 m over the ground. The cruise leg was 40 s at 29 m/s (1.2 km) and the boost leg 40 s at 46 m/s (1.8 km). The run was headless, in real time, with the native land field loaded.

- **Trees were already fairly cheap.**
  - A block took 45 to 48 ms on a worker. Of that, the plan was 44 ms: 17 ms reading the land's shape on the 6 m lattice, 19 ms on the mask, 5 ms thinning, under 1 ms for the feet. The floor grid took 2.7 ms, the floor mesh 0.6 ms and the instance buffers 0.4 ms.
  - A far cell took 37 ms: 33 ms for the plan and 3.8 ms for the floor mesh.
- **Gaps** (a wanted block or far cell missing inside its ring's visible reach):
  - The near ring never gapped.
  - The mid and far rings gapped only while the world was filling in at the start: for about 4.5 s headless and about 9 s rendered. At start, `prime` stood only the blocks within 420 m, then 3 tasks streamed about 150 blocks and 150 far cells (530 rendered).
  - Once filled, no ring gapped at either speed.
- **Main thread:** the trees' step averaged 0.12 ms. Its worst frames were:
  - the replan every 48 m: 2.4 ms headless and 6.3 ms rendered (`sort_custom` with a script comparator over every wanted block and far cell)
  - one cell's colliders standing in a single frame: 1.5 to 2.9 ms
  - `top_at`, about 2 calls a frame: 0.03 ms
  - rendered only, one 14 ms block stand at the start

## What changed

- **`native/terrain_kernels/tree_cell.h`** (new). It holds `ZenScapeTrees`, a line-for-line port of these:
  - TreePlan `area`, `far_cell` and `floor_grid`
  - land_trees `_build_block`'s instance buffers (near, mid and detail tiles), `_build_far`'s buffer and `_floor_arrays`

  It reads the worker's own native land field directly (`ZenScapeLandField.land()`), and cuts in the ponds that LandField passes it (Ponds `at` and `carve`). GDScript still makes the arches (`TreePlan.arches_flat`), the ponds (`LandField.ponds_in`) and each cell's lookup (`_cells`/`_lookup`, which top_at reads). It is registered in `kernels.cpp`.
- **`scripts/endless/land_trees.gd`:**
  - `_build` uses the native path when it can.
  - The GDScript path is unchanged and is still the reference. `--trees-native=0`, `--gdscript-kernels` and `--land-native=0` use it, and so does a missing or stale library.
  - **`prime`:** with native trees, it builds every block and far cell the rings want on the workers at once, as high-priority tasks. That took 0.4 s headless and 0.8 s rendered, against the old 0.9 s GDScript prime of 420 m.
  - **Streaming:** TASKS went from 3 to 6.
  - **Replan:** it sorts `[distance, x, z]` with the engine's own sort.
  - **Colliders:** a cell's shapes are added within 0.4 ms a frame (`_fill`).
- **No prefetch** was needed: once the rings were filled, nothing gapped at boost. There was no GPU readback to remove: the detail tiles keep their CPU buffers.

## Parity

`scratch/native_trees/trees_parity.gd` (not committed) compares each block's and far cell's buffers, tiles, floor, lookups and far plan, plus the Array hash. Every run was **bit for bit identical**:

- 13 runs over 9 seeds and places: about 500 builds, 25,000 near trees and 7,100 far trees, with arches and ponds in most of them
- with `--forest=1.5`, `--forest-meadows=0` and `=2`, `--ponds=4`, `--no-forest-floor`, `--spruce-detail=all` and `--spruce-rings=old`

The candidates are sorted with godot-cpp's `SortArray`, so equal ranks fall in the same order as `Array.sort_custom`.

## Frame time (same route)

| | before | after |
|---|---|---|
| block on a worker | 48 ms | 6 to 10 ms |
| far cell on a worker | 37 ms | 14 to 19 ms (the field's own sampling) |
| gaps, near / mid / far, headless cruise | 0 / 255 / 270 frames | 0 / 0 / 0 |
| gaps, boost | 0 | 0 |
| trees step, average | 0.12 ms | 0.11 ms |
| trees step, worst, headless | 2.9 ms | 1.4 ms |
| trees step, worst, rendered | 6.6 ms | 1.7 to 2.1 ms |
| worst stand, rendered | 13.9 ms | 1.1 ms |
| frame p99, rendered cruise / boost | 17.8 / 16.9 ms | 17.2 to 19.3 / 16.8 ms |

- The rendered run was 1440x900, 30 s a leg.
- A 40 to 55 ms frame early in the cruise leg shows up in both runs. It is not the trees.
- The rendered stills, native against `--trees-native=0`, match within a handful of pixels: `captures/native-trees/` (git-ignored).
- In both stills, a patch of pale crowns about 500 m off sits on the left hillside. It is not from this round, and was not looked into.

## The Mac

The dylib needs rebuilding there, for both targets:

```
python3 tools/build_native_kernels.py --godot /Applications/Godot.app/Contents/MacOS/Godot --godot-cpp <godot-cpp> --scons scons --arch universal --target template_debug
python3 tools/build_native_kernels.py --godot /Applications/Godot.app/Contents/MacOS/Godot --godot-cpp <godot-cpp> --scons scons --arch universal --target template_release
```

Until it is rebuilt, the Mac runs the GDScript trees. Afterwards, run the parity script there, because sin, atan2 and cos come from the C runtime.

## Proof and tests

- **Smoke**, headless: flying and `--on-foot`, each with native trees, with `--trees-native=0`, and with no native library. 0 errors.
- **Tests:** no test reads land_trees or tree_plan. These native and threading tests pass: native_collision_faces, native_fall_reuse, native_mountain_shape, native_object_editing, native_paint, native_pond_attributes, native_pond_cache, plate_migration, threaded_instances, threaded_mesh, forest_hold and inland_recipe.
- **Two tests fail**, on code this round doesn't touch. They were not checked on the previous commit.
  - `test_threaded_recipe`: "Worker pond grid retains exact double precision", in the recipe water.
  - `test_landform_forest`: the isle forest draws 7.7 M near triangles against a 1.2 M budget.
- The full suite was not run.
- **Drivers** (not committed): `scratch/native_trees/trees_perf.gd` (the flights) needs the round's temporary timers, which have been removed. `trees_shot.gd` takes the stills. `forest_map.gd` maps far-cell tree counts.
- The release DLL was built but not exercised: the editor loads the debug one.
