# The generated layer, round 8: the inhaler head and the turrets in the generator (2026-10-13)

> On `roguelike`, after the inhaler head (inhaler-head.md) and the ring
> (layer-round7-ring.md). The turrets are round 6's gust-arrow perches
> (layer-round6-hazards.md).

The user: "We've got a generator, and a new enemy. The olmec head. We've
also got turrets. Let's work on getting the generator to place the enemies."

## Run it

```sh
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
godot --path . res://studies/run_layer.tscn -- --no-title --shape=ring --seed=1
```

Knob: `--knob=heads=<n>` (default -1 rolls 1-2; 0 none; n as many as fit,
one per isle). `--knob=arrows=<n>` now works in the ring too.

Good seeds (headless plans):

| Shape, seed | Heads |
|---|---|
| sprawl 2 | 2: sundered gorge (isle 7), stair to the clouds (isle 5) |
| sprawl 8 | 2: stair to the clouds (5), sundered gorge (8) |
| ring 1 | 2: stair to the clouds (3), sundered gorge (5) |
| sprawl 1, 3-7; ring 2-8 | 1 each |

Every seed tried (sprawl 1-8, ring 1-8) gets at least one head.

## What was placed where

**`scripts/roguelike/layer_enemies.gd`** (new). It plans the heads as data
and builds them on the stage.

- `lay(plan, attempt)` runs after the hazards in LayerSprawl `core` and in
  LayerRing `core`, so the heads keep clear of the turrets.
- **Where a head goes.** Every clear spot (3 m+ of room) on every isle is
  tried. From each spot, the ground the head can ride is flood-filled in
  1.5 m cells, out to about 16 m. A cell is open when:
  - the head finds turf under its middle the same way its own `ground_at`
    does;
  - nothing stands inside its 3.5 m-wide body between its chin and its
    crown;
  - the turf rises no more than 1.6 m from the last cell.

  It may also go up to 3 cells (4.5 m) out over the void past a rim and
  keep the last turf's height there, like the study's round past the east
  rim.
- **Its round.** Up to 5 points, picked far apart (at least 5.4 m) on that
  open ground. Every leg is a straight line over open cells, and the loop
  is at least 23 m long. At most 35 % of it may be over the void.
- **Keeps.**
  - Its body over every leg stays clear of the edges' paths, the ride
    tubes, the piers and the cannons (LayerHazards `_lumps_clear`).
  - Every leg stays 12 m from a turret's perch and from where it fires.
  - The spot is 30 m from the spawn (past its sight), 16 m from the gate,
    22 m from the ram and 10 m from the rune perch.
  - Heads are 60 m apart, one per isle.
- **Which rounds win.** The longest rounds go first, with a bonus for one
  that goes out over the void. The base (the aqueduct isle, where you
  start) comes last.
- **On the stage.** `dress` spawns the heads into the stage's own
  EnemyField, next to the ram, so they are stepped, reset and freed with
  it. The stage hides the figure while a head holds you. The head's air is
  chained onto the sail's wind (`motor.air`) and the plane's (`plane_air`),
  as in the study, and unhooked when the stage goes. The study's
  placeholder synth sounds are wired through the field's `sound_hook`.
- **The card** gets a line, e.g. `Inhaler heads: 7 sundered gorge (p4); 5
  stair clouds (p0)`.

Which isles take one: almost always the sundered gorge (its open floor),
often the stair to the clouds, and the aqueduct base where nothing else
fits. The bell spires, the colonnade spine and the broken ring are too
crowded for a 3.5 m head with 1.2 m of chin room. None of them had a round.

### The turrets in the ring

LayerRing `core` now calls `LayerHazards.lay`, so a ring gets 3-5 gust-arrow
perches too: ground perches off unused rims, and edge perches on the greed
branch's stones. The ring has no exit chain, so it gets no chain perches
and no viaduct. A forced `viaduct=1` is ignored there rather than redrawing
forever.

### Small edits to shared files

- `layer_plan.gd`: the `heads` knob in `KNOBS`.
- `layer_sprawl.gd`: `LayerEnemies.lay` after the hazards; the card line.
- `layer_ring.gd`: `LayerHazards.lay` and `LayerEnemies.lay` before the
  spawn's view; the hazards and heads card lines.
- `layer_stage.gd`: `heads`, built after the ram; the figure hidden while
  held.
- `studies/run_layer.gd`: the knobs in the header comment.

## Checks done (headless)

- Import: clean.
- Plans: sprawl 1-8 and ring 1-8 all lay with no new problems. The heads
  cost 0.3-1 s a plan in this container, against 2-55 s for the plan
  itself here.
- Smoke: `run_layer.tscn --shape=sprawl --seed=2` and `--shape=ring
  --seed=1` for 600 frames, no script errors.
- Throwaway play check through the real loop (`tools/_tmp_head_play.gd`,
  not committed; the stick through `Input.action_press`), sprawl seed 2:
  - Both planned heads stood in the stage's EnemyField.
  - **Drift, 40 s each:**
    - The gorge's head stayed within 15 m of its spot, its chin 1.1-1.6 m
      over the turf (its hover and bob). It never touched stone.
    - The stair's head stayed within 12 m. Its chin went 0.6-5.9 m over
      the turf: it rode over a drop on its round and settled back. Worth
      a look windowed.
  - **Stood 7 m in its way:**
    - It noticed and told, then inhaled at 1.4 s and gulped him at 2.5 s
      (figure hidden). It blasted at 3.5 s.
    - The blast threw him 194 m off the gorge into the void. That ended
      the run and laid a new layer.
  - **Ran away when it told:** he escaped with no gulp. The inhale ended
    at 3.6 s with him 23 m off. (The script then held the stick for 14 s
    and ran him off the far rim. That was the script, not the head.)

## Unverified

- **The look**: nothing was run windowed. How a 3.4 m head reads drifting
  over the gorge's floor next to the painted ruins hasn't been seen.
- **The blast is deadly in a layer.** The head blows you about 27 m out
  along its face. On the gorge that put the wanderer off the isle and into
  the void (the run's end). In the study it threw you back onto the isle
  or off the south rim. Options: aim the blast inland (face the isle's
  middle before blasting), shorten `blast_out` in layers, or keep it and
  rely on the sail.
- The sail and plane pull through `motor.air` / `plane_air` hasn't been
  felt (as in the study).
- Rounds keep off the edges' paths by their body, but its pull reaches 13
  m and it sees 14.6 m, so a head can still catch you on the stones or a
  bridge that leaves its isle.

## Tests this breaks (not run; prototype round)

- `tests/test_layer_sprawl.gd` (slow): its driven crossings now share the
  isles with 1-2 heads that can gulp and blast the driver. It needs
  `heads=0` (and `arrows=0`, as round 6 noted) or to learn about them. Its
  plan numbers don't shift: the heads use their own rng and change nothing
  else in the plan.
- `tests/test_run_layer.gd` uses round 3's shape, which lays no heads, so
  it should be unaffected.
