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

## The endless land

`land_field.h` is the endless flight's land (`scripts/endless/land_field.gd`)
in C++, exposed as `ZenScapeLandField` (`land_field_bind.h`). LandField stays
the public face: it hands every call to the native field when this library is
built and current (`NATIVE_VERSION`), else to its GDScript field (`GDField`,
the same file), which is the reference. `--land-native=0` (or
`--gdscript-kernels`) forces the GDScript field. `build_chunk` makes a whole
land chunk's arrays in one call; `grid` a grid of samples.

The noise is the engine's own FastNoiseLite (`FastNoiseLite.h`, vendored
unchanged from Godot 4.7.2's `thirdparty/misc`), asked with float coordinates
as `get_noise_2d` is. Vector maths runs in floats and the rest in doubles, as
GDScript does. exp, pow, sin and cos are `land_math.h`'s (fdlibm's algorithms,
plain arithmetic), not the C runtime's, so a seed grows the same land on every
machine; `--land-libm` uses the C runtime's instead, which matches GDScript
bit for bit on one machine. Contraction must stay off (SConstruct): with fused
multiply-add, three spots in four move, by up to 3 cm.
`python tools/land_hash.py --seed N` prints the land's hash to compare
machines. Any change to one field must be made to the other; check with
`scratch/`'s comparison (the handoff, docs/design/endless-flight/native-land-handoff.md).

`land_carve.h` is LandField `sample`'s carve layers over the native field:
the ponds, the slot halls and the split mountains (land_ponds.gd,
hall_sites.gd, split_sites.gd), cut in by the field's `carve_sample` in one
call. GDScript still finds the sites and publishes each square's to the
field as it finds it (`carve_put`); a square not yet published, or one a
tunnel may touch, is worked in GDScript. The tunnels, the Peak and the isles
stay GDScript. `carve_version` (LandField `CARVE_VERSION`) gates a stale
library; `--ground-native=0` (or `--gdscript-kernels`) cuts them in GDScript.
Like the field it uses land_math.h's sin/cos/atan2 unless `--land-libm`.

`tree_solid_bind.h` (`ZenScapeTreeSolid`) is LandTrees `tree_in` / `top_at`
over the stood trees' flight solid: each plan cell's `solid` is published
as its block stands, a tree in it is knocked or the block goes, and a query
reads the 3 x 3 buckets in C++ in double, bit for bit the GDScript's. Main
thread only. `version` (LandTrees `SOLID_VERSION`) gates a stale library;
`--ground-native=0` (or `--gdscript-kernels`) asks the GDScript.

`ground_bind.h` (`ZenScapeGround`) is the flight's ground queries' broad
phase (scripts/endless/ground_native.gd): the arches, rocks, the Peak's
towers and stair and the ice tunnel publish world XZ rectangles by an id
of their own (hashed in 8 m squares with a count per layer, so a change
re-marks only its squares; the ships' moving arches in a short list), and
`mask` says which owners may answer at a point, so the study's
`plane_ground`, `floor_at`, `eye_floor`, `_blocked`, `_solid` and `_sight`
skip the rest. The owners' own narrow tests stay GDScript. Main thread only.
`version` (GroundNative `VERSION`) gates a stale library; `--ground-native=0`
(or `--gdscript-kernels`) asks every owner. The handoff:
docs/design/endless-flight/ground-native-handoff.md.

## The endless grass

`grass_cell.h` is `scripts/endless/endless_grass.gd` `grow_cell` past its
height grid (the probe's masks, KitFlora's Grow at the carpet's settings,
its Draw of the grass into multimesh buffers, the patches' tint, the far
wash and the sub tiles), exposed as `ZenScapeGrass`. endless_grass.gd sets
one up per layer (`native_config`) and calls it from its workers; the
flowers and seed heads it keeps come back as records GDScript draws.
`--grass-native=0` (or `--gdscript-kernels`) runs the GDScript placement,
which stays the reference. It matches it bit for bit on Windows (the
engine's PCG32, Variant hash and FastNoiseLite setup; float cos and sin as
the double result rounded, as the official build's runtime gives them):
any change to one must be made to the other, checked with the handoff's
comparison (docs/design/endless-flight/native-grass-handoff.md).

## The air and the birds

`flight_fx.h` holds the endless flight's per-frame loops: `ZenScapeMotes`
(endless_motes.gd's pollen drift and kicked grass bits), `ZenScapeRibbons`
(breeze_ribbons.gd's strips) and `ZenScapeBirds` (endless_birds.gd's
flocks in flight and every bird's parts). The GDScript keeps the spawning,
the random draws and the flocks, and stays the reference; on Windows the
loops match it bit for bit. `--native-react=0`, `--native-birds=0` (or
`--gdscript-kernels`) run them in GDScript
(docs/design/endless-flight/native-react-birds-handoff.md).

`ZenScapePeak` (`peak_massif.h`, `peak_massif_bind.h`) is the Peak's massif: its
profile and its chunk and grid passes (`peak_massif.gd`, `peak_rock.gd`,
`peak_split.gd`'s readers). One per land, read by every worker at once. On
Windows it matches the GDScript bit for bit; `--native-peak=0` (or
`--gdscript-kernels`) runs the GDScript, and a library without it falls back by
itself (docs/design/endless-flight/crown-native-handoff.md).

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
