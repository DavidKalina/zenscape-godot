# The generated layer, round 15: city crossings (2026-10-15)

> Branch `layer/city-crossings-variety`, cut from `roguelike` at d5980423.
> A prototype round: smoke checks and throwaway drivers in `scratch/`, no new
> tests.

The user found the links between city places "very tedious": every one was
a run of column tops or a plain causeway beam. This round gives underground
edges a family of crossing kinds. Each kind is a small place you can read
from the rim, drawn in the city kit's basalt, and sized from the
wanderer's real motor (`KitMotif.pilot()`: `scripts/pilot_motor.gd` at
WorldScale's size). No metres are copied.

## Play

```sh
<godot> --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --world=under [--seed=N] [--region=1|2|3]
<godot> --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --world=under --knob=city_crossings=plain   # round 14's crossings, for A/B
```

Seed 1 (sprawl, region 1) has these crossings:

- a broken causeway off the landing (`face0`);
- the hard piers on the greed branch (`face3`);
- a spillway from the procession down to the colonnade (edge 3).

## The kinds

The plan's shapes are in `scripts/roguelike/city_ways.gd`. The geometry is
in the new kit file `scripts/city_kit_ways.gd`, and
`scripts/roguelike/city_crossings.gd` hands each edge to it. Each layer's
roots go out as one HangingRoots batch.

| Kind | What it is | Its numbers (wanderer 1.0) |
|---|---|---|
| **slide** (the spillway, the mercy) | A carved channel on hex piers. It runs downhill from the lip in banked bends: either an S (+b, -2b, +b with b = 28-40°) or a swerve (+b, -b with b = 38-55°). The bends sum to zero, so it leaves along the edge's way. You crouch-slide it on the motor's own surf. It ends in a flat run-out onto the far rim. | **Grade** 13-17°: steeper than SLIDE_FROM (10°), so a crouch surfs, and gentler than SLOPE_SLOW (22°), so you can walk back up it. **Bend radius** = surf top² / 4.2 m/s², which is 22-28 m; the surf top at this grade is 9.7-10.9 m/s. **Bank:** the floor is banked by the pace the motor's surf integrates at each sample, up to 16°. **Trough:** a 2.4 m floor, 38° ramps 0.9 m high (1.5 m on the outside of a bend), and a coping parapet 1.35 × STEP_UP high (0.61 m) that he can't step over. **Run-out:** 0.7 × the surf's stopping distance from the pace at the foot (7-9 m). **Overall:** 55-97 m long, 10-24 m down. |
| **causeway** (the quiet one) | One straight paved deck lip to lip. It has low curbs, some of them missing, a carved fret down each face, and capped joint piers on corbels. | **Length:** 3.4-6 s of his run (16-29 m). **Grade:** -2% to +8%. **Spans:** 1.3-1.7 s of his run between piers. |
| **broken** | The same causeway with beats between whole spans. **gone:** two broken stubs with ragged teeth, and the fallen deck lodged far below. **sagged:** the two halves droop into a cracked V. **slumped:** the span dropped flat between the pier caps. A gone span always has a whole span before it as the run-up. | **gone:** the gap is 0.62-0.7 of a plain running long jump's reach, plus 0.25 × danger-mean (+0.08 on hard). It is never under 1.2 × his small hop. That gives 2.8-3.1 m on region 1 and 3.5-3.9 m at mean 0.7. **sagged:** 9-15°, a dip of 0.6-1.0 m. **slumped:** from his small jump + 0.15 m up to his grab (`jumps[0] + hang_drop + GRAB_LOW`) − 0.3 m, which is 1.1-1.6 m; the danger pushes it toward the grab. |
| **piers** (staggered) | Stacks of eight-sided drums, each a little off and turned from the one below. Their shafts go down into the haze. In the gaps where the hops fit, a low step drum stands to one side: the slow, safe line. | **Count:** 3-5 piers (+1 on hard). **Gap:** 0.7-0.8 of the long jump's reach at the rise, plus 0.12 × mean (+0.12 on hard). It is never under 1.2 × his small hop or 1.05 × his pump, so a hop or a pump falls short. **Rise:** +0.1 to 0.4 m or -0.4 to -1.4 m, alternating. **Top:** at least (reach − gap) + 0.4 + his brake distance from the long jump's pace (1.6 m), which is 2.4-3.4 m across. **Step drum:** 1.9 m across. It is kept only where his running hop lands on it even if he takes off 0.8 m early, and doesn't overshoot it if he takes off at the edge. |
| **stones** | Round 14's column tops, now only an occasional pick. | As before. |

### Picking a kind

`CityWays.order`, for each route edge:

- It draws by weight at the region's danger:

  | Kind | Danger 0 | Danger 1 |
  |---|---|---|
  | slide | 3.2 | 2.6 |
  | causeway | 2.4 | 0.7 |
  | broken | 1.3 | 2.6 |
  | piers | 0.7 | 2.4 |
  | stones | 0.5 | 0.5 |

- The kind laid on the route just before keeps 8% of its weight.
- If the drawn kind won't stand, the rest of the family is tried in its
  drawn order.
- The greed branch's `hard` edge is laid as the hard piers. It keeps the
  name `hard`, so collectibles' rare-on-the-last-stone still works.
- The exit chain (layer_sprawl) is unchanged: stones, bridge, cannon.

### The plan's contract

These are kept:

- Edges have the same keys. The family adds `spans`, `chute` and `flank`
  only when it lays one of its kinds.
- The piers and step drums are `stones` entries marked `pier` or `step`.
- `flank` holds extra corridor samples off the walked line: the
  spillway's walls, and the step drums' lines. `_corridor_clear`,
  `_crosses` and `_covers_edges` read `path` + `flank`.
- `piers` and `broken` want the same rim run-up (1.5 m) that stones do.
- The knob is `city_crossings` (`varied` by default; `plain` gives round 14's
  crossings).

## What's proven

**Plans: the sky is unchanged.** I compared `LayerPlan.describe` before and
after on seeds 1-5, sprawl and ring, with `--world=sky`: 10 of 10 are
byte-identical. Underground with `--knob=city_crossings=plain` also matches
round 14 byte for byte (seeds 1-4, sprawl).

**Plans underground.** `tools/sweep.py tools/layer_dump.gd --seed 1..10
--shape sprawl,ring --knob world=under --knob region=1,2,3`: all 60 lay,
with no problems. Route edges by kind (gulfs left out):

| Region | slide | causeway | broken | piers | stones |
|---|---|---|---|---|---|
| 1 | 9 | 12 | 7 | 0 | 6 |
| 2 | 10 | 4 | 11 | 4 | 5 |
| 3 | 8 | 7 | 8 | 7 | 3 |
| all | **27** | **23** | **26** | **11** | **14** |

- In 3 of the 101 cases, a kind followed the same kind (a fallback, when
  nothing else would stand).
- All 47 greed edges are the hard piers. Some ring plans have no greed
  edge.

**Through the real input, in a yard.** `scratch/ways_yard.gd` stands the
city landing alone in the motif yard, puts one crossing of `--kind` off its
rim (the plan's own shape and drawing), and adds a pad for the far place.
It drives him with the stick, crouch and jump buttons. The sweep is
`--seed 1..6` × slide, causeway, broken, piers, hard: **30 of 30 crossed rim
to rim.**

- **slide:** run onto the head, hold crouch, stick let go (no steering at
  all). He surfs all the way at 9.1-10.4 m/s top pace and is never more
  than 0.9 m off the centreline. A worst case, the stick held straight at
  the far lip the whole way so he carves into the outer wall, stays in at
  2.35 m off the line: the parapet holds him. Before the parapet (a 0.28 m
  curb) the same input flew him over the wall.
- **broken:** the long jump at each gone span lands 1.4-2.0 m onto the far
  stub. A plain running jump falls short (`--nolong`). He climbs each
  slumped lip with a jump and a grab. At mean 0.7 (gaps 3.5-3.9 m, slumps
  up to 1.6 m) it still passes.
- **piers fast:** a long jump at each gap, 7 of 7 seeds. **Hard:** 3 of 3 at
  mean 0.7.
- **piers safe:** small hops only, via the step drums where they stand, 5 of
  5 seeds.

**In real layers** (`--layer` mode, `studies/run_layer.tscn`): he's set
down behind the near lip of the plan's own edge as the generator stood it,
then driven across with the same input. Each crossed rim to rim:

- slide (seed 1);
- broken (seed 1, with two slumps and a gone span);
- hard piers (seed 1, four long jumps);
- causeway (seed 2, region 1);
- piers (seed 1, region 3).

**The walker that stood still** (from the last round). In a city layer,
`run_layer.tick` returns early while `_base_wait` is set, until the
landing stands, and then `respawn()` puts him back at the spawn. The
harness's `open` returned at `walk_ready`, which is about 9 frames earlier.
So a driver's first input was swallowed and its walker was teleported back.
- **Fix:** `run_layer.holding()` (a loading card is up, or the landing
  hasn't stood yet), and `tools/harness/drive.gd` `open` now waits on it.
- **Result:** the layer driver now checks "he walks at once in the layer"
  (1.76 m in 30 frames), and every layer run above passed it.
- **Not fully proven:** with the old harness this exact check still moved
  him 1.2 m, so I haven't reproduced the full stand-still on the
  Lamplighters' Stair. The lost frames and the respawn are the likely
  cause.

**Smoke checks** (`tools/smoke.py studies/run_layer.tscn`), all PASS with
0 errors:

- `--world=under`: sprawl seeds 1-4, ring seeds 1-3, and sprawl 5 at
  `--region=3`;
- `--knob=city_crossings=plain`;
- `--world=sky` (seed 4).

One sweep run of ring 1 showed an exit-time PagedAllocator leak line. Run
on its own, it passed clean.

## Stills

These were taken in the yard with `--underground=haze` (the drivers'
`--shots`). They are local only, because the repo ignores docs images. The
sheets are `captures/ways/sheet4.png` and `sheet3.png` in the round's
worktree, and downscaled copies are in `layer-round15-city-crossings/`. To
take them again:
`python3 tools/drive.py scratch/ways_yard.gd --rendered -- --kind=slide --seed=4 --shots=res://captures/ways --scene-args --underground=haze`
(the driver is in scratch/, uncommitted).

- `slide_causeway.jpg`: the spillway's S from the side, its head from the
  rim (the trough, the coping blocks), and the straight causeway from the
  side and from the rim.
- `broken_piers_slide.jpg`: a broken causeway (gone, sagged and slumped
  spans), looking up at its joint piers, the staggered drum piers with
  their step drums, and the spillway.

How they read by eye:

- From a rim at gameplay range, each one reads as a ruined causeway in the
  city's stone, not as boxes. The spillway's S on its piers is the
  showpiece.
- **Weak spots:**
  - From the rim at eye level the straight causeway is plain (it is
    meant to be quiet).
  - The yard's haze is thinner than a layer's, so pier feet show there.
    They now go 30-60 m down, into the layer's haze.
  - The spillway's floor shows no wear of water. A worn runnel or wet
    staining would sell it as a spillway.

## Models (docs/art/model-budget.md)

Triangles per crossing (the `CityCrossings` mesh, roots not counted):

| Kind | Triangles |
|---|---|
| slide | 7.4-7.8k |
| broken | 3.9-5.0k |
| causeway | 2.3k |
| piers | 0.9k |

A layer of 5-7 crossings is about 15-30k triangles in one mesh. Roots add
one MultiMesh, 120 triangles per strand.

| Trick | Applies? |
|---|---|
| Silhouette geometry | **Yes, used.** Chips on the outline come from the kit's `block` chip planes, ragged teeth on broken ends, and coping blocks. The flat faces get their detail from the Olmec stone shader. |
| Vertex-colour grime | **Yes, used.** Crevice occlusion is in the colour's alpha: ramp feet and soffits are darker, and the new `Mesher.quad` takes a foot height. |
| Import LODs, visibility ranges | **Would apply, not done.** All crossings are one mesh across the whole layer, so nothing culls. Splitting the mesh per edge with a visibility range would leave only 1-2 crossings drawn near him. I estimate 60-80% fewer crossing triangles drawn, maybe 0.1-0.2 ms on the Mac. Cheap to do next. |
| Sculpt and bake | No (procedural kit). |
| Rigid parts on bones | No (nothing moves). |
| Parallax | No (the shader carries the pits). |

## Files

- New: `scripts/roguelike/city_ways.gd` (the plan's shapes and the pick).
- New: `scripts/city_kit_ways.gd` (the kit pieces: span, joint_pier,
  drum_pier, step_drum, chute).
- `scripts/roguelike/layer_plan.gd`:
  - the `city_crossings` knob;
  - the pick on route edges;
  - `_shape` delegates to the family;
  - the hard edge becomes the hard piers;
  - the flank samples in the corridor checks;
  - `CityWays.warm`.
- `scripts/roguelike/city_crossings.gd`: draws the new kinds and hangs the
  roots.
- `scripts/city_kit_stone.gd`: `Mesher.quad`, a face for swept strips
  (additive).
- `studies/run_layer.gd`: `holding()`.
- `tools/harness/drive.gd`: `open` waits on `holding()`.

The motif editor isn't touched: no RuinKit, KitLand, flora or piece ids
changed.

## What I couldn't verify

- **A human playing it.** The driver's technique is careful: it stops on
  each top, turns on the spot, and takes a run-up. A player chaining long
  jumps across the piers wasn't driven.
- **The full layer route through these crossings from spawn to gate.** The
  layer driver sets him down at each edge's lip.
- **Ledge catches** as a save on a missed gone span. He did catch the lip
  once in the `--nolong` run, but that isn't checked.
- **Whether the slide's long walk back up** (55-97 m at 13-17°) is tedious
  if you go back.
- **Frame time** of the trimesh chute and the many convex hulls in a dense
  layer.

## Tests this may break (not run)

No tests read the city crossings. `tools/harness/drive.gd` `open` now also
waits on a study's `holding()`. Only run_layer has `holding()`, so other
drivers are unchanged. The round-14 notes still apply: `test_run_layer` and
`test_layer_sprawl` play city layers without `--world`. Their plan-only
(sky) parts are byte-identical.

## Seams and next

- **Per-edge meshes with visibility ranges** (see Models).
- **A shelf under a broken lip, and open joints.** These are in the
  round-4 brainstorm; not built.
- **The exit chain** to the gate still uses stones, bridge and cannon. It
  could draw from the family too.
- **Spillway dressing:** water staining, a dry runnel, a fallen coping
  block in the run-out.
- **The slide only goes down.** An edge that has to climb never draws it.
  Today the draw falls through to the next kind; that could be shown in
  the plan's card.
