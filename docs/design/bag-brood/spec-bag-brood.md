# Spec: the brood after the bag (greybox study)

Loop slug `bag-brood`, branch `iter/bag-brood`, cut from `iter/bag` (the
bag study, `docs/design/bag/handoff.md`). Cap and budget: the skill's
default.

## What it is

The stone brood (`scripts/brood/`: knee-high stone guys that climb faces
but never jump a gap, cling to whoever holds a treasure, and haul loose
treasure home) goes after the wanderer's loot bag in the bag study.

- **They wake** when he starts filling the bag (the first piece in), and
  come up out of **burrows** in the room's floor (not over an isle's rim,
  as now: the room has walls, not void).
- **The worn bag: they pick at it.** They come for him, cling and shove as
  they do now (slowing him; a jump shakes them off, and shaken they're
  dazed). Every so often a clinger **rips a piece of loot out of the bag**
  (the bag's kg drops, the sack shrinks). A small crew carries that piece
  off toward a burrow. He can bowl into a crew or grab the piece back (E),
  but every stop lets more catch up. It's a slow leak, not a sudden loss.
- **The idle bag: they take it whole.** A bag set down and left alone a few
  seconds (not being dragged, him not standing by it) draws a crew sized
  by its kg (about one guy per 3 kg). They lift it and haul it
  Pikmin-style: pace by crew over kg, so a few strain and inch along and
  more speed it up. He takes it back as he takes back a hauled treasure
  now: running into the haulers (each knocked off is dazed; under a few
  left they drop it), or taking the bag's neck (F) from them.
- **The burrow: buried.** A bag or a piece hauled into a burrow is buried
  there and becomes a **dig spot** (the dig mechanic, `scripts/dig/`: the
  spade, `walk_dig` on G / pad Y, its spots, motion and effects). A guard
  or two settle on it. He digs it out to get it back; the pieces ripped out
  earlier are in the same burrow's pile.

The hand-carry treasures and the brood's current behaviour in the other
scenes stay as they are. Keep the new behaviour opt-in for this study
(a host setting, or the study passing what it wants), so
`studies/wreck_cluster.gd` and the home isle play as before.

## Where

`studies/bag_study.tscn` (the bag room), with the brood and dig added:

- two or three burrows in the floor (one on the upper floor, one on the
  lower floor, maybe one up on the platform), named through
  `scripts/layout_overrides.gd` (`bag_study/burrow_N`);
- the spade lying near the start, or simply carried from the start;
- a key or flag to turn the brood off (`--no-brood`, as the brood has now)
  so the bag alone stays playable.

## Done looks like

The user launches `run-bag-study.command` and:

1. bags a piece, and stone guys come up out of the burrows;
2. wearing the bag, they cling and rip pieces out, carried off in small
   crews; he shakes them off and chases a piece back;
3. sets the bag down or throws it, walks off, and a crew sized to its kg
   hauls it toward a burrow; a heavier bag draws more and moves slower; he
   bowls into them or grabs it back;
4. lets a bag reach a burrow, sees it buried, digs it out with the spade
   past a guard or two, and gets the pieces ripped out earlier back too.

## Tasks

One trunk, no lanes:

1. Burrows in the room, and the brood waking out of them on the first
   piece bagged.
2. Clingers ripping loot out of a worn bag; small crews carrying pieces
   off; taking a piece back.
3. The idle bag hauled whole: crew size and pace by kg; taking it back.
4. Buried at the burrow; digging it (and the ripped-out pieces) back out.
5. A light tuning pass from play, then the handoff
   (`docs/design/bag-brood/handoff.md`).

## Rules

- Greybox. Burrows are plain holes or mounds; no dressing.
- Prototype: a smoke check (`tools/smoke.py` on `studies/bag_study.tscn`,
  plus `studies/wreck_cluster.tscn` to show the brood there is unharmed),
  throwaway drivers in `scratch/` through the real play loop
  (`tools/drive.py`), rendered stills (`tools/shot.py`, `-- --no-title`).
  No committed tests, no full suite.
- Changes to shared files (`brood_host.gd`, `stone_guy.gd`,
  `brood_knobs.gd`, `dig/*`, `loot_bag.gd`, `pad.gd`) stay small, additive
  and opt-in. Tunable numbers go in `brood_knobs.gd` or the bag's
  constants, named.

## Task 5: tuning and the handoff (spec change)

The user played rounds 1 to 4: it feels natural, there's real tension
getting away from them as they come, and the speed is good. Keep the feel;
change only these:

- **Show where to dig.** The user didn't find the dig. A burrow holding
  loot must read from a distance: a fresh mound of turned earth that grows
  with what's in it, the loot's glint or a marker and a kg tag over it.
  Close up, a "G dig" prompt (or "find the spade" without it). Make the
  spade easy to find too (a marker or a hint line at the start).
- **They go home.** Today they linger round him. After a while with
  nothing to take (no loot in a worn bag to rip, no idle bag to haul, him
  out of reach for some seconds), they wander back to the nearest burrow
  and go down into it (the rise played in reverse). Guards stay on a
  burrow with loot in it, but go down too after a longer while, leaving
  the mound to dig. Bagging loot again wakes them again.
- **Crew by weight for ripped pieces.** A ripped piece's crew scales with
  its kg like the whole bag's (a 12 kg piece takes more than two, and they
  carry it slower), so heavy pieces are easier to catch.
- **The handoff** (`docs/design/bag-brood/handoff.md`, from the trail):
  what's built, the controls, where to play it, what's stood in (no dig
  sound in this room, R doesn't unbury), what's open.
