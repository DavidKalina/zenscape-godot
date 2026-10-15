# The linger serpent, round 3 (prototype): a solid body

After round 2 the user played the underground city (`run-game.command`,
the round-15 crossings, `--linger-at=90`) and said: "The snake clips into
himself and clips through the terrain still."

Round 3 makes the body look solid. It no longer passes through itself, the
isles' ground, kit stone, pillars, the crossings' columns or the isles'
hanging rock. It keeps its size (about 215 m long, 10 m thick) and round
2's hunt, pace, strikes and cover play. The gating is unchanged:
`RunFeatures.on(&"linger")`, with `--linger=serpent` as the default. No
shared files were touched. All the work is in the linger files, two of
them new.

## What changed

### It settles on what you see, not on the collision

What clips on screen is the drawn stone. Several parts of the layer are
drawn but have no collision:
- the isles' hanging sides and keels (KitLand `ring_sides`)
- the columns' shafts under a crossing's stones
- piers, the city landing's corbel, a hillside's faces

**The shell** (`scripts/roguelike/linger_shell.gd`, new). The serpent keeps
its own physics space, which nothing else in the game sees. It holds every
drawn mesh of the layer within 360 m of him, built as a static trimesh.
- **What is left out.**
  - Small meshes (under 2.2 m).
  - Light, haze, fire, water, grass and the like, by name.
  - Anything that moves: enemies, and any mesh seen to move.
  - A mesh over 60k faces (a toppled colossus's stand-in) stands in as
    its box.
- **How it is built.**
  - The tree is listed once. After that, meshes join as they enter the
    tree (`node_added`), so the layer is followed as it streams in round
    him.
  - Up to 120 new meshes are judged a frame.
  - Big meshes are built in pieces of 2k faces, inside 1.5 ms a frame.
  - Sliver-only meshes are dropped, because Jolt refuses them.
- **Size.** In a city layer: 220-300 meshes and 245-320k triangles.

**The settle** (`scripts/roguelike/linger_settle.gd`, new). It runs every
frame after the rings are laid on the head's way
(`linger_serpent.gd _settle_rings`). It moves each ring off that way as
little as it can, then poses the bones again.
1. **Stone.**
   - Each ring is a ball of its belly's depth (0.86 of its radius, less a
     0.12 m sink for its weight), tested against the shell. The contacts
     push it out.
   - A ring whose middle is at or just under the walkable ground is lifted
     onto it.
   - A ring wholly inside drawn stone goes out the nearest way first: up,
     or across. Examples are a terrace it runs under, a pillar, or an
     isle's rock. It counts as inside when the first face straight up, or
     5 of 8 faces round it, are seen from behind.
   - Contacts that pull every way (its middle inside a column) push it
     out across.
   - Half the rings are tested a frame, within 1.2 ms.
2. **Itself.** Two rings further apart along the body than 22 m that
   overlap (an ellipsoid: its width across, 0.9 of it stacked): the newer
   one, nearer the head, is lifted over the older. A snake crossing its own
   coil lies on it. When one is far under the other, they part sideways.
3. **The drape.**
   - Lifts spread along the body at most 0.42 m per metre, so a ring
     lifted over a lip or a coil takes its neighbours with it in an arch.
   - Sideways pushes are smoothed, and every ring keeps at least its own
     push.
   - A ring that the spread would put into stone of its own keeps its own
     push only.
4. **Time.** Each ring's offset eases to its goal: quickly out of stone
   (18/s, at most 22 m/s), slowly back (3/s, at most 5 m/s). A correction
   never snaps. The settle eases by the real frame even in the lunge,
   whose pose snaps.

**The head.** Three balls along the skull are settled the same way, and
the head, jaw and tongue bones move with them.
- The open jaw's tip is kept on the ground under it (`jaw_limit`), so the
  jaw scrapes and never cuts in.
- The bite is still judged on the head's way, before the settle
  (`way_head`, `way_snout`). Strikes land as in round 2.

### Its way chooses where the body can go

- **Ground: the cliffs' feet** (`linger_nav.gd`). A cell under a step up of
  more than 2.6 m (a terrace's wall, a plinth) costs 4 more. The straight
  chase line never runs along one, so its 10 m flank no longer lies in the
  wall.
- **Ground: built levels.**
  - A cell over another floor with room between (1.5 m or more within
    10 m) is not its way. Examples are a spiral stair's ramp over the turn
    below, or a bridge or arch over the ground.
  - It is still his ground, so he can shelter there and it strikes from
    outside.
  - A solid stone on the ground is not a level, because it has no
    underside of its own.
- **Ground: the head's way.** On the ground the way itself is pushed out
  of drawn stone (a ball of its ride, a little a frame), so the rings that
  follow it are clear.
- **In the air: steering round.** Coiling, climbing (not over the lip) and
  going down (not at the rim), it casts a ball its girth 30 m ahead in the
  shell. When that is blocked, it turns or tilts the least way round that
  is clear. If it is already inside a hollow of stone, it steers out.
  - This is only within 140 m of him and less than 85 m under him.
  - Further out it goes straight, so its pace is kept.
- **The climb.**
  - Of the best 6 rims, it takes the first whose way up out of the void
    and over the lip is clear: no cast blocked, and no point inside drawn
    stone. The low point goes further out (15, 22 or 30 m) where the stone
    under the rim reaches out.
  - It never takes a rim the bake has not finished. It waits up to 6 s
    for his isle's bake to settle, because a half-baked rim lies inside
    the ground.
  - A rim cell baked again for another isle leaves its old isle's rims.
- **The drape.** Of the nearest 5 rims, it takes the one it hangs clear
  from soonest. It hangs 0, 4, 8, 12 or 16 m further out, so it clears a
  landing's corbel, a ledge or a crossing's columns, eased in at 4 m/s.

## Play it

```sh
# the user's way: the game, underground, the serpent from 90 s
./run-game.command --linger-at=90
# straight into a level hunt on the city layer (seed 11's start pad)
godot --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/run_layer.tscn -- --no-title --shape=sprawl --world=under --under-look=torch --seed=11 --linger-at=148
# seed 7's hex landing (it coils on the platform and drapes down its steps)
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --world=under --under-look=torch --seed=7 --linger-at=148
# A/B: round 2's body (no settle, no steering round stone, any rim)
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --world=under --under-look=torch --seed=11 --linger-at=148 --linger-settle=off
```

| Knob | Does |
|---|---|
| `--linger-settle=off` | round 2's body to compare: no settle, no steering round stone in the air, any rim, the cliffs' feet and built levels not avoided (the shell is still built) |
| `--linger-at`, `--linger-pace`, `--linger-scale`, `--linger-chase`, `--linger-debug` | as round 2 |

With `--linger-debug` the log also shows each climb's rim (and whether its
way was clear) and each waypoint reached.

Tuning:
- `linger_settle.gd`: `BALL`, `SINK`, `SELF_ARC`, `REACH_*`, `SLOPE`,
  `RISE*`, `FALL*`, `BUDGET_US`, `ESCAPE_*`.
- `linger_shell.gd`: `NEAR`, `SMALL`, `SKIP`, `HULL_TRIS`, `CHUNK_TRIS`,
  `BUDGET_US`.
- `linger.gd`: `AVOID_*`, `RIM_TRIES`, `CLIMB_OUT`, `DRAPE_OUT`,
  `DRAPE_TRIES`.
- `linger_nav.gd`: `CLIFF_UP`, `CLIFF_COST`, `STACK_DEPTH`, `STACK_GAP`.

## Clipping, before and after

**The probe** is `scratch/clip.gd` (throwaway). It runs the real play loop
with stick input. He flees the serpent (`flee`) or stands, then runs
across each strike (`dodge`). His hearts are refilled so the run lasts.
Every hunting frame (climb, chase, strike, descend) it measures against
the drawn world, the shell:
- **Sunk.** A ring is sunk past 0.3 m if any of these holds:
  - its ball (0.84 of its radius) meets drawn stone that deep;
  - its belly is under the walkable ground;
  - it is wholly inside stone.
- **Self.** A pair of rings more than 22 m apart along it overlaps (an
  ellipsoid: 0.95 of the summed radii across, 0.85 stacked).

**Scenarios.**
- `stay`: he starts where the run puts him, as the user does, and the
  serpent comes for him from 148 s.
- `tp`: he is moved at once to another isle, so it must go down and climb
  again. This is the hardest case.

"off" is `--linger-settle=off`: round 2's body. Seeds are underground
sprawl (`--world=under --under-look=torch`) unless marked ring.

| run | rings sunk / frame | frames with a ring > 1.5 m in | worst (m) | self-overlap pairs / frame | worst self (m) | strikes / hits |
|---|---|---|---|---|---|---|
| seed 11 stay flee, off | 8.78 | 65 % | 7.2 | 1.40 | 6.8 | 4 / 3 |
| seed 11 stay flee, on | 0.22 | 0.5 % | 2.0 | 0.02 | 0.9 | (run ended early) |
| seed 3 stay flee, off | 12.2 | 92 % | 7.7 | 0.96 | 6.4 | 4 / 2 |
| seed 3 stay flee, on | 0.28 | 0.4 % | 2.3 | 0.00 | 0.0 | 1 / 0 |
| seed 7 stay flee, off | 10.6 | 63 % | 4.2 | 0.64 | 4.9 | 6 / 3 |
| seed 7 stay flee, on | 0.09 | 0 % | 1.2 | 0.00 | 0.0 | 1 / 0 |
| seed 21 stay flee, off | 8.40 | 65 % | 5.2 | 0.00 | 0.0 | ended early |
| seed 21 stay flee, on | 0.31 | 1.9 % | 2.8 | 0.07 | 2.5 | 4 / 2 |
| seed 5 stay dodge, off | 9.34 | 72 % | 8.0 | 10.8 | 7.8 | 1 / 0 |
| seed 5 stay dodge, on | 0.43 | 6.0 % | 7.5 | 0.25 | 3.7 | 3 / 0 |
| ring seed 3 stay flee, off | 9.15 | 72 % | 4.0 | 0.01 | 1.5 | ended early |
| ring seed 3 stay flee, on | 0.00 | 0 % | 0.4 | 0.00 | 0.0 | 0 / 0 |
| seed 11 tp big isle, off | 13.6 | 85 % | 10.2 | 0.65 | 6.8 | 2 / 0 |
| seed 11 tp big isle, on | 2.89 | 36 % | 7.2 | 0.00 | 0.9 | 1 / 0 |
| seed 7 tp mid isle, off | 13.5 | 100 % | 8.6 | 7.04 | 7.4 | (ended) |
| seed 7 tp mid isle, on | 1.65 | 34 % | 8.6 | 0.06 | 6.6 | (ended) |
| seed 21 tp small isle, off | 26.1 | 100 % | 16.1 | 19.4 | 7.9 | 0 / 0 |
| seed 21 tp small isle, on | 5.26 | 50 % | 14.5 | 0.00 | 0.6 | 0 / 0 |

- **Strikes and hits.** These vary with the run, because a strike changes
  how the rest of the run plays. In the earlier round of these runs, hits
  were 2, 1, 1 and 2 with the settle on.
- **Ended early.** In the "ended" runs the layer changed or he died before
  the frame count.
- **Smoothness.** This is each frame's worst ring second difference: how
  far a ring's motion jumps.
  - With the settle it is 0.3-1.0 m at the 99th percentile.
  - Round 2 measured 0.3-1.1 m. It is the way's own motion: the settle
    adds none.
  - An earlier version of round 3 snapped corrections in the lunge and
    under a lag cap, at 5-14 m. Both are fixed.
- **By eye.** Rendered stills during real chases, from the play camera and
  close views of the head, the body's middle, the whole body and the worst
  ring, on seeds 11, 3, 7, 21 and 5:
  - **Coils.** It coils on the hex landing's top with one coil lying on
    another.
  - **Drapes.** It drapes over the landing's stepped edge, over stone
    posts (the wanderer under the arch of its body) and over the start
    pad's lip.
  - **Hanging.** It hangs down beside the columns, not through them.
  - The worst views in round 2 showed its body through a column and its
    tail through a spiral stair's ramp. The column case now shows it
    hanging beside the column.
  - The spiral stair's ramps are now off its way (built levels). Its run
    did not go back there, so that case was not captured again.

## Cost

- **Headless chase**, through the real loop at 60 fps:
  - The serpent's whole frame averages 0.95-1.2 ms. Round 2's was
    0.5-0.9 ms, with the shell also building in these runs.
  - The settle averages 0.5-0.55 ms, at worst 1.1 ms (budgeted).
- **Spikes.**
  - The shell's worst single build is about 9 ms: listing a 38k-face
    hillside's faces, once.
  - The first listing of the tree takes about 3 ms, once.
- **Rendered frame**, seed 11 chase, 1440x900 Forward+: 16-25 ms on
  against 19-22 ms off. This is noise-bound (the same scene varied by
  5 ms between runs). The serpent's part is under 2.5 ms.
- **Memory.** About 300k triangles in the private space (a few tens of MB).

## Rough

- **Its climbs onto a far isle** (the `tp` rows) are still the worst case,
  at 2-5 rings a frame. The climb from its coil in the haze, past a
  city landing's hex column or the Kukul coil sculpture, still clips
  where the casts start inside a hollow, or where it is deeper than 85 m
  under him (it goes straight there to keep its pace). In real play, when
  he crosses on foot, it is better: see the `stay` rows, which include its
  climbs onto his isle.
- **Pace.** Avoidance near him slows a climb by a few seconds: one climb
  went from 18.7 s to 21.5 s.
- **The play camera can end up inside its body** when it coils round him
  on a small landing. The view goes brown-black for a moment. This is the
  study's camera, a shared file: not touched.
- **Its rings lean on the drawn mesh.** Collision tops and drawn tops can
  differ by a hand (KitLand turf is drawn a hair under). It lies on what
  is drawn, so its belly may float a little over the collision or sit in
  chipped stone.
- **Built levels.** Bridges, arches and spiral ramps are not its way, so a
  man on a spiral stair is out of its reach. It strikes from outside and
  waits. Arguably good cover play, but a change from round 2.
- **Tests.** No committed tests were added and the full suite was not run.

## Tests it may break

None were run (prototype).
- **Long `run_layer` tests** that stand him in the open with the serpent
  on (`test_run_layer.gd`, long scripted `run_loop` runs). They now carry
  the shell: about 1 ms a frame and some hundred thousand triangles more.
  Timing-budget tests (`## suite: serial`) could see it. Pass
  `--no-linger` there.
- **Tests that read the serpent's head place** (`body.head()`,
  `snout()`). Those are now the settled places; the bite reads
  `way_head()` and `way_snout()`.

## Files

- `scripts/roguelike/linger_shell.gd` (new): the drawn world as its own
  physics space.
- `scripts/roguelike/linger_settle.gd` (new): the rings off stone and off
  their own coils, the head, the jaw on the ground.
- `scripts/roguelike/linger_serpent.gd`: `_settle_rings` (the rings posed
  again on their settled places), the jaw kept on the ground, `way_head`
  and `way_snout`.
- `scripts/roguelike/linger.gd`:
  - steering round stone in the air (`_avoid`) and keeping the ground way
    clear (`_path_clear`)
  - the climb's rim and low point checked
  - the drape's rim chosen and hung clear
  - the bake waited for, the bite judged on the way
  - `--linger-settle=off`
- `scripts/roguelike/linger_nav.gd`: the cliffs' feet, built levels
  (`passable`), `settled(isle)`, `rim_offs`, the stale-rim fix, `under`.

No model geometry changed this round (the head and body meshes are round
2's), so `docs/art/model-budget.md` is not reassessed.
