# The generated layer, round 9: the headless bodies in the generator (2026-10-13)

> On `feature/layer-bodies`, from `roguelike` at 47bb398b. Builds on round 8
> (layer-round8-enemies.md, the heads in the generator) and the body's
> rounds 1-3 (headless-body-round1.md, -round2.md, -round3-anim.md).

The ask: each Olmec head the generator places gets its body. The body
arrives the way the study does it: it spawns on the side of a cliff and
hauls itself over the lip, either on the head's own isle or on a nearby
isle it can actually get to the head from. The user's worry was that a body
gets stuck on one isle, when they picture him going up and down between
isles.

## Run it

```sh
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2
godot --path . res://studies/run_layer.tscn -- --no-title --shape=ring --seed=1
godot --path . res://studies/headless_body_isle.tscn -- --no-title   # the study, unchanged
```

A body comes up a cliff near you once you're walking near one of its
head's cliffs. The rules are the study's (below). The layer's card now
says how many cliffs each head's body has, for example "body up 8 cliffs".

Good seeds:

| Shape, seed | Why |
|---|---|
| sprawl 2 | 2 heads. Head 0's body crosses its gorge (two jumps) and is whole in about 60 s. Head 1's body can come up the **bell spires**, a different isle, 46 m over the head, and drop and jump its way down to it (whole in about 120 s). |
| ring 1 | 2 heads. Head 1 (sundered gorge) is whole in about 57 s. |
| sprawl 3, ring 2 | 1 head each; whole in about 54 s and 70 s. Each also has a cliff on a neighbouring isle that fits its face. |
| sprawl 8 | Head 0 (stair to the clouds): the body comes down off the stairs to the head, whole in about 35 s. |

## What's in

- **`scripts/roguelike/layer_bodies.gd`** (new) plans each head's cliffs
  from the plan's isle occupancy, using 2 m columns, with each isle's
  columns as places of their own.
  - **A cliff** has open sky past a rim, the isle's stone at least 0.75 of
    the body's hang deep under it, and flat ground behind it. It keeps
    clear of the edges' paths, tubes, piers and cannons.
  - **Reachability.** A flood runs backwards from the head's ground over
    the body's moves: walk, climb (up to `climb_max`), drop (up to
    `leap_max` across and `drop_max` down), and jump a gap (up to
    `jump_gap`, `jump_rise`, `jump_sink`). A cliff is kept only if the
    head can be reached from it.
  - Its own isle's cliffs come first, nearest first. At most 10 are kept,
    10 m apart, within 90 m of the head, on isles within 40 m of its isle.
- **`scripts/enemies/body_spawner.gd`** (new) holds the cliff-spawn rules,
  which the study and the generator now share.
  - It spawns once a head has been bodiless for `wait` s.
  - The cliff must be `near`-`far` m from the walker, `level` with his
    feet, in the camera's view, and hidden behind the cliff.
  - Each cliff is fitted to the built face by rays first. A cliff with no
    face is dropped.
  - One body per head. A body that falls under the void is gone, and the
    head's next body comes up.
- **`layer_enemies.gd`** lays the heads.
  - A head candidate whose body has no cliff waits behind those with one.
    It is laid bodiless only if nothing else fits.
  - The stage's `before` and `frame` step the spawner and its camera
    shake.
- **The body** (`headless_body.gd`) has these changes:
  - It knows its own head by its home (`head_home`), so a field can hold
    several heads.
  - It checks a leap's arc before throwing (`_arc_clear`). On the
    generated isles, throws into a far wall used to drop it into the void.
  - A ledge too tall to step but too low for its chest ray is mantled.
  - **New this round: lost.** If it gets no nearer its head for
    `lost_after` (20) s, it wanders any way for `lost_for` (15) s, then
    listens afresh. Before this, the head's bearing often ran into a wall
    or off a drop that was too deep, and it turned back and forth there
    forever (sprawl 2, head 1: 1 m flat from the head but 26 m over it).
  - **New this round, generator only: `drop_under`** (3 walker heads). A
    headless body that isn't lost won't drop more than this under its
    head's ground. Before this, on ring 1 it dropped 14 m onto a spur down
    the cliff with void all round and stood there for good. This is off
    in the study, because the study's own way to the head drops below it
    and climbs back. With the rule on there, the body was whole at 175 s
    instead of 114 s.
- **New this round: `stale`** (120 s, a spawner rule). A headless body that
  hasn't got nearer its head in that long is taken away once it's out of
  the camera's view, and the head's next body comes up a cliff near the
  walker. This is the safety net for spurs and pits the body can't leave.
- `inhaler_head.gd` gained `home()` and `go_home()`. When its body is
  replaced, the head goes home.

## Knobs

- `--knob=bodies=0|1` (default 1): bodies off or on in the generator.
- Body (`HeadlessBody.default_knobs`):
  - `lost_after` 20 s, `lost_for` 15 s.
  - `drop_under`: INF in the study. The generator sets it to
    `unit*3` (`LayerBodies.knobs`).
  - The moves the planner reads are `climb_max`, `drop_max`, `leap_max`
    and `jump_*`.
- Spawner (`BodySpawner.RULES`): `wait`, `near`, `far`, `level`, `view`,
  `hidden`, `natural`, plus the new `stale` (120 s; 0 never). In the study
  these are `--spawn-knob=`.
- Planner (`layer_bodies.gd` constants): `NEAR` 40 m, `CLIFFS_MOST` 10,
  `CLIFF_APART` 10 m, `CLIFF_FAR` 90 m, `FACE_DEPTH` 0.75, `WALK` 1.2 m.

## Reachability: how often a body can't reach its head, and why

I surveyed sprawl 1-8 and ring 1-8: 16 layers and 19 heads.

- **On paper, every head's body has a cliff it can reach the head from:
  19 of 19.** No head was laid bodiless, and the heads are the same ones
  round 8 picked.
- **On the built isles, every head has at least one cliff that fits a real
  face.** 99 of 136 planned cliffs fit. The misses are mostly the
  gorges' "east"/"south" rims and the stair to the clouds' lower rims,
  where the occupancy's rim isn't a face the rays find ("no top" or "no
  face"). The stair-to-the-clouds heads are thin: ring 1 head 0, ring 3,
  ring 8 and sprawl 8 head 0 have only 1-2 fitting cliffs, all on the
  stairs above the head.
- **Single isle: 14 of 19 heads have cliffs only on their own isle.** For
  8 of 19, the flood can't leave the head's isle at all. Why:
  - The isles stand farther apart than the body can cross. It jumps at
    most about 10 m (`jump_gap` 3 head heights) within 5 m of its height,
    and drops at most 12 m across.
  - It can't go up to an isle that isn't joined to its face: it climbs
    only a face it walks into, at most 22 m.
  - The generator's edges between isles (bridges, stepping stones,
    rides) are the walker's, and the body uses none of them.

  So "up and down between isles" happens only where isles touch or stack.
  Five heads have a cliff on another isle: sprawl 2 head 1 (bell spires,
  3 of 3 fit), sprawl 3 (stair, 1 of 2), ring 2 (gorge isle 1, 1 of 1),
  sprawl 5 (bell spires, 0 of 2) and sprawl 8 head 1 (colonnade spine,
  0 of 2). The towers and colonnades rarely give a face to hang on.
  **Cross-isle travel was seen once in play:** on sprawl 2, from the
  bell spires down 56 m onto the head's isle.
- **In play, over 6 heads on 5 layers, every spawned body reached its
  head:** sprawl 2 (both heads), sprawl 3, sprawl 8 head 0, ring 1 head
  1 and ring 2. Before this round's two fixes, 2 of the first 4 got
  stuck for good: ring 1 on a spur, and sprawl 2 head 1 dithering over
  its head. The planner is a coarse grid. It can't see arches or the
  spaces between columns, so a body can still strand itself somewhere it
  didn't plan for. That's what `stale` is for.

A big upward leap (the user's likely fix) would be what turns
single-isle heads into multi-isle ones. It isn't built. It would add a
"leap up" move to the body (`_landing`) and to the planner (`_can`), and
it's the knob that would change the 14 of 19.

## Verified, and not

Verified, all headless:

- An import, then `run_layer` sprawl 2, `run_layer` ring 1 and the body's
  study each loaded and played 400 frames with no script errors.
- Throwaway play-loop checks in `scratch_lb/` (uncommitted), through the
  study's own frame at `--fixed-fps 60`. The walker is set down by a
  cliff and the spawner's natural rules bring the body up (on demand on
  sprawl 8). The walker then parks at the layer's spawn, and the body is
  watched until it's whole.
  - Results are in the table above.
  - The bodies climb, mantle, jump gaps and drop across generated terrain.
- The study check: the natural spawn up "A south" is whole at 114.1 s,
  the same as before this round. G (spawn on demand) still replaces the
  body and sends the head home.
- The planner's cost is 17-145 ms a head, inside the plan's own seconds.

Not verified:

- **Nothing was rendered.** Nobody has seen a body come over a generated
  lip yet, and the camera-hidden rule was only checked by ray.
- The `stale` take-away never fired in these runs (every body reached its
  head), so it hasn't been exercised in play. It uses the same take-away
  the checks already exercise.
- Ring 8's one fitting cliff was never played. The check couldn't find
  ground to stand on behind it.
- **Frame cost:** headless frames ran at about 4-6 ms with one body. The
  body is about 89k triangles and each head has one body, so a layer
  with 2 heads draws about 180k extra triangles when both are up. No
  perf pass was done. A LOD or a lighter mesh for far bodies may be
  worth it later.

## Open questions for the user

1. **The upward leap.** Should bodies leap up onto a higher isle (and the
   planner count it), so they travel between isles more than 5 times in
   19? It isn't small, so it wasn't built.
2. Should the body use the walker's edges, such as bridges and stepping
   stones? That's another route between isles.
3. **`drop_under`.** In the generator, a body won't drop far below its
   head unless it's lost. Do you want the same in the study, where it
   slows the body there (114 s to 175 s)?
4. **`stale`** quietly swaps a stuck body for a fresh one near you. Is
   that OK, or should a stuck body stay where it is?

## Existing tests

None of the tests reference the body, the spawner or the heads' laying.
`tests/test_run_layer.gd` and `tests/test_layer_sprawl.gd` (both
`suite: slow`) build these layers. Every seed tried lays the same heads as
round 8, so they shouldn't break, but neither was run (prototyping: no
suite run unless asked).
