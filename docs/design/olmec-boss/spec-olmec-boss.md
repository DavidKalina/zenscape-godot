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
