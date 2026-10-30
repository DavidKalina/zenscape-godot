# Native grass reaction and birds: handoff

Two per-frame main-thread GDScript systems now have their inner loops in the
C++ kernels (`native/terrain_kernels/flight_fx.h`, registered in
`kernels.cpp`). Nothing in the look, counts, ranges or behaviour changes:
the C++ runs the same maths in the same order and gives the same bits.
The GDScript stays as the fallback and the reference. A missing or older
library falls back to it automatically.

## What moved

The `_react` step turned out to be mostly not `GrassReact.step` itself (0.05
ms) but what it drives: the eddies' ribbons and the motes. Measured on the
low amberlands line: ribbons `_draw` 0.36 ms, pollen 0.20 ms, kick 0.14 ms.

- **ZenScapeMotes** (`scripts/endless/endless_motes.gd`): the pollen specks'
  drift and the kicked grass bits' flight and turning, every frame, written
  straight into their multimesh buffers. Spawning stays in GDScript (its RNG
  and land probes). Each new speck or bit is built as before, then handed
  over as a record. A speck that leaves the disc or runs out of life is
  listed by `pollen_age` and respawned in GDScript in the same order.
- **ZenScapeRibbons** (`scripts/breeze_ribbons.gd`): the strokes' strip
  arrays (`strip_arrays`, which `_draw` now calls). The ribbons' simulation
  (0.11 ms, Callables and RNG) stays in GDScript.
- **ZenScapeBirds** (`scripts/endless/endless_birds.gd`): when every bird in
  a flock flies and the flock is WHEEL, RIDING, PEEL or LEAVE, its birds
  pass to C++ (`adopt`) and are flown there (`_fly_birds` plus the
  airborne `_pose_air`). Any other state hands them back (`_hand_back`). Every
  bird's part transforms (`_draw`) are laid out in C++. Natively flown flocks
  are read from C++ state; the others are packed in flock order. The flocks,
  the perched life, the burst and every random draw stay in GDScript.
  `sync_native()` writes the native birds back into their `Bird` objects,
  for drivers.

Constants are passed in from the scripts (`configure`), so they are tuned in
one place. A change to either side's maths must be made to the other.

## Flags

- `--native-react=0`: motes and ribbon strips in GDScript.
- `--native-birds=0`: birds in GDScript.
- `--gdscript-kernels`: both, plus every other kernel.

## Equivalence

`scratch/equiv.gd` (throwaway, uncommitted) runs the real scene. Each frame it:

- builds the scene's own ribbons' strips both ways and compares them;
- steps two fresh EndlessMotes twins with the same seed and inputs, one
  native and one GDScript, and compares their buffers. The eye is held 12 m
  over the land so the pollen shows, and a made-up wash in alternate windows
  keeps the kick running;
- steps two EndlessBirds twins the same way and compares every bird's state
  and every part's transforms.

| Run | Values compared | Differing | Max diff |
|---|---|---|---|
| amberlands low line, 2000 frames | all of the below | 0 | 0 |
| wilderness, 4000 frames | pollen 17.2 M, kick 11.2 M, strips 15.4 M, birds 7.9 M | 0 | 0 |
| wilderness low, 4000 frames, flush reach x4 (forces flushes) | pollen 17.6 M, kick 11.1 M, strips 14.9 M, birds 8.3 M | 0 | 0 |

The flush-forced run covered PERCH, BURST, RIDING, PEEL and WHEEL, with 2
flushes and up to 3 flocks flown natively at once. The perched life ran
through the packed-record draw. The result is bit for bit on Windows (MSVC,
`/fp:strict`).

## Speed

Rendered, one window, `--no-fixed-fps`, `-- --no-title --uncapped`, 4000
frames. Old (flags off) and new alternated, two rounds each. Each call was
timed with Time.get_ticks_usec in a temporary instrumented copy, since
reverted.

- **amber**: the low amberlands line, `--world=regions
  --regions=amberlands:1:start,wilderness:0.01`, launched at (-200, -1300),
  ground+35, heading -30 degrees.
- **wild**: the default wilderness world, relaunched at ground+30 at the
  spawn. Two far flocks (42 birds) were in view; no perched flock came near
  this line.

Each cell is round 1 / round 2.

| Run | `_react` mean | `_react` max | `birds.step` mean | `birds.step` max | wall median | p90 | p99 |
|---|---|---|---|---|---|---|---|
| amber old | 0.913 / 0.932 | 4.63 / 5.50 | 0.501 / 0.514 | 11.6 / 12.5 | 7.52 / 7.84 | 11.75 / 12.47 | 15.87 / 17.06 |
| amber new | 0.484 / 0.421 | 6.47 / 5.69 | 0.109 / 0.098 | 4.28 / 1.45 | 7.30 / 6.86 | 11.19 / 10.15 | 15.13 / 14.95 |
| wild old | 0.840 / 0.783 | 4.84 / 7.94 | 0.471 / 0.445 | 2.54 / 4.72 | 7.96 / 7.56 | 10.49 / 10.19 | 15.05 / 14.36 |
| wild new | 0.440 / 0.394 | 4.67 / 8.46 | 0.105 / 0.099 | 0.63 / 3.84 | 7.46 / 6.99 | 10.02 / 9.65 | 14.07 / 13.88 |

Means are ms per frame. In all, about 0.85 ms of main-thread work came off
each frame: `_react` went from about 0.9 to 0.4 ms and `birds.step` from
about 0.5 to 0.1 ms.

Per part (amber, round 2, old to new):

| Part | Old (ms) | New (ms) |
|---|---|---|
| ribbon strips | 0.357 | 0.084 |
| pollen | 0.199 | 0.066 |
| kick | 0.139 | 0.049 |
| birds flying | 0.254 | 0.028 |
| birds drawing | 0.249 | 0.060 |

The spikes left in `_react`'s max are spawning, which is still GDScript: a
whole pollen swarm at once when it first shows, and bursts of kicked bits.

## Build

- Built on this PC with VS 2022 Build Tools, SCons 4.8.1 and godot-cpp
  6cceaf6a (`builds/godot-cpp`). Both `template_debug` and
  `template_release`. `tools/native_stamp.py` reports current.
- **The Mac binary must be rebuilt on the Mac**
  (`python3 tools/build_native_kernels.py ... --arch universal`). Until then,
  the Mac's older library has no ZenScapeMotes, ZenScapeRibbons or
  ZenScapeBirds, so those systems run in GDScript there (same look, old
  speed), and `tools/native_stamp.py` warns that the kernels are stale.
- Bit-for-bit is checked on Windows only. Re-run `scratch/equiv.gd` on the
  Mac after its rebuild (its libm and clang could differ from MSVC in the
  last bit; the grass and land kernels carry the same note).

## Checks

- Headless import is clean.
- `tools/smoke.py studies/endless_flight.tscn` passes plain and with
  `-- --world=amberlands --at=476,-948`, each with native on and with
  `--native-react=0 --native-birds=0`.
- `tests/test_breeze_ribbons.gd` passes. It is the only test that touches the
  changed scripts. The full suite was not run.

## Unverified

- The Mac (see Build).
- The on-foot bird states (SCATTER, FLIT, SETTLE) are unreachable now that
  walking is cut. Their hand-back path is written but has not been exercised.
- The rendered look was not compared by eye. It is identical by
  construction, since the buffers match bit for bit.
