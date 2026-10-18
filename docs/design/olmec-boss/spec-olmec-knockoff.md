# Spec: the Olmec fight, stomp and knock-off (loop `olmec-knockoff`)

The Olmec field (`studies/olmec_field.tscn`, `./run-olmec-field.command`)
reworked so each phase is won with one of the wanderer's own moves, not the
gust shot. Builds on the fight from loop `olmec-boss`
(`docs/design/olmec-boss/spec-olmec-boss.md`, its handoff beside it): keep
his moveset, the arena, the lock-on and the flow; change how he is beaten.

The user's words: "I'd rather have to use the charge slide slam attack
instead of air blasts. Or doing a ground pound." "Bait him into a charge
attack, while he's regaining composure get behind and charge into him."
"You slam him towards the edge, and he has kinda a losing balance animation.
He falls off and then he jumps back up." "He'd come back cracked. More and
more distorted in the face and body. Maybe losing limbs." "Three is the
classic Mario." "Head alone should be a classic ground slam on his head."
"Take our break-to-find-a-rune effect and maybe make it bigger."

## Done looks like

1. **Phase 1: the head alone, stomped.** The top of the head is the weak
   spot. Only a ground pound (`scripts/slam.gd`) landing on top of it
   counts: a big hit read (hit-stop, shake, chips, the head squashes and
   reels). The wanderer gets the height with the updraft and the jumps he
   already has; the head's puffs stay as the threat to dodge while lining
   up the drop. After a stomp the wanderer is bounced off clear (not left
   standing on it). Gust shots and any other hit no longer hurt it: they
   flare a glint on the crown and puff dust (the kit caches' "not with
   that" language, `scripts/kit_isle/kit_caches.gd`, `kit_cache_glint.gd`),
   and may still stagger or interrupt an absorb. A subtle glint on the
   crown marks the spot. **Three stomps** end phase 1; the body arrives as
   now.
2. **Phase 2: bait, get behind, slam.** His back is the weak spot. Only a
   side slam (`scripts/side_slam.gd`, the charged slide lunge) into his
   back counts; front and side hits glance off (flare and puff, a small
   stagger at most). The way in: bait his shoulder charge, sidestep late,
   and in his overrun recovery (skid, stumble) get behind him and lunge.
   A back hit shoves him a few metres the way he faces and staggers him.
   The ground pound plays no part in phase 2.
3. **The edge.** Shoved to within reach of the rim, he teeters: a
   windmilling, losing-balance beat (a held window). Another back slam in
   it, or failing to recover, takes him over. He drops out of view, and
   after a beat leaps back up over the rim and lands heavy (a shockwave to
   jump), angrier. Not near the rim, a back hit only cracks him and he
   turns on you; so the play is to bait the charge with the rim behind him.
4. **Coming back cracked.** Each knock-off leaves him visibly worse:
   - after 1: face cracked and off-kilter (a brow or eye slipped);
   - after 2: an arm snapped at the shoulder, left on the field as kit
     rubble; his swat one-sided, his charge pulling toward the missing
     side;
   - the third knock-off ends him: he doesn't climb back (or crumbles at
     the top of the rim), and the rune comes out of the break, a bigger
     version of the kit caches' break-to-find (light and chips out of the
     seam, the find rising and settling where the wanderer can take it).
   (A third damage state, torso split and jaw hanging with a faster charge
   and shorter tell, is for when the fight takes more knock-offs or the
   tilt returns as phase 3; not needed for done.)
5. **The tilt is out of phase 2 for now.** His tilt set piece (the rim
   slam that tips the field) stays in the code behind a flag
   (`--tilt` to bring it back into phase 2's mix; `--tilt-now` keeps its
   meaning) for a later phase 3.
6. **Flow.** R restarts from phase 1, arena whole and him uncracked. The
   card shows the phase, stomps (phase 1) or knock-offs (phase 2), and his
   state. `--phase=2` starts in phase 2; a `--knocked=N` flag starts phase
   2 already knocked off N times (to test each damage state).

## Lanes and trunk

**Lane `body-art`** (one agent, its own worktree `lane/olmec-knockoff-art`
branched from `iter/olmec-knockoff`, model Opus): Blender work on the
headless body's rig (`art/blender/headless_body/`, exported into
`assets/models/headless_body.glb`), per AGENTS.md Animation and Models:
- new clips: the teeter (windmilling, losing balance at an edge, a hold
  that can loop), the drop off the edge (tipping over backward/forward),
  the leap back up over a rim and the heavy landing, the back-hit stagger
  (hit from behind, lurching forward);
- damage states for the two knock-offs: a cracked, off-kilter face, and
  the body with one arm gone at the shoulder (a node or mesh that can be
  hidden/swapped, so the arm can be spawned as rubble in-game);
- add clips; don't change or rename existing ones (other scenes use them).
Judge by eye in rendered filmstrips. Ends with **Notes for merge**: the clip
and node names the trunk calls.

**Lane `homing`** (one agent, its own worktree `lane/olmec-knockoff-homing`
branched from `iter/olmec-knockoff`, model Opus; the user's ask: "making the
Olmec's air blasts homing"): the Olmec's air balls (the head's volley,
`scripts/olmec_boss/puffs.gd`, and any the whole body throws) curve after
the wanderer: a limited turn rate, so a late sidestep, a jump or stone
between still beats them, and they never orbit him. Opt-in on
`scripts/dragon_air_blast.gd` (off by default, so the dragon, the gust shot
and every other user fly straight as before). Its edits stay in those files
plus a knob or two; it ends with **Notes for merge**.

**The trunk** (this loop), in order; until the lane lands, trunk steps use
placeholder poses (procedural leans, the existing stumble/stagger clips):
1. Phase 1 stomp: weak spot on the crown, ground pound counts, three
   stomps, gust shots flare and puff only. (First task: the user plays it.)
2. Phase 2 back hits: side slam into his back counts, front/side glance;
   the shove and stagger; the tilt out of the mix behind `--tilt`.
3. The edge: teeter, knock-off, the leap back and heavy landing.
4. Merge the art lane; wire its clips into 2 and 3.
5. Damage states per knock-off (face, arm off as rubble, one-sided
   swat/charge pull), `--knocked=N`.
6. The finish: the third knock-off, the big break-to-find rune.
7. Flow and card; tuning last.

## Checks every step

- Smoke: `studies/olmec_field.tscn` (and `-- --phase=2`) loads and runs a
  few hundred frames with no script errors (`tools/smoke.py`).
- Played steps: a throwaway driver in `scratch/` through the real input
  (`tools/drive.py`; the ground pound is a fresh crouch press in the air,
  the side slam is Q held past its hold with a charge segment), left
  uncommitted.
- Seen steps: rendered stills or filmstrips (`tools/shot.py`, drive.gd
  `film`, `-- --no-title`), looked at.
- Animation and hit reads are judged by eye in rendered captures.

Cap and budget: the iterate skill's defaults.
