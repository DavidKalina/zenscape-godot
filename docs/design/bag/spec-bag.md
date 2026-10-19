# Spec: the loot bag (greybox study)

Loop slug `bag`, branch `iter/bag`. Cap and budget: the skill's default.

## What it is

The wanderer wears a tattered cloth bag. It starts empty, and every
treasure he puts in it makes it heavier. Its weight decides what he can do
with it:

- **Empty or light:** he keeps his whole moveset, with the bag on his back.
- **Heavier:** his walk, run, jump and turn scale down and moves drop off
  (wall, then ledge, sail, rope), the same way a hand-carried treasure does
  it today (`scripts/carry/carry_weights.gd`). Here the scaling follows the
  bag's total kg on a continuous curve, not three classes.
- **Full:** the bag refuses any more. A treasure tried past the cap stays
  where it is, with a clear refusal (a shake of the head, a sound, a short
  line).
- **Set down:** he can take the bag off and leave it on the ground, and
  pick it up again.
- **Drag:** a bag too heavy to wear can be dragged by its neck. He walks
  slowly, it scuffs along the ground and catches on rocks.
- **Wear limit (decided):** a wear limit below the cap (about 18 kg; cap
  24). Worn, the bag fills only up to the wear limit. Set down, he can keep
  putting loot into it on the ground (E by the bag with a piece in reach,
  or carrying a piece to it), up to the cap. A grounded bag over the wear
  limit can't be shouldered again, only dragged (or rolled, thrown when
  light). Under it, he picks it back up.
- **Roll:** on a slope, a shove sends it tumbling downhill as a rolling
  body. It comes to rest at the bottom, where he can pick it up or drag it.
- **Throw:** a light enough bag can be thrown in an arc: over a wall, up
  onto a ledge, across a gap. It lands and stays there.

The bag sits **alongside** the hand-carry in `scripts/carry/`. A big
treasure is still lifted and hugged as it is today. Leave that system
alone, and reuse its numbers and figure tricks where they fit. This round
has one bag. Several bags, and taking a spare one from the plane, come
later. Hitching the bag to the plane is out of scope too.

## Where

A new greybox study, `studies/bag_study.tscn` + `studies/bag_study.gd`,
launched by `run-bag-study.command`. It's an empty room of plain grey
boxes and ramps, with nothing dressed. It has:

- a flat floor where he starts, with 8 to 12 small loot pieces of mixed
  weights scattered around (simple shapes or the existing treasure models;
  enough total weight to hit the cap and go past it);
- ledges and height changes: a low step, a ledge he can climb empty but
  not loaded, and a raised platform;
- a long slope down to a lower floor (the roll test);
- a wall or ledge with loot on top, and a spot on the far side to throw
  the bag over or up to (the throw test);
- some rocks or lips on the lower floor for the drag to catch on.

Use the real wanderer (the same motor, figure and camera as the kit isles,
`scripts/pilot_motor.gd`; see how `studies/kit_isle.gd` and
`scripts/carry/carry_host.gd` attach to it) and the real input path
(`scripts/pad.gd`, keyboard and pad). New controls get a key and a pad
button, with a small on-screen hint line.

## Done looks like

The user launches `run-bag-study.command` and can:

1. walk around with an empty bag and do everything he does now;
2. pick up loot into the bag, see it swell and feel him slow and lose
   moves as it fills, plus a simple readout of the kg and the cap;
3. get refused past the cap;
4. set the bag down, pick it back up, and drag a heavy one;
5. roll it down the slope and find it at the bottom;
6. throw a light one over the wall or up onto the ledge.

## Lanes and trunk

No lanes. It's one trunk, in order. Suggested tasks, each a checkpoint the
user can launch:

1. The room and the wanderer in it, with loot pieces placed (no bag yet).
2. The bag on his back, filling, weight scaling the moves, the cap and its
   refusal.
3. Set down, pick up, drag.
4. Roll down the slope.
5. Throw.
6. A tuning pass from play, then the handoff.

## Rules

- Greybox. Grey boxes, no dressing pass, no new models beyond a simple
  procedural sack (cloth-like, swelling with load; reuse the look of
  `scripts/carry/cargo_sling.gd`'s bag if that's easy).
- Prototype: a smoke check (`tools/smoke.py` on `studies/bag_study.tscn`)
  and throwaway drivers in `scratch/` through the real play loop
  (`tools/drive.py`), rendered stills (`tools/shot.py`, `-- --no-title`).
  No committed tests, no full suite.
- Keep shared files (`pilot_motor.gd`, `pad.gd`, `carry_*`) changes small
  and additive. Existing scenes must play as before.
- The loose bag (rolling, thrown, dropped) is a rigid body on a layer his
  walk doesn't collide with, like the loose treasures in `carry_host.gd`,
  so it can't launch him.
- Name placed pieces through `scripts/layout_overrides.gd`
  (`bag_study/<piece>`) so the user can move them in the world view.
