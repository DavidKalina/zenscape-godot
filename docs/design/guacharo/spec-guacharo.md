# Spec: guacharo (iterate: two lanes, then a trunk)

The guacharo (`scripts/enemies/guacharo.gd` is its mind, `scripts/enemies/guacharo_look.gd`
its body; the states are in guacharo.gd's header) is the giant oilbird that
hunts the pilot when he's exposed. The user finds all of it weak: its look,
its animation, how it hunts and how readable it is in play. Remake it so it
plays and looks like a real threat. It's judged by playing it in
`studies/flyer_yard.tscn`, and by eye in rendered captures.

## Lane `guacharo-body`: model, rig, clips (branch `lane/guacharo-body`)

1. **A sculpted oilbird.** A Blender build script,
   `art/blender/guacharo/guacharo_build.py`, follows the other creatures'
   (`art/blender/headless_body/`, `art/blender/rim_dragon/`). It makes a
   real guacharo silhouette: a hooked beak, big dark eyes, rufous plumage
   with white spots, long broad wings with fingered primaries, and a fan
   tail. It's sized from the current bird's numbers.
2. **A rig, and clips that meet AGENTS.md's Animation bar** (authored key
   poses, anticipation, squash and stretch, follow-through, holds, weight
   for its size):
   - glide;
   - heavy flap;
   - banked circle;
   - stalk hover with clicks (head bobs);
   - the fold tell: a scream with the beak wide and wings thrown up, then
     folded into a teardrop;
   - stoop;
   - flare with talons forward (the strike);
   - carry: hard beats with a load;
   - pull-out;
   - hurt or flinch.

   Exported to `assets/models/guacharo.glb`.
3. **The body plays the clips.** `guacharo_look.gd` drives them from the
   mind's states, keeping its public calls so guacharo.gd needs no change.
   It layers procedural corrections on top: bank into turns, the head
   tracking the pilot, talons to the real target. The old procedural body
   stays as a fallback only if the glb is missing.
4. **Proof:** rendered captures of each clip (`studies/guacharo_poses.tscn`
   and short flyer-yard captures), looked at and iterated. The model-budget
   tricks are assessed (`docs/art/model-budget.md`).

## Lane `guacharo-hunt`: how it hunts and reads (branch `lane/guacharo-hunt`)

The lane keeps the current body; the timings it settles are the contract
the clips match.

1. **Hunting that reads as fair:**
   - It notices you when you're exposed, and you can tell it has.
   - It stalks where you can see it.
   - It gives one clear tell before every dive.
   - Keeping on gets you hit; a sidestep or turn on the scream dodges it.
   - Cover (stone over your head) breaks the hunt.
   - After a strike or a miss it backs off for a while, rather than
     chaining dives.
   - The snatch-and-drop is escapable with the struggle, and the drop puts
     you somewhere survivable, or over a void that's honestly your fault.

   Tune and fix `guacharo.gd` to that.
2. **Readability:**
   - its shadow, sharper and growing as it closes;
   - sound, as distinct cues for marked, clicking (faster as it commits),
     scream and wingbeats;
   - the tell, which must be the biggest beat;
   - a camera or screen cue, only if the others aren't enough.

   You should always know where it is and why it got you.
3. **Proof:** drive checks through the real play loop and input in the
   flyer yard (`scratch/`, uncommitted):
   - dodging on the scream misses;
   - keeping on is hit;
   - ducking under cover stops the stalk;
   - the struggle frees you;
   - the attack rhythm (time between dives) is measured and reported.

   Plus a few rendered captures of a full attack, looked at.

## Trunk (branch `iter/guacharo`), after both lanes are merged

1. Merge the lanes. The orchestrator does this and joins any shared lines.
2. Match the clips' timings to the hunt's states. In particular the fold
   and scream are the tell's length, and the stoop and strike line up with
   the hit.
3. Short rendered captures of a whole hunt in the flyer yard: circle,
   stalk, tell, dive, dodge, then a hit and a snatch. Look at them and
   iterate.
4. Smoke checks pass: `studies/flyer_yard.tscn`, `studies/guacharo_poses.tscn`,
   and one layer that lays flyers. The handoff lists any existing test the
   change breaks.

## Rules

Prototyping (AGENTS.md): smoke checks plus throwaway drive checks, no new
committed tests, no full suite. Opus for every agent (new model, animation,
enemy feel). Every agent carries an `ITER-BUDGET` line. Each lane runs as
its own short loop if it needs more than one agent. Keep public interfaces
stable: other code (layer_flyers.gd, the Pilgrim's Ladder build) uses the
guacharo.
