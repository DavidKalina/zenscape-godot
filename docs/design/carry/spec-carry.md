# Spec: picking up and carrying things (loop `carry`)

In the wreck cluster (`studies/wreck_cluster.tscn`, `run-wreck-cluster.command`;
its handoff is `docs/design/wreck-cluster/handoff-wreck-colonnade.md`), the
wanderer finds smallish treasures (an idol, a dragon egg, an urn and the
like), picks them up and carries them, and their weight changes how the
wanderer moves. Eventually a treasure gets hitched to the plane; this loop
builds that as its last step.

A sibling loop, `dig` (`iter/dig`, `docs/design/dig/spec-dig.md`), adds a
spade and digging in the same cluster. The two will merge later (a dug-up
treasure you then carry), so keep this loop's code in its own new files and
its edits to shared files (the motor, input setup, `studies/wreck_cluster*.gd`)
small and additive. Leave digging to that loop.

## Done looks like (what the user plays and sees)

1. **Treasures.** 3–5 carriable things in the cluster, each its own small
   model with a clear silhouette that reads as worth carrying: at least a
   small idol (light), an urn or relic (medium) and a dragon egg (heavy).
   They sit where exploring takes you (a niche, a ledge, the top of
   something, an islet's tip), not lying on the strip. Name each through
   `scripts/layout_overrides.gd` as `wreck_cluster/treasure_NN` so the user
   can move them in F4.
2. **Pick up and put down.** One input (a free key plus a gamepad button;
   find the input setup and the motor's bindings and check for clashes)
   lifts the treasure in reach, and pressing it again sets it down in front.
   The lift has weight: anticipation, a heave that matches the load, then a
   carry pose that holds it in both hands or on the shoulder.
3. **Weight.** Each treasure has a weight that the motor feels:
   - light: a little slower, a slightly shorter jump, everything still works;
   - medium: slower, a lower jump, no wall kick or wall run;
   - heavy: a slow trudge, barely a hop, no climbing, ledge grabs, rope swings
     or sail, and the camera and footsteps sell the load.

   Keep the numbers in one place so they're easy to tune. Things you can't do
   while carrying fail visibly (a stagger, a shake of the head), not silently.
4. **Dropping it.** A hard hit (the rune knight, a long fall) knocks the
   treasure out of your hands and it tumbles. It is a body that settles on
   slopes and ledges without jitter, never pushes through walls and never
   launches the player. A treasure that falls off the isle into the sky is
   lost for this deal. That's the stake.
5. **Hitch it to the plane.** Carry a treasure to the parked plane and press
   the input there: it gets strapped on or stowed and stays visibly on the
   plane, flying with it when you take off. How a load changes the plane's
   flight (the `--heavy` work) is out of scope; note it in the trail as open.
   **Spec change:** the treasure doesn't go on the plane itself. The plane
   trails a cargo sling (a net or basket) on a rope. Parked, the sling lies
   on the ground by the plane; carry a treasure to it and press the input to
   load it in. In flight the sling hangs under the plane on its rope and
   swings with the plane's moves, the loaded treasure visible in it.
6. **Re-deal.** N (or Esc, New deal) puts every treasure back at its spot,
   the hitched ones too.

## Out of scope

Throwing, digging (loop `dig`), treasures outside the wreck cluster and
its stretch, committed tests.

## Proof, per task

- The smoke check of `studies/wreck_cluster.tscn` passes.
- Anything played: a throwaway driver through the real play loop and input
  path (`tools/drive.py`; run `python tools/drive.py --api` first), left in
  `scratch/`: walk to a treasure, lift it, walk, try a jump and a wall kick
  under each weight and compare against empty-handed, put it down; get
  knocked and watch it settle; carry one to the plane and hitch it.
- Anything seen: rendered stills or a short capture (`tools/shot.py`,
  `-- --no-title`), looked at before committing. The lift and carry are
  judged in a capture, not a still.
- The lift and carry poses may be procedural on the existing rig for now.
  List them in the trail as stood in: clips authored in Blender come with
  lock-in (AGENTS.md, Animation). Each new model notes the
  `docs/art/model-budget.md` tricks that apply.
- Runs use `--ledger=/tmp/...`; drivers write only to `/tmp` or `scratch/`.
  Don't touch the user's saved layouts.

## Spec change (after task 6): the haul home

The user wants the flight out with a load to be its own adventure. The
cargo sling becomes a bag that grows, can spill, weighs the plane down and
can break it. Built as four more tasks, in this order, each playable:

7. **The stretch.** A mid-length flight out from the cluster (roughly 30–60 s
   at cruise) through open sky with things to hit: floating rocks, broken
   spans, drifting debris, a few gaps and arches to thread. Some of it runs
   over land (low islets or ledges under the line) and some over open sky.
   Any land the plane can reach keeps a clear turf strip long enough to land
   by hand (AGENTS.md). Size gaps from a toy width with
   `WorldScale.opening()`, and name every piece through
   `scripts/layout_overrides.gd` (`wreck_cluster/stretch/<piece>`) so the
   user can move it in F4. In the wreck cluster study, not a new scene.
8. **The bag.** The net becomes a sack that swells with what's in it (size
   from the total weight), and its rope lengthens as it fills, so a full bag
   hangs low and swings wide. No count cap: weight caps it (task 9). The bag
   gets real collision. A hit spills treasure, more the harder the hit;
   spilled treasures fall as loose bodies (task 5's): onto land they come to
   rest where you can land or walk to them and carry them back; over open
   sky they are lost for the deal.
9. **Load.** The bag's weight feeds the plane's weight model (the `--heavy`
   work, `4f30770c` and `59c8bef6`): a longer takeoff roll, a slower climb,
   pull-ups that mush, turns that swing on after the nose. Past a weight the
   plane can't get off the ground. Keep the numbers in one table.
10. **Strain.** Strain builds from the load and from hard moves (tight turns,
    pull-ups, hits) and eases off in calm flight. It shows on the plane, not
    in a meter: creaks, wing flex, a labouring engine, rattling struts. At the
    breaking point a plane part snaps off and the plane must put down (it
    loses power or control enough that flying on isn't possible). The part
    falls like a spill: onto land it can be found there; over open sky it
    goes back to a part spot in the cluster, so a deal is never unwinnable.

Proof as above: the smoke check, a real-input driver per task (fly the
stretch with the stick, not scripted positions, where the task is about
flying), and rendered stills or captures looked at.

## Loop

Model Opus. Cap and budget: the skill's defaults. Size each task so it ends
in something the user can launch or look at, and get to a first playable
carry (one treasure, lift, a slower walk, set down) as early as possible,
then add weights, the rest, dropping and the hitch.
