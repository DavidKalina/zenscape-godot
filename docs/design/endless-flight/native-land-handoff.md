# Endless flight, native land round

The ask: port the land's shape to C++ so chunks build much faster, ahead of
more terrain and a faster plane. The land must stay the same for a seed on
every machine (co-op will send only the seed). This is a prototype round. It
is proved by smoke checks, a GDScript-vs-native comparison and timings.
There are no committed tests.

## Launch

- Mac: `./run-endless-flight.command [--seed=7]`
- Any: `godot --path . res://studies/endless_flight.tscn -- --no-title [flags]`
- The land is the same as before, so any launch line from earlier handoffs
  shows the same place.

## What changed

- **`native/terrain_kernels/land_field.h`** (new). The whole land field in
  C++, line for line from `land_field.gd`: continents, hills, ranges,
  meadows, valleys, rivers and mouths, the carve (blocks, ledges, gullies),
  round one's land, the colour, and every side output (`last_*`). It even
  keeps the carve's lattice caches the same way. That matters for one
  output: `last_floor` after a carved sample is whatever the carve's last
  broad read left (see Notes).
- **`native/terrain_kernels/land_field_bind.h`** (new). `ZenScapeLandField`,
  the GDExtension class. It has the per-point calls, the knobs and outputs
  as properties, and two batch calls:
  - `build_chunk`: a land chunk's whole arrays (verts, normals, colours,
    carve and river data, skirt) in one call.
  - `grid`: heights, meadows and `last_river` over a grid.
- **`native/terrain_kernels/FastNoiseLite.h`** (new). The engine's own copy
  (Godot 4.7.2 `thirdparty/misc`, v1.1.0, MIT), unchanged. It is set up as
  Godot's wrapper sets it up, and asked with float coordinates as
  `get_noise_2d` is.
- **`native/terrain_kernels/land_math.h`** (new). The land's own `exp`,
  `log`, `pow`, `sin` and `cos`. They use fdlibm's algorithms in plain
  double arithmetic, so they give the same bits on any machine. The C
  runtimes (macOS, Windows UCRT, MinGW) can differ in the last bit.
- **`native/terrain_kernels/SConstruct`.** It adds `-fwrapv` (the noise's
  integer hashing wraps by definition) and `-fno-fast-math` beside the
  existing `-ffp-contract=off`. MSVC keeps `/fp:strict`.
- **`kernels.cpp`** registers the class.
- **`scripts/endless/land_field.gd`** is now a facade with the same public
  members and methods as before:
  - It parses the flags, then hands every call to the native field when
    the library is built and its version matches (`NATIVE_VERSION`).
    Otherwise it uses the GDScript field.
  - The GDScript field is the old code, moved unchanged into an inner class,
    `GDField`. It is the reference.
  - `last_*` and the knobs are properties that read or write through to the
    working field. Callers need no change.
  - New: `native_on()`, `native_available()`, `build_chunk(...)` (native, or
    the old loops on `GDField`) and `grid(...)`.
- **`scripts/endless/land_stream.gd`.** `_build` makes one
  `build_chunk` call. The loops it had moved into `LandField.build_chunk` as
  the GDScript fallback, unchanged.
- **`scripts/endless/endless_grass.gd`.** `grow_cell` reads its 1 m probe
  grid with one `grid` call.
- **`tools/land_hash.py` + `tools/land_hash.gd`** (new, committed). The
  land's fingerprint for a seed, to compare machines (see Repeatability).
- No tree file was touched. `land_trees.gd` and `tree_plan.gd` are not in
  this branch. Anything that calls `Field.new(seed)` and reads `height`,
  `sample`, `shape` or `last_*` works as before.

## Flags

| Flag | What it does |
|---|---|
| `--land-native=0` | The GDScript field (as before this round). `--gdscript-kernels` does the same. |
| `--land-libm` | The native field on the C runtime's exp/pow/sin/cos (as GDScript). It matches GDScript bit for bit on one machine. It is for checking, not for play. |

All the land's flags work the same on both fields (`--mountains`,
`--peaks`, `--valleys`, `--no-valleys`, `--old-land`, `--no-carve`,
`--carve*`, `--no-rivers`, `--river-*`).

## Profile (before)

Single-threaded, seed 1, the 225 chunks the stream wants round
(-700,-300) (`scratch/native_land/build_split.gd`):

- Field sampling was 86% of a chunk build: 13.2 to 14.3 ms of 15.4 to 16.7 ms.
- The mesh, normals and colour loops were 2.2 to 2.4 ms. A new field was 0.03 ms.
- Level 3 chunks (8 m steps) cost twice the rest (27 to 30 ms). The carve
  reads the broad land on an 8 m lattice, so at 8 m steps every sample
  needs fresh lattice reads.

Costs that come from the algorithm, not the language:

- Each chunk builds a fresh field, so the carve's lattice cache (about
  800 KB) is thrown away per chunk. Neighbouring chunks redo their borders.
- One broad sample reads about 15 noises. The valley's distance takes 2
  extra valley reads (finite differences). The river's world scale takes 2
  more warped valley reads (6 noises), and its flow 2 continent reads.
- Coarse chunks sample their whole grid even where it is all sea.
- **A grass cell's grow is mostly not the field.** The field grid was about
  13 ms of a 150 to 400 ms grow. The rest is the KitFlora scatter.

## Verified

- **Import:** headless, 0 errors.
- **Smoke** (`tools/smoke.py studies/endless_flight.tscn`), 0 errors with
  each of:
  - no flag (native)
  - `--land-native=0`
  - `--old-land`
  - `--old-land --land-native=0`
  - `--seed=3 --at=548,-731 --land-libm`
- **Match** (`scratch/native_land/compare.gd`, run by `matrix.py`). Each run
  had 1.13 million samples:
  - an 8 km square every 16 m at full detail
  - 128 x 128 dense patches at 1 m (0.5 m by rivers and mouths) at
    details 0, 4 and 8 m, round 18 spots found on the grid: carved cliffs,
    valley walls, river banks, river mouths, coast
  - `shape`, `river_y`, `sea_calm` and `height` round each spot
  - 90 whole chunks (levels 0 to 4): `build_chunk` against the old loop,
    and the GDScript `build_chunk` against the old loop.

  It ran on seeds 1, 3, 7 and 42, and on seeds 1 and 7 with these flags:
  `--old-land`, `--mountains=2 --peaks=1.3 --valleys=1.5`, `--no-rivers`,
  `--river-mouth=0.5 --river-flare=2 --river-width=1.5 --river-drop=1.4`,
  `--carve=1.5 --carve-ledges=0.5 --carve-blocks=1.2`,
  `--no-carve --no-valleys`, `--mountains=0.4 --river-cut=0 --river-fill=0`.
  26 runs, 29 million samples, 1,620 chunks.

  | | Result |
  |---|---|
  | Heights, everywhere | **bit for bit the same** (max diff 0 m) |
  | Meadow, colour, river flow, `last_across` | bit for bit |
  | Chunk arrays (verts, normals, colours, carve bytes, river, heights) | bit for bit, all 1,620 chunks |
  | Other side outputs (`last_river`, `last_river_w`, `last_side`, `last_floor`, `last_cavity`, ...) | within 2.3e-13 (doubles; from land_math.h's last bit against the C runtime's) |
  | With `--land-libm` (seeds 1, 3, 7, 42) | every output bit for bit |
  | Round one's land (`--old-land`) | every output bit for bit |

- **Repeatability on this Mac.** `tools/land_hash.py` gives the same `exact`
  hash for the native field, the GDScript field and `--land-libm`, on seeds
  1, 3, 7 and 42. land_field.h built alone with clang at -O0, -O2 and -O3
  gives the same bits as the game's library at all 78,628 spots
  (`scratch/native_land/opt_levels.sh`). With contraction left on (fused
  multiply-add), 75% of spots move, by up to 3 cm. That is why it must stay
  off. Neither slice of the Mac library, nor the Windows DLL, has any
  fused multiply-add instruction.
- **Stills.** `captures/native_land/sheet.png` shows native (left) and
  `--land-native=0` (right), seed 1 at the range, Forward+. The land is
  the same. The plane stands a little further on in one: it flies on real
  time while the scene loads.

## Timings (before vs after)

The in-game stream uses `scratch/native_land/perf.gd`: seed 1,
`--at=-700,-300 --heading=66 --alt=90`, 1500 frames unpaced, 16 workers.
Before is the round's start (HEAD's three scripts), interleaved with after
over three rounds (`perf_ab.sh`). Other sessions loaded the machine (load
4 to 9), so the "before" numbers swing. An earlier pair at load 1.5 is in
brackets.

| | Before | After (native) | Speed-up |
|---|---|---|---|
| Chunk build on a worker, mean | 85 to 98 ms (45 ms) | 2.4 to 2.6 ms (2.1 ms) | about 20 to 35x |
| Chunk build on a worker, slowest | 260 to 440 ms (134 to 152 ms) | 6.3 to 7.2 ms (5.6 ms) | about 25 to 60x |
| Grass cell grow, mean | 350 to 400 ms (212 ms) | 190 to 260 ms (164 ms) | about 1.3 to 1.8x |
| Main-thread commit, slowest | 2.7 to 4.0 ms (1.5 to 2.6 ms) | 1.6 to 1.7 ms (1.2 to 1.3 ms) | about 1.5x |
| Chunks built in the 1500 frames | 275 to 279 | 334 to 337 | |

Single-threaded, no contention (`scratch/native_land/chunk_time.gd`, 225 chunks):

| | GDScript | Native | Speed-up |
|---|---|---|---|
| A whole chunk (`build_chunk`), mean | 15.8 ms (before: 15.4 to 16.7) | 1.92 ms | 8x |
| A whole chunk, slowest | 51.5 ms | 5.5 ms | 9x |
| A grass cell's 1 m grid (73 x 73) | 13.4 ms | 1.6 ms | 8x |

The in-game gain is larger than the single-threaded one. GDScript on 16
workers at once slows itself down, and the native field doesn't. The
fallback (`--land-native=0`) runs at the old speed: its loops call the
GDScript field directly, not through the facade.

## Not verified

- **Windows.** I have only the Mac. Not run there:
  - the cross-built DLL (MinGW)
  - CI's MSVC build
  - whether the Windows hash matches the Mac's

  Under the method, they should match bit for bit: the same noise code, no
  C runtime maths, no fused multiply-add, strict IEEE doubles on x86-64
  SSE2. That is a claim to check, not a result.
- **x86-64 at all.** Rosetta is not installed on this Mac, so the x86_64
  slice of the universal library never ran.
- Flight feel and long flights with the faster stream (no play-loop run
  beyond the smoke and the unpaced fly).
- The full test suite (not run, per the prototype rules).
  `test_threaded_mesh.gd` passes, as a check that the SConstruct flags
  left the mesh kernel alone.

## Repeatability (for co-op)

- Run `python tools/land_hash.py --seed 1` on each machine and compare the
  `exact` line. The Mac (native and GDScript alike) gives:
  - seed 1: `746423e985090e2759050166c6153aa3e041dc3e51a5d9f7dce57b07976dbc7d`
  - seed 7: `38c41f411bb72bbeee70891761f64bc98331c2dfbdf238eee6d34e609cc0a406`
- If they differ, copy one machine's dump (`scratch/land_hash/seed1_*.txt`)
  to the other. Then run `python tools/land_hash.py --compare a.txt b.txt`:
  it lists the spots that differ and by how much. The `mm` hash (heights
  to the millimetre) tells a last-bit difference from a real one.
- Nothing in the field reads the clock, thread state or uninitialised
  memory. Each field is built and read on one thread. Its caches only hold
  what a recompute gives, and they start empty.
- The GDScript field is not guaranteed the same across machines: its
  exp/pow/sin/cos come from each C runtime, and the engine binary's
  compiler flags decide its float maths. For co-op, both machines should run
  the native field.

## Tests this breaks

- None expected. No test touches the endless land. The SConstruct flags
  (`-fwrapv`, `-fno-fast-math`) change nothing for code without signed
  overflow. `test_threaded_mesh.gd` passes. The isle-kernel and water
  tests were not run.

## Notes for the next round: new terrain in C++

- **Where it goes.** In `native/terrain_kernels/land_field.h`:
  - a change to the land's broad shape goes in `broad()` (before the carve,
    so the carve and the valleys see it)
  - a cut or pass after the carve goes in `sample()`
  - a 3D "solid or air?" query would be a new method beside `sample()`,
    with FastNoiseLite's 3D `GetNoise`, bound in `land_field_bind.h`
- **A new knob becomes a flag.** Add a member to `zsland::LandField`. Parse
  the flag in `land_field.gd` `_init` into the `k` dictionary. Read it in
  `ZenScapeLandField.configure`. If callers must read or set it, add a
  property (the `ZSL_KNOB` macro) and a facade property in `land_field.gd`.
- **A new noise** is a new `FNL` member set up in `setup()` with an unused
  salt (19 and up), so the land's existing noises don't move.
- **Keep it repeatable.** Use `EXP`/`POW`/`SIN`/`COS` (land_math.h), never
  `std::exp` and the like. Add a `det_*` function to land_math.h if a new
  one is needed (`atan2`, `log`, ...). No statics that change, no threads
  inside a field, no iteration over hash maps. Keep contraction off.
- **The version.** Bump `version()` in `land_field_bind.h` and
  `NATIVE_VERSION` in `land_field.gd` together whenever the land's output or
  the interface changes. A stale library is then refused, with a warning,
  and the land is grown in GDScript.
- **The GDScript field.** Today it mirrors the native one exactly. If new
  terrain goes into C++ only, the fallback grows the land without it (see
  the decision below). If both are kept, mirror the change in `GDField`
  and check with a comparison like `scratch/native_land/compare.gd`
  (scratch is git-ignored: it lives only in this worktree). The committed
  quick check is `tools/land_hash.py` with and without `--land-native=0`:
  the same `exact` hash means the same land.
- **Exactness rules** (only for matching GDScript):
  - GDScript numbers are doubles.
  - Vector2/3, Color and PackedFloat32Array hold floats, and a double
    meeting one is narrowed first (the `V2`, `V3`, `C4` helpers).
  - Vector2 constants are floats (`*_X`/`*_Y` constants).
  - Noise coordinates go in as floats.
- **Rebuild on the Mac** (godot-cpp at the pinned commit and SCons 4.8.1
  are in `~/.cache/zs-plate-maps/`):

  ```sh
  python3 tools/build_native_kernels.py --godot ~/Applications/Godot.app/Contents/MacOS/Godot \
    --godot-cpp ~/.cache/zs-plate-maps/godot-cpp --scons ~/.cache/zs-plate-maps/sc/bin/scons \
    --arch universal --target template_debug      # then --target template_release
  ```

  Add `--platform windows` (MinGW, from Homebrew) to cross-build the
  Windows DLLs into `native/terrain_kernels/bin/`.
- **Windows.**
  - Build on the PC with Visual Studio's C++ tools and SCons:
    `python tools/build_native_kernels.py --godot $env:GODOT --godot-cpp <checkout> --scons scons`
    (docs/desktop-builds.md).
  - Or copy the cross-built `zenscape_kernels.windows.template_*.x86_64.dll`
    and `zenscape_kernels.gdextension` from the Mac into the PC's
    `native/terrain_kernels/` (`bin/`). They are git-ignored, so they never
    come with a pull.
  - Without them, the PC runs the GDScript field: the same land, at the old
    speed, with a version warning if an old DLL is there.
  - CI builds the DLL with MSVC on every push.

## Notes

- **A quirk kept as it was.** After a sample whose carve ran,
  `last_floor` (read by the valley fog's map) is whatever the carve's last
  broad read left, not the point's own floor. It depends on the carve's
  cache. The native field keeps the same caches, so it matches. Fixing it
  would change the fog map a little.
- `shape()` and `colour()` are native too. The fog, ground and depth maps
  (`endless_clouds`, `endless_sea`) still loop in GDScript, calling the
  native field per point. They could take a `grid`-style batch later.

## Needs the user's decision

- **New terrain in C++ only?** If yes, the GDScript field stays as today's
  land, and a machine without the library grows a different land from one
  with it. Co-op would then need the library on every machine. If no,
  every new feature is written twice and checked against itself.
- **The Windows PC** needs the new DLL (build it there, or copy the
  cross-built one) before it gets the native land. Until then it runs the
  GDScript field.
- **Grass grow** is mostly KitFlora, not the land. A faster grass carpet
  would be its own round.

## Commits

- `d93f5742` Endless flight: the land field in C++ (ZenScapeLandField), same land bit for bit
- This handoff (the commit after it).
