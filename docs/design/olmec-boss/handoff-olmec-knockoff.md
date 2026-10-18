# Handoff: the Olmec fight, stomp and knock-off (loop `olmec-knockoff`)

Spec: `spec-olmec-knockoff.md` beside this. Trail:
`git log --grep='^ITER(olmec-knockoff)'`.

## Play it

- `./run-olmec-field.command`: the whole fight from phase 1.
- `-- --phase=2`: the body whole. `-- --knocked=N` (0..2): phase 2 already
  knocked off N times (cracked, one-armed); R restarts the same test state.
- `-- --tilt`: the tilt set piece back in phase 2's mix (out by default,
  kept for a later phase 3). `-- --volley-homing=0`: air balls straight.

## What's built

- **Phase 1, the head:** only a ground pound on its crown counts (a glint
  marks it); three stomps end the phase. Gust shots and slams beside it
  flare the glint and puff dust; a gust still breaks an absorb.
  (`scripts/olmec_boss/boss_head.gd`)
- **Phase 2, the body:** only a side slam into his back (within ~63° of
  dead behind) counts; front and side hits glance. Bait the charge, take
  his overrun skid, get behind. A back hit shoves him ~3.5 m with the
  `back_hit` clip. (`scripts/olmec_boss/boss_body.gd`)
- **The edge:** shoved to the rim he teeters (`teeter_catch`, `teeter`,
  ~2.7 s); a second back slam takes him over (`topple`), else he steps
  back (`teeter_back`). He leaps back up (`rim_leap`) and lands heavy with
  a shockwave (`rim_land`), angrier each time. Mid-field a back hit only
  cracks him.
- **Coming back cracked:** after 1, the cracked head
  (`assets/models/inhaler_head_cracked.glb`); after 2, the right arm snaps
  off on landing as three rubble blocks, his swat is left-only and his
  charge pulls right.
- **The finish:** the third knock-off crumbles him at the rim top; a light
  column grows in the heap and the rune bursts out, rises and settles
  clear of the rubble; walk into it. (`scripts/olmec_boss/olmec_rune.gd`)
- **Homing volleys:** the Olmec's air balls bend after the wanderer (a
  limited, fading turn, straight for the last 8 m); opt-in on
  `scripts/dragon_air_blast.gd`, so the dragon and gust shot are as before.
  (`scripts/olmec_boss/puffs.gd` knobs, `--volley-*` flags)
- **Art:** seven new body clips and the two damage states, authored in
  `art/blender/headless_body/` and the head's builder (`--cracked`).
- **Grass:** the field grows the aqueduct isle's carpet
  (`studies/aqueduct_isle_flora.gd` `carpeted`); other isle studies still
  grow drifts.
- **Card:** phase, stomps or knock-offs, his damage, his state.

## Stood in / open

- Untuned, for the user's play: stomp squash, reel and bounce; back-hit
  angle, shove and lurch; edge distance and teeter length; leap and
  shockwave size; anger per knock-off; the charge pull (about 2 m over a
  23 m charge, maybe too strong); homing numbers; the rune's seam timing
  and light.
- The teeter's windmill is unseen side-on (the cloud layer fills shots at
  rim height); judge it in play.
- The cracked face reads only in light.
- No backward topple; a third damage state (torso split) waits for phase 3.
- Falling off the field restarts the whole fight (as before this loop).
- Checks were smoke and throwaway drivers in `scratch/`; no committed tests
  (prototyping).
