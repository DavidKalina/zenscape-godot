# Native terrain kernels

Mesh face shading uses C++ GDExtension automatically when its local library is
built. Unbuilt checkouts run the GDScript implementation without setup errors. GDScript retains
terrain transactions, private input snapshots, workers, resource publication,
physics and undo. It does not change rendering quality or use a different mesh.

The kernel accepts packed arrays and scalar settings. It performs no scene,
renderer or physics operations. The existing sequential GDScript builder remains
the exact-output reference, including when testing native synchronous shading.
Automatic native shading runs inline for up to 8,192 faces; larger meshes and
explicit positive worker counts use the worker pipeline. The compiler disables
floating-point contraction to retain the reference's
operation ordering. Test exact output on each new compiler/architecture.

## Terrain erosion

`erode` builds inland genome version 7 terrain: ridged, domain-warped detail on
slopes, then stream-power erosion down a drainage tree with sediment settling
where the flow slackens. It runs on a 41x41 grid and returns a height delta.
`scripts/terrain_erosion.gd` samples the grid, calls the kernel and caches the
result; its `erode_reference` is an exact GDScript mirror, so an unbuilt
checkout, or a stale library without `erode`, grows the same world. Unlike the
shading kernel this output is saved-world state: both sides use only
`+ - * / sqrt floor` on doubles and 64-bit integer hashing, and any change to
one must be made to the other. Check with
`tools/probe_terrain_erosion.gd -- 400 --reference 400`, which must report 0
mismatches. The kernel takes under 1 ms per world; the mirror takes about 70 ms.

## Build and run

Prerequisites: Godot 4.7 editor, a C++17 compiler, Python 3, SCons 4.x, and the
official [godot-cpp](https://github.com/godotengine/godot-cpp) checkout. The measured
build used commit `6cceaf6a5f8b0d78ac5d71c139fd7fabba43b918`, SCons 4.8.1 and
Apple clang on arm64. Pin that commit when reproducing the build.

```sh
python3 tools/build_native_kernels.py \
  --godot /absolute/path/to/Godot \
  --godot-cpp /absolute/path/to/godot-cpp \
  --scons /absolute/path/to/scons
```

The script dumps the installed editor's extension API, builds the matching
library, and creates the local `.gdextension` descriptor. Binaries, API dumps and
the generated descriptor are ignored by Git. Ordinary launches use the built
kernel automatically. `--native-kernels` is a validation flag that requires it
to be available; `--gdscript-kernels` forces the reference implementation for
comparisons. Pass these after Godot's `--` separator. For example:

```sh
/path/to/Godot --headless --path . --script res://tests/test_threaded_mesh.gd -- --native-kernels --benchmark
/path/to/Godot --path . --rendering-method forward_plus --script res://tools/profile_explosions.gd -- --native-kernels --quality=balanced
```

When no library has been built, ordinary launches use GDScript. The native test
fails if explicitly required with `--native-kernels` and unavailable, rather than
benchmarking fallback code. `NativeTerrainData.native_mesh_enabled = false` selects the reference for
an individual data owner even in a native run.

The desktop workflow builds debug and release libraries on Windows x64 and
macOS, using the pinned bindings above and SCons 4.8.1. Mac builds use
`--arch universal` to include both arm64 and x86_64 in one library. The helper
generates matching universal descriptor entries for that option.

CI requires native mesh equivalence in the editor, then checks imported, foundation and
sculpted meshes with synchronous and 0/1/2/4/8-worker release dispatch, plus the
menu/editor, through the actual exported executable. Release templates prohibit
script/path overrides, so CI launches normally with `-- --native-kernels
--verify-desktop-build`. The in-package self-check requires the kernel and runs
outside the checkout; a missing library cannot silently pass via GDScript. Only verified packages are uploaded.
Mac packaging verifies both architecture slices; execution checks cover the
runner's architecture. Linux native exports are not covered by this workflow.
Local exports still require matching libraries to be built before exporting.

## Interpretation

See `docs/performance/threading-acceptance.md` for the interaction results. Faster
face arithmetic does not remove shoreline preparation, texture uploads, render
synchronization or physics costs. Worker counts must be remeasured for native
kernels: at sub-millisecond shading costs, copying and scheduling more partitions
can cost more than the computation they distribute.
