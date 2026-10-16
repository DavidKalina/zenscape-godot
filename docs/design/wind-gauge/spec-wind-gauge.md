# Spec: the wind gauge (loop `wind-gauge`)

Trail prefix: `ITER(wind-gauge):`. Cap: the skill's default. Prototype
round: smoke checks and throwaway play-loop checks, no committed tests.

The main game: `studies/zenscape.tscn -- --no-title`, on foot on the
aqueduct isle. Builds on the `lock-on` loop on this branch (target stone,
R3 lock-on, depth of field, the gust shot on X: `scripts/lock_on/`,
`docs/design/lock-on/handoff-lock-on.md`). The charge is the updraft's
(`scripts/updraft.gd`). No lanes: one trunk.

The user said "try it, whatever you feel", so these choices are ours to
make and the user will judge them by playing. Keep each new rule behind a
const or flag in the file that owns it, so the old behaviour is one
switch away, and keep other scenes that use `Updraft` (character_study,
snag_study) behaving as before unless they opt in.

## What done looks like (what the user plays)

1. **A wind gauge on screen.** A small painterly arc in a lower corner of
   the screen, split into **three segments**, in the isle's look (no hard
   game-UI chrome). It fills as the charge builds, a segment pulses
   softly when it fills, the whole gauge brightens when all three are
   full, and a spent segment visibly empties (a quick flick out). It fades
   down when empty and idle, and up as soon as charge builds. Hidden in
   the title, while flying the plane, and in photo mode.
2. **Charge from the air.** On foot, the gauge builds from moves through
   the air: flips, twirls, wall runs and wall kicks, long jumps, rope
   rides, and airtime at speed. Running and sliding on the ground no
   longer build it. Tune the gains so a few good air moves fill one
   segment and a lively run through the air fills all three. The drain
   after a lull stays, but gentle enough that a held segment survives a
   short walk.
3. **Three unleashes, each spends one segment.**
   - **Updraft:** Q / pad RB, not in a slide: tosses him up, as now, at a
     fixed per-segment strength (chaining three must not launch him off
     into the sky; tune by playing).
   - **Slide boost:** Q / pad RB **while sliding**: the existing forward
     burst (`BURST_*` in updraft.gd) at a fixed per-segment strength, along
     the slide. This replaces the stick-toward-travel rule for picking the
     burst.
   - **Focus blast:** X / pad X with at least one segment: the gust shot
     from the lock-on loop (locked: homes on the target; free: along the
     camera). No segment: X twirls as before.
   - No segment: Q / RB does nothing new (a soft "empty" cue on the gauge
     is welcome).

## Checks per iteration

- Headless import, then `tools/smoke.py studies/zenscape.tscn -- --no-title`:
  PASS.
- A throwaway driver through the real play loop (`tools/drive.py`) with
  real inputs: air moves build charge and ground running does not; each
  unleash spends exactly one segment; the slide boost fires only in a
  slide; the focus blast still reaches the locked stone; three updrafts in
  a row stay within a sane height.
- Rendered stills of the gauge empty, part full, full, and a segment being
  spent (`tools/shot.py`, `-- --no-title`), looked at before committing.

## Out of scope

The shooting pose/recoil, new sounds beyond a small cue, damage, and the
plane's flight HUD.
