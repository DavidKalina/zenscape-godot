# The generated layer, round 11: the headless body's routes, and what the world does to him (2026-10-13)

> On `feature/body-routes`, from `feature/layer-bodies` (rounds 9 and 10).
> A prototype. The round was cut short so the world can be reconsidered
> instead (more motifs, a revised kit). The planner is committed switched
> on so the bodies can be played as they are now.

The ask was that the Olmec body never gets stuck: on stairs, on narrow
landings, or in corners, swivelling back and forth. This doc is mostly
about the world: where he does well, where he gets trapped, and what kit
and motif changes would fix it. The planner comes after that.

## Play it

```sh
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2 --knob=spawn_far_share=1   # then B: watch one come up far off
godot --path . res://studies/run_layer.tscn -- --no-title --shape=ring --seed=4
godot --path . res://studies/headless_body_isle.tscn -- --no-title           # the body's own study
```

On Windows, use the same arguments with the Godot 4.7.2 exe, run from the
project folder (or `--path <folder>`).

- **Sprawl 2** has two heads. Head 1's body comes up the stair to the clouds.
  Before this round it dropped onto a stair landing of stepping stones and
  stuck there for good (169 s). It now drops off the landing, drops again
  onto the head's isle, and is whole in 43-49 s.
- **Ring 4** has stair-to-the-clouds cliffs. Its body comes down the stair
  isle to the head.
- **Sprawl 11 and 12** have bell spires cliffs: the worst place for him (see
  below).

## How bodies fared on each motif

These numbers come from a throwaway sweep (`scratch_br/`, uncommitted)
through the real play loop: run_layer's own `_process`, `--fixed-fps 60`,
headless, with each body on its own think, rays and motor (no teleports).
It covered sprawl and ring seeds 1-12, with 4 passes, each starting from a
different cliff in the head's list. That made 120 bodies. Each run lasted
180 s, with natural spawns and the `stale` swap turned off.

- **Stuck** means a 10 s spell inside a 3 m box while not whole.
- **Dither** means 3 or more heading reversals in 8 s inside 4 m while
  walking. Listening sweeps are not counted, so the baseline's swivel
  while listening in a corner shows up as stuck, not as dither.
- The motif is the motif of the isle the body spawned on. Bodies often
  ended up on a neighbouring isle, so read the motif as where the trouble
  started.

| Motif (spawn) | Bodies | Reached head, before | Reached head, now | Median time to reach, before / now | Fell into void, before / now | Bodies stuck at least once, before / now |
|---|---|---|---|---|---|---|
| Sundered gorge | 78 | 47 (60%) | 56 (72%) | 34 s / 36 s | 16 / 6 | 29 / 28 |
| Stair to the clouds | 27 | 26 (96%) | 27 (100%) | 48 s / 43 s | 0 / 0 | 2 / 10 |
| Bell spires | 11 | 4 (36%) | 9 (82%) | 89 s / 88 s | 0 / 0 | 11 / 10 |
| Aqueduct isle | 4 | 4 (100%) | 4 (100%) | 31 s / 30 s | 0 / 0 | 1 / 0 |
| **All** | **120** | **81 (68%)** | **96 (80%)** | 39 s / 40 s | **16 / 6** | 43 / 48 |

Over all bodies, stuck time went from 2078 s before to 2491 s now, and
dithering bodies went from 0 to 8. Most of the extra stuck time is the
planner's own stops: a leg it can't make costs a short re-plan beat (see
"Not fixed").

### What works for him, and why

- **Big open tops** (the aqueduct isle, the gorge's broad halves, the
  head's turf rounds): 100% reached. There's room on every side for his
  footprint (about 4.4 m wide and 2.4 m deep, with his neck 6.7 m up), so
  every climb tops out somewhere he fits and he walks straight on.
- **The stair to the clouds as a place to come down from**: 96-100%. The
  stair isle stands over the head's isle, and its rims drop clear onto
  broad ground below. He gets there by dropping, not by walking the stair.
  The trouble on it comes only when a drop lands him on a stair landing
  (below).
- **Cliffs to climb**: a cliff 6-22 m tall with a broad top is the best
  thing in the kit for him. Climb, haul, mantle, and he's standing
  somewhere he fits.

### What traps him, and exactly where

1. **Stair landings and flights narrower than he is (stair to the
   clouds).**
   - Sprawl 2, head 1: the landing at about (-114, 135, 183). It's a
     platform about 9 x 9 m whose only ways on are flights narrower than
     his body.
   - Part of the landing is stepping stones with 1.5 m gaps (no collider
     under his middle). Before this round his floor ray found the gap, so
     he "fell" where he stood, landed with a shockwave, listened and fell
     again, for 169 s.
   - Now his feet span gaps, and he drops off the landing's side instead.
   - Ring 3 at about (-175, 58, 97) and ring 4 at about (-182, 81, 172)
     are the same kind of place: a stair isle's landings, 15-30 m over the
     head.
2. **Bell spires.**
   - Sprawl 12, head 0: around (-359, 91, -69) and (-366, 91, -76).
   - Sprawl 11, head 1: around (-36, 101, 313) and (-42, 101, 305).
   - Sprawl 2, head 1: (-162, 168, 152).
   - In the baseline, 11 of 11 spires bodies were stuck at least once.
     The tops between the spires are pockets about one body wide. He hops
     back and forth between them (up to 16 jumps in 180 s) without
     getting off them.
   - Now 9 of 11 reach the head, but slowly (median 88 s) and still with
     stuck spells. Every way off is a drop or a jump from a narrow rim.
3. **Spurs and ledges down the gorge's cliffs (sundered gorge).**
   - Ring 1, head 1: (328-397, 27-56, -134 to -158).
   - Ring 9: (-116, 35-41, -311 to -319).
   - Ring 5: (331, 44, 150).
   - These are narrow shelves 2-10 m under a rim. A drop lands him there,
     and the only ways off are a long drop into the void, or a climb back
     to where he came from.
   - Most of the void falls happened here before (16). Now there are 6.
4. **Walker-sized gates and arches.** Sprawl 1, the gate by head 0 at
   about (-277, 129, -171). His shoulders hit the lintel and posts 3.3 m
   up. The arch is thinner than the planner's 1.5 m columns, so it plans
   through it, meets the wall and plans round. That takes 3-5 tries.
5. **Gappy floors**: stepping stones, voussoirs, slatted bridges. Before
   this round his single floor ray at his middle fell through these.
6. **Ruin stairs as walls.** Before this round, any face over 0.77 m at his
   knee was a wall, so ordinary walker stairs (risers of 0.2-0.4 m, rising
   about 1 m in 2 m) read as walls. He either climbed each one or turned
   away. This was the user's "he can't quite go up the stairs". It's fixed
   now (see "What changed").

### Kit and motif changes that would fix each trap

His footprint is 4.4 m wide, 2.4 m deep, with 6.7 m to his neck. A place
he fits is a disc about 3 m across with 7 m of headroom.

- **Stairs he should use: at least 5 m wide, with landings at least 6 x 6
  m.** Riser and tread don't matter to him now (anything rising under
  about 2 m per 2 m he walks). Width does. A flight under 5 m wide is a
  ledge he can't turn on.
  - Option A: widen the stair to the clouds' grand stair to 5-6 m on some
    flights, with 6 m landings at the turns.
  - Option B: mark stairs off-limits to him (see the last bullet), and
    make sure every landing a drop can reach has a drop of its own off it
    onto broad ground.
- **No dead-end landings.** Every landing or ledge more than about 3 m
  above the ground under it needs a clear drop side: open sky to a broad
  floor no more than 22 m down and 12-22 m out. The stepping-stone landing
  on the sprawl 2 stair has one only on its west side.
- **Bell spires: give him a lane.**
  - Either one broad saddle (at least 6 m wide) joining the spire tops to
    the isle's rim, or space the spires so their tops are either joined
    (a gap of 3 m or less) or clearly apart (8-10 m, a clean jump).
  - What traps him is the pockets in between: one body wide, with gaps
    too narrow to leap and too wide to step.
- **Gorge spurs**: either keep shelves under a rim at least 6 m deep (a
  place he fits, with a way on), or make them less than 2 m deep so
  nothing lands on them.
  - Alternatively, keep the body's drops off any shelf under the rim (the
    `drop_under` rule does a rough version of this).
- **Gates and arches**: walker-sized gates (under about 7 m clear) need a
  way round at least 5 m wide, or he needs to know they're his walls. The
  kit could tag gate and arch colliders so the body's reads count them as
  solid to its neck.
- **Gappy floors**: bridges, stepping stones and voussoirs are walker
  routes, not his. Tag them so his reads skip them (or count them as
  void).
- **Mark what's his.** The cheapest fix overall is a collision layer or
  group for "body ground" (broad turf, cliff tops, his lanes) and
  "walker-only" (stairs, bridges, stones, gates, rails). His rays and the
  route reads would then only see his ground. Every trap above is a
  walker-scale piece he reads as ground.

## What changed (committed)

These changes are in `scripts/enemies/headless_body.gd` and the new
`scripts/enemies/body_routes.gd`.

- **Routes over places he fits** (`body_routes.gd`).
  - The world is read with rays in 1.5 m columns, only where the search
    goes. Each column records its floors and the headroom over each one.
    The reads are shared by every body in the field.
  - A place he fits has 7 m of room overhead, floor within his step all
    round it (3 x 3), and floor between columns (so not stepping stones).
  - His moves:
    - **Walk**: to a place he fits, or along a narrow way (a stair or a
      bridge), which costs 1.8 times as much.
    - **Climb**: up a wall to the first place he fits. A lip he doesn't
      fit on is climbed on from: he mantles onto it against the next
      wall and climbs on (`CLIMB_LINKS`).
    - **Jump**: across a gap to a ledge.
    - **Drop**: down and across to a place he fits, on his own isle or
      another. He now drops further across the deeper he falls
      (`leap_far`, `leap_fall`).
  - Leaps pass over low ledges under the rim, and walls and rims count up
    to 3 columns out (the strip by a rim he doesn't fit on).
  - The search is an A*, stepped 1.5 ms of each frame while he listens.
    Where the head can't be reached, it takes him to the place nearest it
    that can.
- **Following the route.**
  - He turns on the spot to a leg's way before stepping. Once at a leap's
    or climb's start he keeps facing out along its way; before, he turned
    back toward the start and swivelled at the rim.
  - Legs only advance, including past a corner he cut.
  - A wall or edge where the route walks, or a leg not made in
    `leg_slack` s, is banned and he re-plans after a short beat. A wall
    met while walking blocks its columns for later plans.
  - If the best route goes nowhere, he bails: a route down and away (to a
    lower isle). A second time running, he falls back to round 9's
    bearing.
- **Fixes underneath it all.**
  - `step` went from 0.67 m to 1.23 m (unit × 1.1). A riser whose top is
    within 1.6 × step is a stair he walks up, not a wall.
  - His floor reads look past steep faces (rails, lamps) and his feet span
    gaps his middle is over (`_feet_floor`).
  - A mantle onto a lip under a higher wall stands him against that wall,
    not inside it.
  - A fall that doesn't fall (wedged between faces) eases him out.
- The study (`headless_body_isle`) still runs its whole route. With routes,
  he's whole at 157 s against 114 s before: the head starts beyond hearing
  and his wander goals are random. Biasing them toward his old bearing is
  the next small fix.

### Knobs

Body knobs (`--body-knob=` in the study):

- `routes` 1 (0 is round 9's bearing and turns, for comparison)
- `leg_slack` 6 s
- `leap_far` unit × 20
- `leap_fall` 0.6
- `step` unit × 1.1

Constants in `body_routes.gd`:

- `CELL` 1.5 m
- `MARGIN` 45 m
- `MOST` 9000
- `APPROACH` 3
- `CLIMB_LINKS` 4
- `NARROW` 1.8
- the move costs

Constants in `headless_body.gd`:

- `STAIR` 1.6
- `ROUTE_US` 1500
- `ROUTE_TURN` 0.4
- `WANDER`
- `BAIL`, `BAIL_NEAR`

## Before and after, by attempt

All rows used the same harness, 180 s per body.

| Attempt | Bodies | Reached head | Fell | Bodies stuck | Notes |
|---|---|---|---|---|---|
| Baseline (round 10) | 120 | 81 (68%) | 16 | 43 | Seeds 1-12 × 4 passes |
| a1: routes, rays ignoring back faces | 56 | 22 | 21 | 40 | Back faces off broke climbing: the isles' sides are only hit as back faces. Reverted |
| a2: back faces on, walls only one column out | 56 | 35 | 2 | 29 | Climbs and leaps from a strip by a rim were never planned |
| a3: approach strip, leaps over low ledges, walls block columns | 56 | 45 | 2 | 24 | 16 bodies dithered at leap starts |
| **a4 (committed)**: heading latch at leg starts, legs advance only | 120 | **96 (80%)** | **6** | 48 | 8 dithering bodies |

For comparison on seeds 1-6 only, the baseline was 56 bodies, 35 reached,
8 fell and 19 stuck.

## Not fixed, and what's unverified

- **Stuck time is up, not down.** Each failed leg costs a re-plan beat,
  and the planner's 1.5 m columns can't see walker-scale pieces: gates,
  arches, stones and rails.
  - The body bumps into them, bans the leg and plans again, sometimes 10-30
    times a run (`fails` in the logs).
  - That is why the world-side fixes above matter more than more planner
    work.
- **8 bodies dithered**, mostly on bell spires and gorge shelves: legs
  failing back and forth between two banned ways.
- **Ray cost.** A body casts 10-50k rays over a 180 s run, for its column
  reads, its "between" checks and its fit tests. That's well within
  headless frames, but no rendered profile was done.
- **Nothing was rendered** and nothing was played by hand. The reads come
  from the headless sweep and per-body probes only.
- The whole body's wander goals are random. The study's body takes longer
  to find a head that's out of hearing.

## Checks run

- A headless import. Then `run_layer` (sprawl 2 for 1500 frames, and ring 1
  and sprawl 2 for 400 frames each) and the body's study for 400 frames,
  with no script errors. The sweep's 120 bodies ran with no script errors.
- The study's full route: a natural spawn, then whole at 157 s, then G.
- No suite run. No new tests.

## Existing tests

None reference the body, its knobs or `body_routes.gd`.
`tests/test_run_layer.gd` and `tests/test_layer_sprawl.gd` build layers but
don't step bodies. None should break, but none were run.

## Worth keeping from the planner

- The column reads with room overhead, the "fits" test, the stair-as-riser
  fix, the feet spanning gaps, the mantle clamp, and the heading latch.
  These are useful whatever the world becomes.
- Drops across onto another isle (`leap_far`) do what the user asked
  for. He leaps from above onto a lower isle when that's the way.
- If the kit gets a "body ground" layer, the planner gets much simpler: no
  narrow ways, no blocked columns, and far fewer re-plans.
