# Lane spec: wild-kit director (lane `wk-director`)

A lane of loop `wild-kit`. Branch `lane/wk-director`, worktree
`/Users/davidkalina/Documents/Projects/zenscape-wk-director`, branched from
the loop's step 0 (placed sites, in this branch). The loop's spec,
`spec-wild-kit.md`, is background: its **Settled** section holds here. The
master list is `wilderness-kit.md`. Commits:
`ITER(wild-kit): lane director: <task>`, each ending with **Notes for
merge** (every line it touched in a file it didn't create). Cap: the skill's
default.

Other lanes run at the same time (elk, waterfall, uprights). They add kinds
in `scripts/endless/kinds/` and rows in
`scripts/endless/world/wilderness/placed.gd`; this lane needs neither, so
leave both alone.

## Done looks like

1. **The director** (engine, new file, e.g. `scripts/endless/happenings.gd`).
   Moments register with it: a name, where (a predicate: the region, near
   a placed site's handle, over water, in a cloud, and so on), when (an hour
   window from the day cycle; a weather key that is always "clear" until
   weather states exist), how rare (a chance and a cooldown per area, an
   area being a cell of the land of about 1 km), and what it does. One
   moment runs at a time. `--happen=<name>` forces that moment the next time
   its place matches, ignoring chance and cooldown, so the user can see it
   on demand; `--happen=off` turns the director off. Cheap when idle: no
   scans of the world each frame. Rolls come from a seeded RNG, so a replayed
   flight fires the same moments.
2. **Life reacts** (engine, new file): the shared reactions a creature
   declares and the director or a moment calls: flush (up and away), bolt
   (run off away from the plane), look up (turn to track the plane), follow
   (trail along for a while). The waterfowl moment uses flush. Keep it small
   and plain so the elk lane can adopt it later; don't wait on that lane.
   The existing grass flush (`scripts/endless/grass_birds.gd`) stays as it
   is; say in the handoff whether it could move onto the director later.
3. **Moment: the cloud punch.** By day, after some seconds inside a cloud,
   the plane climbs out of its top into sun. A rainbow arcs for a few
   seconds (`scripts/shared/celestial.gd` `rainbow_strength`; nothing sets
   it today), and frost forms on the canopy at the screen's edges and melts
   off over a few seconds (the wet layer `scripts/endless/screen_wet.gd` is
   the pattern). Rare unless forced.
4. **Moment: the waterfowl takeoff.** When the plane takes off from the
   ground near water (the inlet beside the start, any lake), a few ducks or
   a heron on the water nearby run along the surface and lift off away from
   the plane. `scripts/life_models.gd` has a heron to start from;
   `scripts/endless/endless_birds.gd` has the flock birds. The game starts
   beside the inlet, so a session's first takeoff is its natural first
   showing; let it fire there more often than elsewhere.

## Proof

The smoke check of `studies/endless_flight.tscn`. A throwaway driver
through the real play loop that (a) climbs out of a cloud with
`--happen=cloud_punch` and sees the rainbow and frost come and go, (b) takes
off near the inlet and sees the birds run and lift, and (c) without the
force, fires a moment once across two triggers in a row in the same area
(the cooldown holds). Rendered stills of both moments, looked at. Look at:
those stills, and a launch line per moment with `--happen=`.

Suggested order: the director and the cloud punch (one checkpoint), then
life reacts and the waterfowl (a second), then tuning from what reads wrong.
