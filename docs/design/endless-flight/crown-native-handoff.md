# The Peak's chunks in C++: handoff

The Peak's per-vertex land work now runs in C++ with the same output, and land no longer arrives
late at the mountain. A Peak chunk went from about 170 ms to about 17 ms, and gorge waits from
about 1.2 s to about 28 ms. Nothing in the look, shape, flight, LOD levels, sky or thread budgets
changed.

Item 3 of `crown-popin-handoff.md` is done. Items 1 and 2 (the collar's sky, the 666 m swap) are
untouched and still the user's call. The swap is exactly as sharp as it was, only on time now.

## What moved

New: `native/terrain_kernels/peak_massif.h` (`zspeak::Massif`, the maths) and
`peak_massif_bind.h` (`ZenScapePeak`, the class). `land_math.h` gained `det_atan2`, fdlibm's, so
the Peak's angles are machine-independent like the land's other maths.

- `PeakMassif._h_rock` and all it calls: `_h0`, `_falls`, `_rock_keep`, the ring and ribs,
  `_valley`, `_cirq`, `_tarn_n`, `_crown_rock`, `_roots` with the shoulders.
- `PeakRock` whole: `move`, `ledge`.
- `PeakSplit`'s readers: `near`, `carve` and their helpers.
- `PeakMassif.apply_chunk` and `apply_grid`. The Peak's share of `RockShape.grid` falls away
  through `apply_grid`, since its ring reads `LandField.grid`.
- `apply_chunk`'s colours: read directly from a native field. Any other field (the regions'
  blend, `GDField`) goes through `LandField.colours` as before.

`_h_rock` is what `apply` calls, so `height()`, `sample`, `shape`, `river_y`, the wheels and
everything else reading the field get the same native numbers as the chunks.

**One object per land.** `_go_native` builds one `ZenScapePeak` once and caches it in `_shared`,
beside the mask. Every worker's massif shares it. Its data is passed once in `setup`, then only
read: everything in `Massif` is const.

**Maths.** As the land: `land_math.h`'s exp/pow/sin/cos/atan2, or with `--land-libm` the C
runtime's, for checking against GDScript on one machine.

Constants are duplicated in `peak_massif.h`, as `land_field.h` does. **A change to the Peak's
maths or constants must be made on both sides**, and `ZenScapePeak.version` bumped with
`NATIVE_VERSION` in `peak_massif.gd`. Both files say so at the top.

## Flags

- `--native-peak=0`: the Peak in GDScript. `--gdscript-kernels` does that too, plus every kernel.
- `--cirque=0` and `--spire-form=0`, debug shapes, stay in GDScript and turn the twin off.
- A library without `ZenScapePeak`, or at another version, falls back by itself.

## Same output

`scratch/native_peak/parity.gd` (throwaway, git-ignored): two fields in one process, one with its
twin detached. It compares every array of chunks across the massif at levels 0-7, their rock
shape, the field's grids, and the point reads.

| Run | Array values | Differ | Point reads | Differ |
|---|---|---|---|---|
| Default maths (`land_math.h`), 289 chunks | 29,277,013 | **0** | 30,000 | **0** |
| `--land-libm`, 134 chunks | 12,027,803 | **0** | 8,000 | **0** |
| `--world=regions` (blended colours), 60 chunks | 6,064,740 | **0** | 6,000 | **0** |

Arrays: heights, verts, normals, colours, the paint bytes, river, rock shape, grid heights,
meadows, river. Point reads: `sample`, `height`, `river_y`, and `shape`'s keys every 20th.
**That is bit for bit, with no tolerance**, on Windows.

Negative control: a twin with one tower's phase off by 0.0005 gave 28,498 differing values and
220 differing heights, so the check does see the native path.

Workers: `scratch/native_peak/threads.gd` ran 400 builds of 40 chunks at once on the pool
(16 threads), each with its own field on the shared twin. All 40 hash the same as serial GDScript.

## Numbers

PC quiet unless marked. **Chunk cost**, `land._build` on the main thread, chunks along the gorges,
ms. The user had a game open during this pair, about one core busy (18% load):

| Level | GDScript mean | Native mean | Native worst | Native's build_chunk + RockShape |
|---|---|---|---|---|
| L0 | 163 | **14.2** | 23 | 9.2 + 4.1 |
| L1 | 178 | **16.7** | 23 | 8.9 + 5.9 |
| L2 | 185 | **18.7** | 33 | 9.4 + 7.1 |
| L3 | 156 | **18.8** | 29 | 10.0 + 6.8 |

An earlier partial pass, before the game was opened, gave L0-L2 GDScript 149/165/172 and the same
native numbers. In the real pool, the mean build went from 183-187 ms to 18.7 ms.

**Gorge wait**, rendered, 1440x900, 50 m/s, a = 2300 to -300, `--no-fixed-fps`, quiet PC. Median /
p90 / worst, ms. GDScript is `--native-peak=0`, one run; native is two runs:

| Level | GDScript | Native r1 | Native r2 |
|---|---|---|---|
| L0 | 252 / 497 / 764 | **21** / 48 / 76 | **21** / 46 / 77 |
| L1 | 980 / 2075 / 3396 | **24** / 53 / 136 | **23** / 61 / 181 |
| L2 | 1156 / 1810 / 3837 | **28** / 75 / 234 | **30** / 70 / 243 |
| L3 | 1285 / 2339 / 4373 | **30** / 70 / 133 | **32** / 66 / 85 |
| L4 | 1549 / 1879 / 4136 | **51** / 88 / 98 | **73** / 106 / 167 |

That run's frames: median 7.97 to 6.38 ms, p95 11.2 to 8.0, p99 13.1 to 8.7. Worst frame unchanged
at about 47 ms. Teleport settle 11.8 s to 3.8 s. Smoke's load 23.7 s to 17.6 s.

**A driver note.** `scratch/popin/trace.gd` passed `settled()` before the land had seen the
teleport once the land got fast, so the teleport's backlog was counted as flight waits (2-3 s at
L3-L6). `scratch/native_peak/trace.gd` holds the pose 30 frames first. Both columns above use that
copy. The handoff's own runs of the old driver came out the same as this GDScript column.

**Flight.** `scratch/crown_fly.gd`, medium, by the stick with wobble, up both gorges, native
against `--native-peak=0`, headless: the same to the printed figure.

| Gorge | Time | Mean | Wall room | Over floor | Scrapes | Crashes |
|---|---|---|---|---|---|---|
| Rock | 35 s | 56.2 m/s | 36.6 m | 30.8 m | 0 | 0 |
| Ice | 56 s | 55.1 m/s | 30.6 m | 28.6 m | 0 | 0 |

**Smoke.** Passes on the default world and `--world=amberlands --at=476,-948`, each with and
without `--native-peak=0`, plus `--gdscript-kernels`. With the main checkout's library swapped in
(no `ZenScapePeak`, the Mac's case) it passes with 0 errors in GDScript.

## Left in GDScript, and why

- **`RockShape.grid`'s own loops, 4-7 ms a chunk.** Universal: every rocky chunk pays them. The
  clear next piece if land needs more, but not needed here.
- **The rest of a chunk's 9-10 ms in build_chunk** is mostly the native base field.
- **`Ponds.apply_chunk`/`apply_grid` for the tarn.** Near the lake only; the worst chunk seen is
  33 ms.
- **Once per land or per field:** `_way`, `_bake_mask` (kept GDScript so its output is the
  reference), `Split.bake`. `_init` and `_lay_ribs` run per field, 0.7 ms in all.
- **`_h0` called from outside `_h_rock`:** only the mask bake.
- **The debug shapes:** `--cirque=0`, `--spire-form=0`.
- `_portal_holes`, `_crest_cut`, `_tops_of`: 1-2 ms together.

## The main checkout and the Mac

`native/terrain_kernels/bin/` is git-ignored and `tools/worktree.py` copies it **from** main, so
merging brings the C++ but not the library. This worktree's bin holds both Windows targets. After
a merge:

- **Main on Windows:** rebuild both targets (`python tools/build_native_kernels.py --godot ...
  --godot-cpp builds/godot-cpp --scons ... --target template_debug`, then `template_release`), or
  copy both DLLs with their `.sources` from this worktree's bin. Do this before cutting new
  worktrees, or they copy the old library.
- **Until then** main runs the Peak in GDScript, as today, with no errors. The stale check is
  honest: `tools/native_stamp.py` hashes the new headers, and main's stamp (620bf1d7) won't match
  the merged sources (1ac0c588), so `tools/play.py` warns.
- **The Mac** must rebuild on the Mac (`python3 tools/build_native_kernels.py ... --arch universal`,
  both targets). It runs GDScript until then. Afterwards, re-run `scratch/native_peak/parity.gd`
  there. `scratch/` doesn't travel by git, so copy it. Apple's libm can differ from GDScript's in
  the last bit there; `--land-libm` is the one that should read 0.

## Not verified

- **The Mac:** not built, not run, not compared.
- **A release export.** `template_release` builds and is stamped, but it can't load in the editor
  binary, so every number and check here ran on `template_debug`.
- **Default maths against a Windows or Mac GDScript on another machine.** On this PC both maths
  gave 0 differences at float precision; that 1 ulp of a double rarely survives narrowing to float
  is why, not proof for other machines.
- **The look by eye.** Identical by construction, as the arrays match. No before/after stills.
- **`--peak-mask=0` and `--peak-rock=0` through the twin:** ported, not exercised.
- **The test suite** was not run. `tests/test_sky_peak_look.gd` is the only test naming these
  files. No test should change, since output is the same.
