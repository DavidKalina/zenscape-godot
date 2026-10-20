# Spec: the greed run on the crag reach (loop `greed-run`)

The first playable run of the game's loop, on one island. Everything it
needs exists in separate scenes; this loop brings them together on the crag
reach and gives the run a start, a pressure and an end.

Read first: `docs/design/crag-reach/olmec-hunt-handoff.md` (the crag reach
and its Olmec), `docs/design/bag-hitch/handoff.md` (the loot bag, hitching
it to the plane, the tally), `docs/design/bag/handoff.md`,
`docs/design/bag-brood/` (the brood after the bag), `docs/design/rope/`
and `docs/design/rope-swing/` (the climbing rope, rappel, beam swing).

## The run, as the user plays it

1. **Start.** `run-greed-run.command` opens the crag reach
   (`studies/crag_reach.tscn -- --no-title --greed-run`, on a throwaway
   ledger in /tmp like `run-bag-hitch.command`). He stands beside the parked
   plane, with the empty loot bag on his back and his climbing rope.
2. **Treasure.** Loot scattered over the crag reach: a few light, easy
   pieces near the plane, better and heavier ones farther out, across the
   rope bridges, on terraces and islets, and down faces where the rope
   (climb or rappel) is the way there and back. Each piece is named
   `greed_run/loot_NN` through `scripts/layout_overrides.gd`, so the user
   can move it in F4. Pieces glint, as in the bag hitch.
3. **Greed.** Each piece bagged raises the isle's anger. The thresholds are
   knobs (`--greed-brood=N`, `--greed-olmec=N`, by value or count, the
   iteration picks and says which):
   - first, the brood come out of burrows on the crag and go for his bag
     (rip loot out, haul an idle bag off);
   - past a higher threshold the Olmec comes up a cliff out of view to hunt
     him (the existing `--olmec-after` entrance, fired by greed instead of
     a timer).
   The player feels the anger rising: a sound, a rumble, a shift in the
   sky or light, something small and readable. No meter UI required; a
   small one is fine if the cue alone doesn't read.
4. **Banking at the plane.** F at the parked plane's rope end hitches the
   bag, as in the bag hitch. What's hitched at the plane is kept: he can
   hitch a load, take the bag back off with it emptied into the plane's
   keep, or otherwise "drop off at the plane and go back for more". Pick the
   simplest version of that which plays clearly and say how it works. Only
   what reaches the plane counts; loot ripped out by the brood or lost on a
   fall is lost unless he picks it up again.
5. **Escape.** He boards and takes off. Clearing the isle (a distance or
   height past the crag, the iteration picks) ends the run as banked.
6. **Death.** If the Olmec kills him (or he falls off the isle with no way
   back, using the crag reach's existing fall rule), the run ends as lost:
   what's already at the plane is kept, what's in his bag is lost.
7. **End screen.** Banked value, what was lost, time taken, and a key to
   start a new run (reloading the scene is fine).

## Glue the loop may add

- The loot bag, its loot and the hitch on the crag reach (from
  `studies/wreck_cluster_loot.gd`, `scripts/carry/*`).
- The brood on the crag (from `scripts/brood/*`, as the bag and bridge
  studies set them up), with burrows placed on the crag's turf.
- The climbing rope on the crag (from the rope study). If the bag's keys
  and the rope's keys clash, add the smallest fix: a two-slot switch
  between bag and rope, shown with a small hint. No general inventory.
- The greed meter, its thresholds and its cue.
- The run's start, banked/lost check, end screen and restart.

## Rules

- Everything behind `--greed-run`. Without it, the crag reach plays as it
  does now (including `--olmec` / `--olmec-after`), and the home base, bag
  hitch, bag, bridge, rope and swing studies play as before.
- Keep the landing turf and the plane's takeoff line clear (AGENTS.md).
  Loot and burrows stay off it.
- Handles: loot, burrows and any new placed piece get stable layout names
  under `greed_run/`.
- Reuse existing systems; new code lives in new files
  (e.g. `studies/crag_reach_greed.gd`, `scripts/greed/*`) with small,
  additive edits to the shared ones.
- The Olmec's entrance and hunt are used as they are; don't retune his
  moves in this loop.
- Prototype rules: smoke checks, throwaway drivers in `scratch/`, no new
  committed tests, no full suite.

## Out of scope

Flying in from a home base, multiple islands, a shop or quota, co-op, the
Olmec damaging the plane (a later idea the user floated), new art.

## Done looks like

The user launches `run-greed-run.command`, and in one sitting can: walk off
from the plane, find and bag loot across the crag (some of it only by rope),
feel the isle wake, have the brood go for the bag, have the Olmec come for
him once he's greedy, bank loads at the plane, take off and see a banked
end screen, or die and see a lost one, then start again.

## Checks

- Smoke: `studies/crag_reach.tscn` with `--greed-run`, and without it;
  `studies/wreck_cluster.tscn -- --home --loot-bag`.
- Through the real play loop (a scratch driver on `tools/harness/drive.gd`,
  real input): bag a piece, see greed rise, brood wake at its threshold,
  the Olmec arrive at his, hitch and bank, board, take off, banked end
  screen; and a death run reaching the lost end screen.
- Rendered stills of the start, a loot piece, the anger cue, and the end
  screen.

## Loop

Slug `greed-run`, branch `iter/greed-run`, worktree
`../zenscape-greed-run`. Model: Opus. Cap and budget: the skill's
defaults. No lanes: every step builds on the crag reach in order.
