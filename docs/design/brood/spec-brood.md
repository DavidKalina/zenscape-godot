# Spec: the stone brood (loop `brood`)

In the wreck cluster (`studies/wreck_cluster.tscn`, `run-wreck-cluster.command`),
lifting a treasure wakes the isle: a swarm of small stone guys climbs over
the rim and the walls and comes for the treasure. The wanderer gets out by
platforming where they can't follow, hitches the treasure to the plane's
cargo sling and flies off, shaking off any that cling on.

This loop branches off `iter/carry` (`docs/design/carry/spec-carry.md`),
which owns the treasures, lifting, weight, dropping (`scripts/carry/`) and
the cargo sling. Use carry's API; keep this loop's code in its own new
files (`scripts/brood/`) and its edits to carry, the motor and
`studies/wreck_cluster*.gd` small and additive. The two loops merge later.

This round is greybox: plain stone-grey shapes (a squat block body, a
head, stub limbs is plenty). Good looks, Blender models and clips come in a
later round. The motion should still read: a climb, a mantle over an edge,
a scurry.

## Done looks like (what the user plays and sees)

1. **One stone guy.** About knee to hip high on the wanderer (size from
   `scripts/world_scale.gd`). It walks the real terrain and kit pieces,
   climbs walls and cliff faces (slower than the wanderer climbs) and
   mantles over edges and the isle's rim. It **does not jump gaps**: a gap
   sends it down and around, or stops it at the edge. That is how the
   wanderer escapes, so it has to hold.
2. **The brood wakes.** Lifting a treasure wakes them: they come up over
   the isle's rim (and out of nearby ruin walls if that's cheap), a dozen to
   start, fingers and heads first, a short staggered beat, then they come.
   Spawn spots come from the isle's real rim near the treasure, not a
   hand list. Re-deal (N) puts them all away.
3. **They want the treasure.** They head for whoever holds it, and for a
   loose treasure. Reaching the wanderer they grab and shove; a few hanging
   on slow him, enough of them knock the treasure loose (carry's `drop`).
   **No damage**: losing means losing the treasure, not dying. A loose
   treasure gets mobbed: they lift it together and haul it back toward its
   home spot, and the wanderer can chase them down and take it back
   (knock them off it, or lift it from them). Put back home, it rests and
   the brood settles. Keep the numbers (counts, speeds, grab strength) in
   one knobs file.
4. **Numbers.** 30 to 50 at once, chasing and climbing on the real
   terrain, at a frame rate that plays well on the user's Mac. That means a
   cheap body per guy (no full physics body each; shared ray budgets,
   staggered thinking, or a crowd step), which the earlier steps should be
   built for. Measure it rendered (`tools/shot.py` or a short timed run) and
   put the numbers in the trail.
5. **Clingers.** At takeoff with a loaded sling, a few that are close leap
   onto the sling (or the plane) and hang on, visibly. Hard banking, a
   skim near the ground or a cliff, or threading a narrow gap shakes them
   off; they tumble away. While they hang on they drag a little, so you
   want them off. **Spec change:** carry's hitch is now the bag (a sack
   on a rope under the plane whose kg weighs the plane: `iter/carry`
   60eaac4e, 6a0db8b6), not the sling. Clingers grab the bag (or the
   plane), each adding kg to the bag's load through carry's load path, so
   a few of them make the plane sluggish; shedding them gives it back.
   Merge `iter/carry` (6a0db8b6 or later committed) into `iter/brood`
   first. This needs carry's cargo sling: if `iter/carry` has
   committed it by then, merge `iter/carry` into `iter/brood` first; if it
   hasn't, do this task last and abort with that as the blocker.

## Out of scope

Looks beyond greybox, animation clips, the big Olmec, a vault or swap
mechanic, other isles, sound beyond a placeholder, committed tests.

## Proof, per task

- The smoke check of `studies/wreck_cluster.tscn` passes.
- Anything played: a throwaway driver through the real play loop and input
  path (`tools/drive.py`; run `python tools/drive.py --api` first), left in
  `scratch/`: lift a treasure, watch them come, run where they can't follow
  (a gap they must stop at), get mobbed and lose it, take it back, hitch it.
- Anything seen: rendered stills or a short capture (`tools/shot.py`,
  `-- --no-title`), looked at before committing. The swarm's motion
  (climbing, mantling, mobbing) is judged in a capture, not a still.
- Runs use `--ledger=/tmp/...`; drivers write only to `/tmp` or `scratch/`.
  Don't touch the user's saved layouts.

## Loop

Model Opus. Cap and budget: the skill's defaults. Size each task so it ends
in something the user can launch or look at. Get to one stone guy
climbing the real isle first, then a swarm that comes for the treasure,
then mobbing and hauling back, then numbers, then clingers.
