# Handoff: the greed run on the crag reach

Loop `greed-run` (spec: `spec-greed-run.md`), branch `iter/greed-run`.
Trail: `git log --grep='^ITER(greed-run)'`.

## Play it

`./run-greed-run.command` (the crag reach with `--greed-run`, on a
throwaway ledger in /tmp). Knobs after `--`: `--greed-brood=N` (default
50), `--greed-olmec=N` (default 200; 90 brings him after three pieces near
the plane), `--brood-count=N` (12), `--no-brood`.

## The run

- **Start:** beside the parked plane, the empty bag on his back, the rope.
- **Loot:** 12 pieces `greed_run/loot_01..12` (~695 in all), light ones by
  the plane, better ones over the bridge, pillar, aqueduct, knolls and down
  terrace faces. Two anchor posts `greed_run/post_01..02` serve the rope
  pieces on terrace 1 and the east terrace.
- **H (pad up)** switches bag / rope in hand; only the one in hand answers
  E, F and the throw.
- **Greed** (`scripts/greed/greed_meter.gd`): value bagged, each piece once.
  Each bag groans, shakes and drains the light; a corner line says what
  wakes next.
- **Brood** (`greed_run/burrow_01..07`): wake at the brood threshold from
  the three burrows nearest, cling, rip loot out, haul an idle bag off and
  bury it. A buried bag is lost with its loot; one empty spare comes back
  by the plane's hook. They can't touch him once he's flying.
- **Olmec:** comes up a cliff at the Olmec threshold (the `--olmec`
  entrance). A greed-run-only fallback re-enters him on another cliff when
  he's stuck below for 8 s.
- **Banking:** F at the hook hitches the bag (its load is the plane's); F
  again empties it into the plane's keep and puts it back on.
- **End** (`scripts/greed/greed_run.gd`): 250 m clear of the crag in flight
  = Banked; swallowed, thrown off or fallen off = Lost (keep and hitched bag
  kept, his worn bag lost). End screen with banked / lost / time; Enter, R
  or pad A starts a new run.

## Shared files touched (additive)

`studies/crag_reach.gd` (all behind `--greed-run`), `scripts/carry/loot_bag.gd`,
`scripts/rope/climb_rope.gd`, `scripts/brood/bag_brood.gd`, `scripts/pad.gd`
(new `walk_tool` on pad up).

## Open

- loot_09 and loot_10 sit deeper than the 14 m rope; move them in F4 or
  give them posts on ledges.
- The Olmec's entrance can pick a ledged cliff on the main crown (lip near
  (-31.5, 30, 16.3)) and fall below; also true with plain `--olmec-after`.
  The greed run's fallback hides it at the cost of slow arrivals there.
- The angry light reads as hazy rather than menacing.
- The rappel camera sits too close (the rope study's pull-out isn't ported).
- Cosmetic: "Stranded" line under the lost screen; a buried bag's kg stays
  in the readout; the empty spare has no glint; the keep isn't shown at
  the plane.
- Tests: none run. `scripts/pad.gd`'s new pad-up action shares the button
  with the cannon's power-up and may trip a key-clash test.
