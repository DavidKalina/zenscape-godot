# The generator's layer, perf round 2 (2026-10-13)

> On `perf/run-layer-2` (from `perf/run-layer`, round 1). Not merged.

Round 1 ranked three things: ruin growth on the GPU, the Broken Viaduct's
build freeze, and big collision hitches. This round did all three. The user's
constraint, sent mid-round: the far ruin growth looks right and its look at
distance must not change.

## Play it

```sh
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
godot --path . res://studies/run_layer.tscn -- --no-title --shape=ring --seed=1
# the growth-shadow cutoff is a knob: 0 puts every shadow back as it was
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2 --growth-shadow-range=0
```

Measure it (as round 1):
`Godot --windowed --path . -s res://tools/bench_run_layer.gd -- --no-title --shape=sprawl --seed=2 --cap=1080 --stills --no-next --parts=none --out=/tmp/x`
(`--parts=none` skips the per-part sweep; `--growth-shadow-range=M` sets the knob.)

## What changed

- **Growth shadows stop at 40 m** (`scripts/ruin_lod.gd`). The growth
  (ivy, curtains, moss) is lifted out of each ruin "Mesh" into its own
  instance `Growth` under it. It uses the very same mesh and levels as round
  1, so its colour pass is unchanged, but it no longer casts shadows. Its
  shadows come from shadows-only twins `Shade0..n`: the growth cut into
  24 m cells at full detail, each visible (as a shadow caster only) within
  `SHADOW_RANGE` = 40 m of the eye. The stone casts as before. `--growth-
  shadow-range=0` builds the old single instance. (Godot has no per-surface
  or per-LOD shadow cutoff; separate instances with a visibility range is
  the clean way.)
- **Not done, on purpose** (user constraint): no further thinning of far
  growth, no splitting of runs to thin them harder (the cells are only for
  the shadow twins; the colour growth is one mesh per run with round 1's
  levels), and no vertex-colour grime bake (it would drop far growth).
- **Viaduct built on a worker** (`scripts/roguelike/layer_hazards.gd`).
  Rendered, `_make_viaduct` (lay out, build, the LOD pass, collision) runs
  on a `WorkerThreadPool` task off the tree. When done, the main thread puts
  its children into the tree 2 ms a frame, then its held shapes (below),
  then the old setup (foot stones, updrafts, air) in one frame (about 28 ms
  under load). `viaduct` stays null until then, so the hazards ignore it
  (and `set_on` is remembered). Headless it builds on the main thread as
  before (godot#124183). The study's paint cache is wrapped in a mutex for
  the worker.
- **Big collision stood over frames** (`scripts/late_shapes.gd`, new;
  `motif_isle.gd`; also used for the viaduct). On the build worker, a body's
  shapes past the first 16 are taken out and held; a trimesh over 9000
  corners is cut into pieces of about 2500 triangles first (along its
  longest side; the first stays). In the "standing" stage the isle puts them
  back as the sky's budget allows, and the isle is not "up" until all are
  back.

## Where the colonnade's hitch really was

The round 1 note said "one part has about 9,254 hulls, 40-50 ms". Timing
`add_child` part by part showed the colonnade "Spine" part is one body
holding one ConcavePolygonShape3D of 19,578 triangles (58,767 corners) and
that single shape cost 25-45 ms to enter the tree (Jolt builds its mesh tree
then). The 9,182 convex hulls are the other 9,182 shapes (hulls, deferred).
So the fix is mostly the trimesh cut. The pieces cover exactly the same
triangles.

## Before / after

Sprawl 2 and ring 1, 1080p cap, 3024x1898 window, `--no-next`, fixed spots,
median of 60 frames, vsync off. Each pair was run back to back; load average
was 9-10 (other agents ran headless suites throughout). Read every ms as
plus or minus 10 %. Primitives and draw calls are not load-sensitive.
Cell: before -> after.

Sprawl, seed 2:

| View | Frame ms | Script ms | Draw calls | Primitives |
|---|---|---|---|---|
| spawn | 37.6 -> 35.5 | 8.7 -> 8.4 | 2052 -> 1933 | 6.88 M -> 5.89 M |
| gulf | 13.5 -> 13.8 | 4.9 -> 5.0 | 880 -> 937 | 2.36 M -> 2.35 M |
| mid | 22.4 -> 20.1 | 3.3 -> 3.3 | 1049 -> 998 | 5.36 M -> 4.17 M |
| next | 6.4 -> 6.6 | 2.6 -> 2.7 | 109 -> 108 | 0.17 M -> 0.17 M |

Ring, seed 1:

| View | Frame ms | Script ms | Draw calls | Primitives |
|---|---|---|---|---|
| spawn | 25.6 -> 25.2 | 5.4 -> 6.2 | 885 -> 857 | 3.18 M -> 2.23 M |
| gulf | 8.1 -> 8.3 | 3.9 -> 4.0 | 152 -> 153 | 0.40 M -> 0.40 M |
| mid | 16.7 -> 16.4 | 2.7 -> 2.6 | 833 -> 806 | 3.11 M -> 2.20 M |
| next | 8.3 -> 7.9 | 2.9 -> 3.1 | 137 -> 135 | 0.40 M -> 0.32 M |

Reading it: the shadow cutoff removes 0.9-1.2 M primitives where growth is
near (30 % of ring spawn and mid), but the frame gain is 2-2.3 ms on sprawl
(spawn, mid) and none beyond noise on ring. The 5-8 ms estimate was too
high: on this machine the frame at these views is not simply primitive
bound. An earlier sprawl pair at the same window with only the knob changed
(`0` vs `40`, load 12) read spawn 39.2 -> 37.7, mid 25.6 -> 22.8, gulf
24.3 -> 23.2: the same direction and size. Gulf gains nothing because its
growth is all farther than 40 m.

Stutter traces (the stream until the layer stands, sprawl 2):

| | Before | After |
|---|---|---|
| Worst frame after the first | 9,239 ms at frame 70 (the viaduct, rendered), 61, 56, 54 | 62, 57, 45 (the viaduct freeze is gone) |
| Colonnade "standing" frame | 42-46 ms | under 6 ms in the worst-frame list |
| Frames over 50 ms | 6 | 3 |
| Viaduct | 5.7 s on the main thread | 0 s; main thread about 2 ms a frame while its children enter, then one 28 ms frame |

The first frame (3-12 s, scene load, collectibles) is the same in both and
untouched. A before run's frame 0 read 11.9 s, an after run's 3.2-4.1 s;
that is noise from load, not from this round. Other mid-stream hitches
(flora ticks 20-60 ms, "built" 20-60 ms) are as round 1 left them and
vary with load.

## Collision check

- A throwaway headless check (not committed) built the spine island twice,
  cut and drained one with `LateShapes`, put each in its own physics world
  and compared 6,000 downward rays: 515 hits, 0 mismatches (within 1 mm);
  triangle count 19,578 -> 19,578. Draining 9,182 shapes took 416 frames at
  1.5 ms a frame (about 7 s at 60 fps) in headless.
- Not done: a walk of the wanderer over a cut piece in the rendered play
  loop. See Unverified.

## Far growth, before and after (1:1 crops, same camera spots)

Stills from `--stills`, `/tmp/zs2-before/s2` (before) and `/tmp/zs2-after2b`
(after); crops in `/tmp/zs2-crops`:

- `f-spawn-zs2-before_s2.png` / `f-spawn-zs2-after2b.png`: the vine curtains
  under the floating stones (about 40-90 m).
- `f-gulf-zs2-before_s2.png` / `f-gulf-zs2-after2b.png`: the far ruins' ivy
  and tops.
- Earlier, with the first final build: `spawn-curtains-*`, `gulf-ruin-*`
  (before vs `r40`).

**Nothing changed that I could see.** The curtains read the same strand
for strand (their sway differs by time), the far ruins' growth is the same,
and the contact shadows the curtains cast on the stone beneath them were not
visibly different at these spots. I read the full views as well: the only
differences are time-driven (clouds, the airship, the wind ribbon). I did
not look at the 40-60 m band from the ground at a low sun angle. See
Unverified.

## Geometry tricks (docs/art/model-budget.md)

Meshes changed (at runtime, no art changed): the ruin kit's growth surface,
now its own instance.

| Trick | Applies? | Assessment |
|---|---|---|
| Import LODs | Kept as round 1 | The growth levels are untouched. The shadow twins have none, since they are seen only within 40 m, where the levels are all full anyway. |
| Silhouette geometry | Not here | Nothing changed. |
| Vertex-colour grime | Rejected for now | Would let far growth reach 0 %, which the user does not want to look different. Estimate if ever taken: 1-2 M primitives, 3-5 ms. |
| Rigid parts on bones, parallax, sculpt-bake | Not applicable | |
| Shadow casters (not in the doc) | Applied | Growth casts shadows only within 40 m: 0.9-1.2 M primitives at sprawl spawn and mid, 2-2.3 ms (ring: primitives only). Cost: the twins duplicate growth vertex data in memory (about the size of the growth surface). |

## What's left, ranked

1. **Ring (and gulf) frame time is not the growth.** Ring spawn is 25 ms
   with 2.2 M primitives; the frame is waiting on something else (draw 16
   ms). Next round should sweep ring with `--parts` (grass, sky_isles) first.
   Grass was up to 11 ms at the sprawl spawn in round 1's noisy sweep.
2. **Sky isles and multimesh** (sprawl spawn: sky isles 6 ms, multimeshes
   12 ms in one contended sweep).
3. **The viaduct's finish frame** (28 ms: foot stones, updrafts) could be
   sliced; its worker takes 5+ s of wall time (16 s under load) and the
   hazards are absent until it is done.
4. **Aqueduct base build** (9-16 s at load), layer-change spikes, MSAA
   setting, first load: as round 1.
5. **Collision**: the spine's 9,182 hulls could be merged into fewer
   bigger hulls for the walker (they take 7 s to drain).
6. **Cell size and range of the shadow twins** (24 m / 40 m) were not tuned
   against the look; 60 m would give back some of the win.

## Unverified

- **Walking a changed collision piece in the rendered play loop.** Only the
  ray comparison above. Concave piece seams (Jolt "active edges") could
  in principle catch a foot at a cut; none was observed, none was looked
  for in play.
- **Shadow cutoff under other light** (low sun, dragon-roost dusk): crops
  are at the bench's held time of day (phase 0.35) only. Use
  `--growth-shadow-range=0` to compare.
- **Loads were 9-13**, and the window came up at 1440x960 on two runs
  (those are not in the tables); the tables are all 3024x1898 pairs.
- **No windowed play session** of the viaduct arriving mid-run; the order
  (children in, held shapes in, setup) ran clean in the bench (no script
  errors) but a player standing at the viaduct while it builds was not
  tried (it is minutes from the spawn).
- **GPU time** is not available on Metal (as round 1).
- Headless: the viaduct builds on the main thread as before, so the
  headless paths do not exercise the worker.

## Tests

No new tests. Smoke: headless import clean; run_layer sprawl 2 and ring 1
rendered through the bench with no script errors.

Existing tests run: `test_ruin_growth`, `test_ruin_kit`,
`test_aqueduct_isle_sail` pass. `test_aqueduct_isle_life`, `_plane` pass.
**Breaks:** `test_aqueduct_isle_sky` fails ("The plane reads stair_clouds's
turf (70.88, its datum 44)"; passes on the base, 4 of 4 runs; fails with this
change, 6 of 6). The plant count is the same (2215 to 3289 depending on the
variant), but the first plant record is a different tuft, one on the stair
isle's top steps, where the turf really is 70.88 and the test's "within 25 m
of the isle's top" does not hold. I did not find why the first record
changes (it appears to follow deferring the large bodies' shapes; with the
deferral off the test passes). The ground the plane read at that tuft is the
real ground, so I read this as the test depending on which tuft comes first,
not a wrong collision, but I have not proved it. It is the thing to look at
if the deferral is kept. `test_aqueduct_isle_look` fails on the base too
(plants over open turf). `RuinKit.triangles` counts the `Growth` child of a
levelled "Mesh", so an LOD'd ruin's total is unchanged; a levelled "Mesh"
now has one surface (the stone), growth in a child (no test run reads a
levelled mesh's second surface).
