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

Only the macOS arm64 debug-template build is validated so far. Descriptor entries
and host selection for other platforms are build scaffolding, not verification.
Desktop exports currently use the GDScript fallback unless matching native
libraries are built and included; native packaging is not part of this change. Linux/Windows toolchains,
release builds, and their output equivalence remain unmeasured.

## Interpretation

See `docs/performance/threading-acceptance.md` for the interaction results. Faster
face arithmetic does not remove shoreline preparation, texture uploads, render
synchronization or physics costs. Worker counts must be remeasured for native
kernels: at sub-millisecond shading costs, copying and scheduling more partitions
can cost more than the computation they distribute.
