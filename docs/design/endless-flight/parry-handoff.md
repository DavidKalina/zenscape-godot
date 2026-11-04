# Parry (prototype round, branch `iter/parry`)

## What was built

- **The parry.** The roll button's roll (the clean roll, or the surge roll on a
  full meter; neither flies any differently) opens a window at its start. A shot
  that will pass within `PARRY_REACH` m of the plane's touch inside that window
  is knocked back at whoever fired it. When the ball's nearest pass falls in the
  first `PERFECT_S` after the press, it's a perfect parry, which pays more and
  holds the freeze a frame longer.
- **The tell.** The ball that will come nearest soonest gets a ring that closes
  onto it. A second ring round the plane on the screen closes too, with a pip
  on the side the ball is coming from, so a ball off the edge of the screen
  still reads. Both turn white and thick while a roll now would parry. A
  whistle rises in pitch as the ball comes on. The rings go grey while the roll
  is locked out.
- **A whiff.** A roll that parries nothing while a ball was closing (within
  `WHIFF_REACH` m of a pass inside `WHIFF_S` s) locks the roll out for
  `WHIFF_LOCK` s after the roll ends. You get a dull clunk and MISS. A press
  while locked is dropped. Nothing else happens.
- **The hit.** A hard freeze of `STOP_FRAMES` frames (time scale
  `STOP_SCALE`), then `SLOW_SCALE` slow motion for `SLOW_S` real seconds, then
  back to normal speed. There is also a camera kick, the speed streaks lifted, a
  white screen flash, a disc flash with a shock ring, and the word PARRY (or
  PERFECT PARRY, xN on a chain).
- **The return.** The ball goes home glowing and homes onto the ship's middle.
  On her hull it throws a muzzle-style blast of fire and smoke, wood debris and
  dust, splinter chunks and two planks on the water, with a crash and a thump.
  A miss (she's gone, or it timed out) splashes.
- **The meter.** Each parry adds `METER_CHUNK` of the one general meter
  (`NearMiss.meter`). Each parry chained within `CHAIN_S` s of the last adds
  `CHAIN_STEP` more again (0.25, 0.34, 0.43: three in a row fill it), and a
  perfect pays `PERFECT_PAY` times. Light flies from the ball into the meter on
  the screen, and the meter takes the points when the light lands (`LIGHT_S`).
- **The interface.** Any projectile can opt in. Its source joins the group
  `parry_source` and answers `parry_shots`, `parry_take`, `parry_aim`,
  `parry_inside`, `parry_moved` and `parry_landed`; each shot carries
  `parry: true` (contract in the header of `scripts/endless/parry.gd`). The
  pirate ship is the only source this round. The burrower has none yet.

## Files

- `scripts/endless/parry.gd`: new. All of the above, including the
  placeholder sounds, which it makes procedurally at runtime: a metal ring from
  bell partials over a click, a low hit from a falling sine and noise, and a
  clunk. The tell's whistle reuses `assets/audio/kit/air-whistle-loop.wav`.
- `scripts/endless/pirate_ship.gd`: balls are tagged `parry`, the ship joins
  the group, and the parry methods plus the hit on her are in the section
  "Parried".
- `studies/endless_flight.gd`: makes the Parry node, calls `parry.before(input)`
  before the surge's step and `parry.step(delta)` before the shots fly
  (`coast.after`), and adds `PARRY_STREAK` to the streaks.
- `scripts/endless/near_miss_hud_handoff.gd`: `meter_point()`, the meter's
  spot on the screen.

## Tuning (constants at the top of `scripts/endless/parry.gd`)

`WINDOW` 0.1 s, `PERFECT_S` 0.045 s, `PARRY_REACH` 4 m, `WHIFF_REACH` 18 m,
`WHIFF_S` 1.0 s, `WHIFF_LOCK` 0.5 s, `STOP_FRAMES` 4 (+`PERFECT_FRAMES` 1),
`STOP_SCALE` 0.02, `SLOW_SCALE` 0.3, `SLOW_S` 0.25, `KICK` (0.045 rad shake,
14 degrees punch), `STREAK_S`, `WHITE_S`, `METER_CHUNK` 0.25, `CHAIN_STEP` 0.35,
`CHAIN_S` 3.2 s, `PERFECT_PAY` 1.4, `LIGHT_S` 0.55, `RETURN_SPEED` 175 m/s,
`TELL_S` 1.1 s, `TELL_ANGLE`, `TELL_RING`. `PARRY_STREAK` is in
`studies/endless_flight.gd`.

## Try it

`--ship-start` starts you 240 m off the first ship's beam, flying her way. Her
hull guns open up within a few seconds. Fly straight, watch the ring round the
plane close, and roll (Z, pad A, left click) as it flashes white.

```
cd /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/agent-aaf301ddad9dc2baf && python3 tools/play.py --no-pull -- --no-title --ship-start --pilot-file=/tmp/parry_pilot.json
```

## Proof

- Smoke check: headless import, `studies/endless_flight.tscn` for 400 frames,
  0 errors.
- Driver `scratch/parry_drive.gd` (uncommitted), run as
  `python3 tools/drive.py scratch/parry_drive.gd -- --scene-args --ship-start --pilot-file=/tmp/parry_pilot.json`.
  It taps the real `fly_roll` 0.07 s before a ball arrives. Result: 3 parries
  (1 to 2 perfect), all 3 sent home onto the ship (`shot_back` 3), and the meter
  went from 0 to 1.0 on a chain. A tap 0.4 s early whiffed and locked the roll
  out: the next press was dropped, and the press after the lock rolled. Time
  scale came back to 1. Headless and rendered both pass.
- Rendered stills of the tell closing, the freeze and slow motion, and the hit
  on the ship were looked at.

## Unverified

- How the freeze, slow motion and camera punch feel in real-time play. Stills
  can't show timing.
- The sounds and their mix. Headless is silent, and no one has listened to the
  generated placeholders.
- Whether the window is fair at 0.1 s with a human's reaction time. The driver
  presses with perfect knowledge.
- Deck-gun lobs coming down. They are parryable by the same test, but the
  driver only met hull shots.
- No existing test is known to break; the suite wasn't run. The ship's ball
  dictionaries gained two keys (`parry`, `r`).

## Harness gaps

- `tools/smoke.py studies/endless_flight.tscn -- --ship-start` reports a
  timeout. Its log reaches the 400-frame RESULT in about 17 s, but the process
  never exits. Main does the same (checked on `affa0e7a`), so it isn't this
  round's doing. The plain smoke passes.
- A still taken mid-effect stalls the frame. A still taken mid-effect stalls the frame, so time-based
effects are clamped to 1/30 s of real time per frame to show in stills.
