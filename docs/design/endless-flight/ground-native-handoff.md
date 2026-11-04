# Endless flight, the ground query in C++ (loop `ground-native`)

The ask (spec-ground-native.md): the GDScript tick asks for the ground
dozens of times a frame (the camera, near misses, landing, the plane's
figure, the tree knock), and those parts dominated a flown log. This round
moves the stable parts of those queries to C++. It is a prototype round:
smoke checks, a parity tool (0 mismatches) and headless driven timings. No
committed tests.

## Launch

- Mac: `./run-endless-flight.command`
- All of it off, for a side-by-side flight: add `--ground-native=0`
  (`--gdscript-kernels` turns it off too, with every other kernel).
- A flown log to judge it: `python3 tools/play.py -- --frame-log=res://scratch/f_on.csv`,
  then the same with `--ground-native=0` to `f_off.csv`, and
  `python3 tools/frame_report.py scratch/f_off.csv scratch/f_on.csv`.

## What is native

Each layer keeps its GDScript as the reference and the fallback, and each
publishes its data when it changes, never per query.

1. **The broad phase** (`ground_bind.h`, `ZenScapeGround`,
   `scripts/endless/ground_native.gd`). The arches (and the ships' moving
   ones, the cracked walls and way towers, in a short list of their own),
   the rocks, the Peak's towers and stair and the ice tunnel publish world
   XZ rectangles that hold everything each owner's own quick reject lets
   through. `GroundNative.mask(p, pad)` says which may answer at a point,
   and `plane_ground`, `floor_at`, `eye_floor`, `_blocked`, `_solid` and
   `_sight` (studies/endless_flight.gd) ask only those. A skipped owner
   would have said "nothing here", so the answers are the owners' own.
   Owners say what changed: LandArches and LandRocks `touch_arch` /
   `touch_rock` the cell or grid square, the towers and the stair `bump`
   their part (`bump()` alone republishes everything), the movers
   `bump_loose()`; only the changed squares are re-marked. Main thread only.
2. **The trees' flight solid** (`tree_solid_bind.h`, `ZenScapeTreeSolid`).
   LandTrees publishes each plan cell's `solid` as its block stands, a tree
   is knocked or the block goes; `tree_in`, `top_at`, `inside` and `ground`
   read the 3 x 3 buckets in C++, in double, bit for bit. Main thread only.

## Stage 2, the carve, axed

Stage 2 put LandField `sample`'s pond, slot hall and split carves in C++
(`ZenScapeCarve`, 64c685b1). The user took it out before the PR: the gain
was small (field.height ~7.0 -> 5.1 us in the split segment, within noise
in the meadow; the rest of field.height's cost is GDScript wrapping it
couldn't take) for a second copy of the carve's maths that would drift
silently from the GDScript each time a carve is tuned, and the carve shapes
the land. It was removed in a new commit (not a history rewrite): the
class, `land_carve.h`, `land_carve_bind.h`, its registration and its
README paragraph, and LandField's native path, so `sample` and `height`
are main's GDScript again (plus GroundTally's two counter lines). The
commit 64c685b1 keeps it whole if it is ever wanted back.

## What stays GDScript, and why

- **LandField `sample`'s carve** (ponds, tunnels, halls, splits, the Peak,
  the isles): all GDScript, as on main (stage 2 axed, above).
- **Tunnels** (tunnel_sites.gd, land_tunnels.gd): churned 2026-11-01/02.
  Their ground, land_y, sight and tube are GDScript. In a bore the camera's `_sight` is
  the tunnels' own fine march, so the bores gain least.
- **The ice tunnel's narrow tests**: churned 2026-11-01 (icefield). Only its
  reach is published (broad-phase bit ICE), so away from the tube it costs
  nothing.
- **Halls, coast, doors** in the composite: about 1-2 us each, not worth a
  layer yet.
- **The batch calls for the camera's probe march and `_sight`** (in the
  spec's stage 3): not built. What is left in a `_sight` step is GDScript
  that a batch call couldn't take without porting churned or unported
  parts: LandField `height`'s wrapping (LandBlend's regions, the Peak's and
  the isles' `reaches`, the river getter), the sea's swell, the tunnels'
  and ice tunnel's tube and sight, and the arches' and rocks' narrow
  `inside`. The broad phase already took the owners' rejects out of each
  step (`_sight` meadow ~230 -> ~130 us). If the camera part still leads a
  flown log, the next step is a native `heights(xs, zs)` on LandField for
  points inside one region, then a batch `_sight` over it.

## Flags and staleness

- `--ground-native=0` or `--gdscript-kernels`: both layers off.
- No library, or a library without the class or with another version: that
  layer runs GDScript, cleanly. Versions: `GroundNative.VERSION` (2) vs
  `ZenScapeGround.version()`, LandTrees `SOLID_VERSION` (1) vs
  `ZenScapeTreeSolid.version()`.
- **The PC needs a rebuild** of the native libraries (docs/desktop-builds.md,
  native/terrain_kernels/README.md "Build and run"). Until then it runs the
  GDScript for both, as on main; the parity tool says so (its checks FAIL
  with "no library, a stale one"). Rebuild there, then run
  `python tools/ground_parity.py` on the PC too.
- Measuring: `GroundTally` (scripts/endless/ground_tally.gd) counts each
  ground query per FrameLog part when a frame log is on; off it costs one
  static read a query.

## How to compare

`python tools/ground_parity.py` (headless, ~9 min both; `--only trees` ~1
min, `--only ground` ~8; past a tool call's limit, run it under
`tools/bg.py`). It runs `tools/harness/ground_parity.gd` once per check
and prints `PASS|FAIL <check>: points N mismatches M`; exit 0 only when
both find 0 mismatches. `--break` is the control (the arches layer, and
some tree cells, unpublished from the native side): both checks must FAIL
and it exits 1 (3 if it found nothing, so the check doesn't bite).

- `ground`: the study's plane_ground at pads -1, 0, random, 16, 17,
  `_blocked`, `_solid`, `_sight`, `floor_at`, `eye_floor` and the field's
  `last_river` after each, broad phase on vs every owner asked, at both
  ships, meadow and split spots, three stair flights, the Peak and the ice
  tube, near arches, loose arches, rocks, towers, flights and ice windows.
- `trees`: `tree_in`, `top_at`, `inside`, `ground` native vs GDScript at
  six spots, with knocks and blocks freed and re-stood.

Timing (scratch, git-ignored, in the loop's worktree): `scratch/gn_base.gd`
(a 55 m/s kinematic low flight, 8 m over the ground,
`--seg=meadow|split|tunnel`, a per-call bench) and
`python3 scratch/gn_parts.py <csv>...` for the parts' mean/p99.
`scratch/gn6_ab.sh` is the whole-loop A/B below.

## Numbers

Headless Mac, driven, 300 settle frames dropped. The machine was shared
with another session through stages 3-5, so runs were interleaved
(off, on, off, on); each run is listed. Headless numbers are a guide; the
real judgement is a flown log.

Per stage (us per call, before -> after; from the commits):

| stage | query | before | after |
|---|---|---|---|
| 3 broad phase | plane_ground, meadow | 44.3 | 30.5 |
| 3 broad phase | _sight, meadow | 233 | 181 |
| 3 ice layer | plane_ground, meadow | 38.1, 30.3 | 24.3, 23.0 |
| 3 ice layer | eye_floor, meadow | 17.9, 14.5 | 10.3, 10.0 |
| 4 trees | tree_in, meadow | 9.4, 9.9 | 2.0, 2.4 |
| 4 trees | top_at, meadow | 8.4, 8.9 | 1.5, 1.6 |

(The stage 3 broad phase row was `--ground-native=0` vs on, which then
turned stage 2's carve off too, so it is stages 2 and 3 together.)

Whole loop, every layer off (`--ground-native=0`) vs on, measured in
stage 5 **with stage 2's carve still in** (so "on" includes its small share,
mostly in the split segment; not re-measured after the trim)
(`scratch/gn6_ab.sh`, logs `scratch/gn6_*`), parts mean/p99 ms:

| part (mean/p99 ms) | meadow off r1, r2 | meadow on r1, r2 | split off r1, r2 | split on r1, r2 |
|---|---|---|---|---|
| tick | 3.63/10.22, 3.86/10.23 | 3.25/7.84, 3.39/8.25 | 3.60/11.18, 3.62/10.84 | 3.13/10.78, 3.09/9.84 |
| camera | 0.43/5.30, 0.45/5.27 | 0.28/2.94, 0.29/2.95 | 0.47/4.40, 0.47/3.72 | 0.33/3.71, 0.33/3.67 |
| near | 0.46/1.00, 0.49/1.21 | 0.28/0.64, 0.30/0.70 | 0.53/1.17, 0.53/1.13 | 0.31/0.97, 0.30/0.95 |
| landing | 0.14/0.29, 0.15/0.32 | 0.09/0.21, 0.09/0.22 | 0.16/0.32, 0.16/0.31 | 0.09/0.26, 0.09/0.28 |
| figure | 0.13/0.26, 0.14/0.34 | 0.09/0.20, 0.09/0.21 | 0.17/0.36, 0.16/0.37 | 0.10/0.28, 0.10/0.28 |
| knock_before | 0.15/0.31, 0.16/0.34 | 0.03/0.08, 0.04/0.09 | 0.17/0.34, 0.17/0.32 | 0.04/0.09, 0.04/0.10 |

(`scratch/gn8_*`; every run exit 0, 0 errors.) Every one of the spec's
parts is lower in both on runs than in both off runs, means and p99.

**A spike this round found and fixed.** The first whole-loop A/B
(`scratch/gn6_*`) showed landing's p99 up from ~0.3 to ~1.4 ms with
everything on: about one frame in 40 (in meadow) the first `mask` after an
owner's change rebuilt the whole hash (0.5-1.4 ms, growing with the
squares marked, 38k to 68k in a 40 s flight) and re-gathered every owner's
rectangles in GDScript (0.2-0.4 ms). It landed in landing because landing
asks first. Now (`ZenScapeGround` version 2) each layer keeps its
rectangles by the owner's id (an arch cell, a rock grid square, the
towers, the stair) with a count per square, and an owner's change re-marks
only its own squares: LandArches and LandRocks `touch` the key that
changed, the towers and the stair `bump` their part. Parity after it:
"GN_GROUND points 132828 mismatches 0"; `--break` control: 7833
mismatches, FAIL as it should.

## Not covered

- No flown log yet. Please fly the same kind of flight (low, fast, near
  trees, arches and rocks) with and without `--ground-native=0` and send
  the two logs: that is the spec's "done".
- The whole-loop numbers above were taken with stage 2 in; the trimmed
  branch was smoked and parity-checked, not re-timed.
- One headless run in stage 3 logged 11 dummy-renderer RID errors at load
  ("Initializing already initialized RID"), in no other run; it looks like
  a headless render-server race, not this round (it touches no meshes).
