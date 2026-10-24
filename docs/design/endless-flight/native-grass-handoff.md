# Native grass placement

The ask was C++ for the grass placement, because the carpet couldn't keep up with the faster plane. This is a prototype round: it was proved with smoke checks, a GDScript-vs-native comparison and real-loop flights, and adds no committed tests.

## Where the time went (before)

Measured with seed 1, flying the real input at about 15 m over the ground: 40 s at cruise (1.15 km), then 40 s at boost (1.82 km), headless and in real time, with the native land field loaded.

- **The cause was the workers' placement, not the main thread.** On a worker a near cell took 0.8 s at cruise and 1.9 s at boost. A far cell took 90 to 155 ms. Six cells could grow at a time.
- Per cell, on average:
  - grass candidates (KitFlora Grow, its probe and wild grass feet): 125 to 490 ms
  - drawing the records into buffers (`add_item`): 35 to 500 ms
  - the tint grid (`colour` + `Patch.tint`): 80 to 100 ms
  - flower candidates: 25 to 150 ms
  - the height grid (already native): 7 ms
- **Gaps** (a wanted cell missing inside its visible ring):

  | | near ring | far ring |
  |---|---|---|
  | cruise | 11% of frames | 0% |
  | boost | 83% of frames | 89% of frames |

- **Main thread:** the grass step averaged 0.25 ms. Its worst frame was 6.5 ms: a near cell's roughly 100 batches stood in one frame.
- **Rendered:** a 15 ms spike in `_cull`. Every far-LOD mesh swap made Godot read the instance buffer back off the GPU.

## What changed

- **`native/terrain_kernels/grass_cell.h`** (new). It holds `ZenScapeGrass`, which is `grow_cell` past the height grid, line for line:
  - the probe's masks (beach, river bank, slope, alpine, ragged rock edge)
  - Grow at the carpet's settings (candidates, feet, tussocks, thatch, seed heads, and the flowers over the meadow type and the drifts)
  - Draw of the grass into MultiMesh buffers, with the ring lot
  - the patches' tint, the far drift wash and the 8 m sub tiles

  The flowers and seed heads it keeps (a few hundred) come back as records, which GDScript draws with KitFlora.Draw. It is registered in `kernels.cpp`.
- **`scripts/endless/endless_grass.gd`:**
  - `native_config` gives each layer its tables, and `grow_cell(..., native)` calls `_grow_native`.
  - The GDScript path is unchanged and is still the reference. `--grass-native=0` or `--gdscript-kernels` uses it, and so does a missing or stale library.
  - **Prefetch:** `lead_with(velocity)` (from `studies/endless_flight.gd`, flying and on foot). Cells are also wanted round where the eye will be in 1 s (at most 64 m ahead). The near ring is planned for the lowest height over the ground at 0.5 s and 1 s ahead, so a descent or a hill brings it in early. `--grass-prefetch=S`, 0 turns it off.
  - **Stand:** a cell is stood over as many frames as its batches need, within the 1.5 ms budget.
  - **Cells in flight:** MAX_TASKS went from 6 to 8.
  - **Cull:** the far ring culls a quarter of its cells a frame, inside its 4 m slack at boost. The near ring culls half its cells a frame.
  - **Far-LOD swap:** a far batch keeps its buffer, and the swap builds a new MultiMesh from it (`_swap_mesh`), so there is no GPU readback. The CPU copy is about 24 MB across all far cells.
- **KitFlora is untouched**, so the motif editor is unaffected.

## Parity

`scratch/native_grass/grass_parity.gd` (not committed) compares every part's buffer, box and ring. Every run was **bit for bit identical**:

- 7 seeds and places: about 1.6 M tufts in 12,000 parts
- with `--no-drifts`, `--grass-cover=old`, `--land-native=0`, `--no-flowers` and `--no-regions`

Two things had to match the engine for this:
- C++ evaluates arguments in no fixed order, so the two random draws for a point are sequenced by hand.
- MSVC's `cosf` is a last bit off the engine's, so float cos and sin are taken in double and rounded.

## Frame time (grass's share of the main thread)

**Headless, real time, at 60 fps:**

| | cruise | boost |
|---|---|---|
| near gaps | 0% | 0% |
| far gaps | 0% | 0% |
| grass step, average | 0.21 ms | 0.66 ms |
| grass step, worst | 2.2 ms | 2.7 ms |

A native cell takes 8 to 16 ms on a worker, plus 6 to 8 ms for its height grid, plus up to 15 ms for the GDScript flower draw on near cells. Single-threaded, that is 45 ms against 725 ms before.

**Rendered (1440x900, RTX 4070 Super), 30 s per leg:**

| | before (`--grass-native=0 --grass-prefetch=0`) | after |
|---|---|---|
| boost gaps | near 58% of frames, far 50% | none |
| grass step, average | 1.2 ms | 0.65 ms |
| grass step, worst | 15 ms | 3.9 ms |
| frame, average | 16.67 ms | 16.69 ms |
| frame, p99 | 18.7 ms | 18.6 ms |
| frame, worst | 26 ms | 22 ms |

- A 40 to 50 ms frame in the cruise leg shows up in both runs. It is not grass: the grass step was under 2 ms in that frame.
- The look is the same: `captures/native-grass/{native,gdscript}.png`.

## The Mac

The dylib needs rebuilding there, for both the debug and the release target:

```
python3 tools/build_native_kernels.py --godot /Applications/Godot.app/Contents/MacOS/Godot --godot-cpp <godot-cpp> --scons scons --arch universal --target template_debug
python3 tools/build_native_kernels.py --godot /Applications/Godot.app/Contents/MacOS/Godot --godot-cpp <godot-cpp> --scons scons --arch universal --target template_release
```

Until it is rebuilt, the Mac runs the GDScript placement. After rebuilding, run the parity script there: Apple's float cos may still differ from the double result rounded by a last bit, which would only nudge a tuft's lean by about 1e-7.

## Proof and tests

- **Smoke**, headless: endless flight and `--on-foot`, each with native placement, with `--grass-native=0`, and with no native library at all. 0 errors.
- **Tests:** no existing test touches the grass. test_native_paint and test_threaded_mesh pass on the rebuilt DLL. The full suite was not run.
- **Drivers:** `scratch/native_grass/grass_perf.gd` (the flights) needs the round's temporary timers, which have been removed. Re-add the timers to use it again.
