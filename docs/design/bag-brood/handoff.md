# Handoff: the brood after the bag (greybox study)

Spec: `docs/design/bag-brood/spec-bag-brood.md`. Built on branch
`iter/bag-brood` (cut from `iter/bag`) over five tasks
(`git log --grep='^ITER(bag-brood)'`). The bag itself is in
`docs/design/bag/handoff.md`.

## Where to play it

`./run-bag-study.command` (or
`godot --path . res://studies/bag_study.tscn -- --no-title`).
`--no-brood` leaves the brood out (the bag alone); `--brood-count=N` sets how
many wake (12 by default).

Three burrows sit in the room's floor, named for the world view (F4):
`bag_study/burrow_1` (upper floor, west by the ledge), `burrow_2` (lower
floor), `burrow_3` (up on the platform). The spade lies just ahead-left of
the start (`bag_study/spade`) under a pale glint and a "spade" tag.

## Controls

The bag's controls are unchanged (E bag a piece, F bag off/on/drag, LMB/T
throw, V shove). New here:

| Key (pad) | What it does |
|---|---|
| Space | shakes clingers and guards off (shaken, they're dazed a while) |
| E (B) | by a ripped piece (on the floor or on a hauler's head): take it back |
| F (d-pad down) | by the bag while they haul it: take it back |
| walk over the spade | take it |
| G (Y) | with the spade, facing a burrow's mound: dig it out |

Running into a crew (over 2 m/s, or landing on them) knocks haulers off.

## What's built

- **The wake** (task 1): the first piece into the bag wakes the brood out of
  the burrows, nearest the bag first, a few at a time; each heaves up out
  of the hole (`StoneGuy.rise_at`). Worn or dragged with loot in it, they
  come for him, cling (slowing him), and shove; a jump shakes them off.
- **The rip** (task 2): while any cling to the worn bag, every 7 s or so
  (faster the more cling) one pulls a piece out (`loot_bag.rip_out`): the
  sack shrinks and the piece hops onto the floor. A crew takes it up and
  carries it to the nearest burrow. The crew goes by its kg (one per 3 kg,
  at least 2) and so does the pace (0.55 light, 0.22 at 12 kg); under 60%
  of the crew left they let it down. A 12 kg piece takes four and one knock
  drops it.
- **The idle bag** (task 3): set down with loot and left 3 s (him 2.5 m off),
  it calls a crew of one per 3 kg (2 to 8), who lift it overhead and haul it
  to the nearest burrow; pace by kg and by crew over the full crew; free
  guys join on the way. Bowled under 60% they drop it; F takes it back
  (`loot_bag.haul_hold/haul_place/haul_free`).
- **The burial and the dig** (task 4): at the burrow the bag or piece is
  buried (`loot_bag.bury/unbury`; pieces hidden, listed in
  `bag_brood.buried`), and one guard (two for the bag) settles on the
  mouth. Near it they cling; while any cling the spade won't dig and a dig
  under way stops (`bag_study.dig_blocked`). Shaken guards stay dazed 2.6 s,
  long enough to dig. The burrows are the dig's spots
  (`scripts/brood/burrow_digs.gd`); the second bite digs the whole pile out:
  the bag hops out toward him, the ripped pieces land round the mouth.
- **Where to dig** (task 5, `scripts/brood/burrow_marks.gd`): a burrow with
  loot in it shows a dark fresh mound over its (filled) mouth that grows
  with the kg buried, a bobbing glint, a thin beam and a "buried N kg" tag
  that reads through walls. Close up: "G dig (face the mound)", "jump: shake
  them off to dig", or "find the spade (by the start) to dig". The first
  burial says which burrow.
- **Going home** (task 5): with nothing to take (no loot on him, no loose
  bag with loot, no ripped piece about) and none on him for 6 s, the free
  ones walk to the nearest burrow and go down (`StoneGuy.sink_at`: step on,
  look round, hop, drop, arms up). Guards follow after 20 s, unless he's at
  their burrow; the mound stays to dig. A piece bagged again wakes as many
  as went down.

All the numbers are named in `scripts/brood/brood_knobs.gd` (BAG_STUDY_COUNT,
RIP_*, BAG_*, GUARD*, PILE_*, TRAIL_RING, HOME_AFTER, GUARD_HOME_AFTER,
SINK_TIME, HOME_DOWN) and `burrow_marks.gd` (the pile, glint, beam, prompt).

## Code

- `scripts/brood/bag_brood.gd`: the bag-mode host, extending
  `brood_host.gd` (`setup_bag(study, burrows)`). `brood_host.gd` is
  untouched, so the wreck cluster and the home isle play as before.
- `scripts/brood/stone_guy.gd`: additive `rise_at`, `sink_at` and the
  states "sink" and "home".
- `scripts/carry/loot_bag.gd`: additive `slow`/`set_slow`, `rip_out`,
  `mouth`, `hauled`/`haul_hold`/`haul_place`/`haul_free`,
  `buried`/`bury`/`unbury`.
- `scripts/dig/dig.gd`: `setup(scene, opts)` takes optional
  `{spade, from_start, spots}` (defaults are the cluster's), reads the
  host's `dig_blocked()` and the spots' `soil_at()` if they have them.
- `studies/bag_study.gd`: the burrows, the brood, the dig and the marks.

## Stood in

- No dig sound in this room (no KitAudio in the study; the dig's effects
  skip sound).
- R only moves him back to the start: it doesn't unbury anything, reset
  guards or call the brood home. `brood.clear()` clears guards but leaves
  `buried`/`bag_in` (a buried bag stays hidden).
- Burrows are greybox mounds with no collider; the hauls go straight-line
  to the nearest burrow (a bag on the east upper floor may go up the ramp to
  the platform's burrow).
- A ripped piece's "N kg" tag stays on its spot, not with the piece.

## Open

- Shoves while he stands still can drift him far (seen in early drivers).
- The idle bag's crew refills from walkers after each knock, so bowling a
  light bag takes many hits; it may feel sticky (BAG_KEEP, or no refill for
  a while after a knock).
- Rip pace (about 4 s a rip with eight on him) and the home timers are
  first guesses from one play.
- No committed tests: this is a prototype. The rounds' throwaway drivers are
  in `scratch/brood_*.gd` (git-ignored).
