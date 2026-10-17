# Spec: the Olmec as a mini boss (loop `olmec-boss`)

The Olmec field (`studies/olmec_field.tscn`, `./run-olmec-field.command`,
handoff `docs/design/olmec-field/handoff.md`) becomes a two-phase mini boss
fight. The Olmec was built to roam open isles; here he lives in this one
arena instead. Changes stay in this study and new files (subclasses, as
`scripts/lock_on/olmec_target.gd` does): the Olmec, head and body elsewhere
(motif yard `--olmec`, headless body isle, inhaler isle) behave as before.

The user said: "Let's add destructible items, pillars, etc. Let's have the
fight open with just his head. Instead of a suck attack, although we can
keep that, he should absorb the air, and then puff out different air-based
attacks. Then when he gets his head, he's now much more mobile, and
dangerous." The attack designs below are ours to pick and tune by play.

## Done looks like

You launch `./run-olmec-field.command` and play this fight:

1. **The arena.** The 80 m field, now with things to break: a ring of
   tall pillars and broken colonnade pieces, a few standing stones, low
   walls or plinths to duck behind. They are cover from his air attacks
   and break when his attacks, his body or a gust shot hit them hard
   enough (crack, then topple and break into rubble that stays). Use the
   kit-breaks hub (`docs/design/kit-breaks/`, `motif_yard.gd` `kit_breaks`,
   RuinKit pieces) rather than a new breaking system. The plane's landing
   run (west side) stays clear of pieces and rubble.
2. **Phase 1: the head alone.** The fight opens with only the head in the
   field; no body yet. It is the lock target (Tab), shot with the gust
   shot (X). It can't walk; it heaves and pivots as it does now.
   - **Absorb.** Its core move: it draws the air in (the existing inhale,
     `scripts/enemies/inhaler_head_air.gd`): grass, dust and loose bits
     stream into its mouth, a light pull on the wanderer, its cheeks/stone
     swell, a clear tell. The old suck-and-gulp stays as one outcome when
     he's caught close.
   - **Puffs.** What it absorbed comes back out as one of several air
     attacks, each with its own tell and a way to beat it:
     - *Gust volley*: three to five dense air balls in a fan (the dragon
       air blast, `scripts/dragon_air_blast.gd`). Sidestep or hide behind
       a pillar (which takes the hit and cracks).
     - *Ground ring*: it slams its jaw and exhales flat; a ring of wind
       rolls out along the turf, flattening the grass. Jump it.
     - *Whirlwind*: it spits a small twister that wanders after the
       wanderer for a few seconds, flinging him if it catches him and
       tearing through pieces in its path.
     - *Long breath*: a sustained cone that pushes him back toward the rim;
       pillars break the stream.
   - Being hit: it knocks the wanderer back, down or into the air (the
     game's existing throw and knock, no health bar unless one already
     exists); the rim and the drop are the real danger.
   - Hits stagger it and can interrupt an absorb. After enough hits it
     cries out, and the body answers.
3. **Phase 2: whole.** The body comes up over the rim (the cliff spawn,
   `scripts/enemies/body_spawner.gd`), crosses to the head (breaking what's
   in its way) and puts it on: a short beat the camera can read. Now he is
   much more mobile and dangerous: he hunts the wanderer, not his head;
   faster, leaps across the field, slams that shock the ground, swats, and
   uses the puff attacks from up high (quicker, aimed while he moves).
   The lock target is the body (head on).
   The user played the arrival and loved it as built, including the lock's
   depth of field blurring the body while it climbs and crosses behind the
   head: keep that blur, it is not a bug to fix. After enough hits he crumbles
   (existing `crumble`).
   **His run and the charge (user's playtest of phase 2):** "I don't like
   him chasing with the outstretched arms. I want more of like a shoulder
   check, him leading with his shoulder." And "add a new attack where he
   just kinda charges after you."
   - *His hunting run, whole:* no arms reaching forward. He leads with a
     shoulder: torso turned a quarter, that shoulder dropped and forward,
     the near arm tucked in, the far arm pumping, head down, heavy
     strides. The reaching arms can stay for the headless body (blind,
     feeling for its head), elsewhere and in the arrival.
   - *The charge:* a new phase 2 attack. Tell: he plants, drops his
     shoulder, scrapes a foot (dust), a held beat. Then he barrels at the
     wanderer in a straight line, fast (well past his hunt pace), steering
     only a little, shoulder first, smashing through arena pieces in his
     path (`arena.hit_at`). A hit throws the wanderer hard. Beat it by
     sidestepping late; if he misses he overruns, skids and stumbles to a
     stop (a recovery window to shoot him). Into a big piece or the rim's
     edge he stops short with a stagger. Mixed in with the slam, bound and
     puffs by distance.
   - *How:* new clips authored in Blender on the body's rig
     (art/blender/headless_body/, exported into
     assets/models/headless_body.glb) per AGENTS.md, Animation: the
     shoulder-led run, the charge tell, the charge run, the overrun skid
     and stumble, the impact stagger. Add clips; don't change or rename
     the existing ones (other scenes use them). Procedural layers on top
     where they help. Judge by eye in rendered captures (a contact sheet
     or short filmstrip of each).
   - *Order:* these come after the flow task (4) and before tuning, as
     two tasks: (5) the shoulder-led run, (6) the charge. Tuning is last.

   **The tilt (user's ask, after the charge):** "He gets to the edge,
   ground slams, and tilts up the arena pretty steeply. You slide toward
   him, build up charge, launch a couple of attacks at him, then he
   releases, the arena goes back up and you're popped in the air, so you
   hang glide around and get back on." While you slide, "attacks are
   coming in and you're sliding left and right, dodging these vertical
   arcs of air." The user picked the slam (not a ledge grab: too awkward
   to animate) and that he can repeat it; the rest is ours.
   - *Start:* in phase 2 he bounds to the rim (never over the plane's
     run), slams, and stays braced there leaning his weight on it: the
     whole field tips toward him, steeply (about 25-30 deg, past what the
     wanderer can walk up: he slides and surfs down, steering left and
     right). Build it as a steep mode on the existing tilt
     (scripts/enemies/olmec_tilt.gd: today it caps at 9 deg and a field
     this size only groans), additive so its other users are unchanged.
     The camera reads it: the field tipped, him braced at the low edge.
   - *The slide:* the wanderer is carried down toward him. Loose rubble
     and toppled pieces slide too. He fires vertical arcs of air (blades
     of wind standing on edge, a crescent, sweeping up the slope at the
     wanderer, a few at a time with gaps) to dodge by steering left and
     right. A hit knocks him back up the slope or sideways, not off.
   - *The counter:* sliding fills the gust charge (the wind gauge already
     charges from slides); 2-3 gust shots into him while braced break
     his brace. If the wanderer slides past him off the low edge, he
     falls and glides back (the cost is the lost chance, the fall).
   - *The release:* his brace breaks, he staggers back off the rim and
     drops out of sight, the field springs back up and overshoots, and
     the snap flings the wanderer high into the air: he glides (the
     pocket sail) round and lands back on. The Olmec climbs back up the
     rim as in his arrival (the beat the user liked) and the fight goes on.
   - *Repeat:* first at 3 of his 8 hits, then again no sooner than about
     40 s later, only from phase 2. A flag starts it at once for testing
     (e.g. `--tilt-now`).
   - *User's playtest of (8), "solid", three fixes (task 10, right after
     (9), before tuning):*
     1. Slide about 10% faster while the field is tipped (the cap step 8
        set, 8.5 m/s, to about 9.4; the arcs' timing kept fair).
     2. The grass lifts off the ground when the field tips: the blades
        float detached from the tipped turf. They must stay rooted on
        the turf through the tilt, the snap and back to level (the
        grass/flora multimeshes follow the turf's pose).
     3. The debris (pieces and stones sliding off the lane and the loose
        stones from the slam) is "an incredible touch, but it reads a
        bit buggy". Keep it; make it read as real stone sliding: it sits
        on the turf (no floating, sinking or passing through the
        ground), tumbles and slides with weight, no popping, jitter or
        sudden vanishing, and goes over the low edge in view. Film it
        from the play camera and fix what reads wrong.
        What the user saw: "it looked like we were doing some geometry
        trick; at different angles they looked like cutouts, like 3/4 of
        the item was missing texture." Likely open, uncapped or
        single-sided meshes (the break's pre-cut chunks with their cut
        faces open, back faces culled, or a shell/impostor seen from
        behind or below) that show as hollow from some angles. Every
        debris piece must read solid from every angle, underside and cut
        faces included: find the cause (kit-breaks chunks, the lane
        shove, the slam's loose stones), cap or close it, and prove it
        with stills of the same piece orbited from several angles,
        including from below.
   - *Order:* after the charge, as three tasks: (7) the tilt slam, the
     steep tilt and the slide; (8) the air arcs and the counter (shots
     break his brace); (9) the release, the fling, the glide back and his
     climb back. Tuning is last.

4. **Flow.** R restarts the whole fight from phase 1 with the arena whole.
   The top-left card shows the phase, his hits, and the attack he's on.
   A flag can start in phase 2 (`--phase=2`) for testing.

## Lanes and trunk

Lanes run at once, each in its own worktree branched from `iter/olmec-boss`
as `lane/<part>`, each its own new files plus small additive edits to
`studies/olmec_field.gd`, ending its commit with **Notes for merge**:

- **lane `arena`**: the destructible arena (item 1). Pieces, layout,
  breakage by body contact, by the dragon air blast / gust shot hitting
  them, and an entry point the attacks can call (e.g. `arena.hit_at(point,
  radius, strength)`). Still: the field wide, a pillar breaking.
- **lane `head`**: phase 1 (item 2): the head alone as the lock target, the
  absorb, and at least the gust volley and ground ring; the whirlwind and
  long breath if they fit, else noted. Pieces it hits: call the arena's
  entry point if present, else leave a stub hook. Still: an absorb, each
  puff.

**The trunk** (this loop, after the lanes merge): the remaining puffs; the
body arriving and the head going on (phase 2's beat); phase 2's moveset;
the flow (R, card, `--phase=2`); tuning and final stills.

## Checks every step

- Smoke: `studies/olmec_field.tscn` loads and runs a few hundred frames
  with no script errors (`tools/smoke.py`).
- Played steps: a throwaway driver in `scratch/` through the real input
  (lock with Tab, shoot with X; the pattern:
  `/Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/agent-a5ac9d41967105a62/scratch/olmec_lock.gd`
  and `olmec_lock_far.gd` beside it), left uncommitted.
- Seen steps: rendered stills (`tools/shot.py`, `-- --no-title`), looked at.
- Animation and attack reads are judged by eye in rendered captures.

Cap and budget: the iterate skill's defaults.
