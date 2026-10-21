# Takeoff roll: handoff

Branch `iter/takeoff-roll`. Prototype round, no committed tests.

## Play it

`./run-heist.command`. Board (Space by the plane), hold Boost. The roll
builds slowly. Past about 10 m/s, pull the stick back and it lifts off at
12.5. Don't pull and it rolls off the end and plummets nose down. Let the
nose drop, then pull back once it has the speed, and the wings catch it.

## What changed

All in `scripts/manual_landing.gd` (the dip hint text in `studies/kit_isle.gd`).

- The roll's push fades with speed: `ROLL_PUSH * (1 - (v/ROLL_FADE)^2)`.
- The manual takeoff has its own `LIFT_SPEED`. The sequence's 9.5 in
  `plane_landing.gd` is unchanged.
- The plummet: the nose falls to `DIP_NOSE`, and a sink of its own grows
  at `DIP_FALL` up to `DIP_SINK`, on top of the plane's fall. The wings
  catch only when the speed reaches `max(FLY_SPEED, edge speed + DIP_BUILD)`
  **and** the stick is pulled back, or else after `DIP_MAX`. Until then a
  pull only mushes the nose to `DIP_MUSH` (no speed from it). Once caught,
  the sink fades over `DIP_FADE`.
- There is still no auto-lift and no damage. Every isle uses the same
  rules. The speeds are not scaled by plane size: the landing and stall
  speeds never were, and `world_scale.gd` holds sizes only.

| constant | old | new |
|---|---|---|
| ROLL_PUSH | 6.0 flat | 2.6, fading (ROLL_FADE 16) |
| ROLL_TOP | 11.0 | 13.5 |
| LIFT_SPEED | 9.5 (PlaneLanding's) | 12.5 (own) |
| ROTATE_FROM / ROTATE_RATE | 8.0 / 0.35 | 10.0 / 0.3 |
| SURGE (brake run-up lunge) | 1.0 | 2.5 |
| FLY_SPEED | 12.5 | 15.0, and DIP_BUILD 4.0 over the edge speed |
| DIP_NOSE / EASE_DIP | -0.35 / 0.3 | -0.85 / 0.45 |
| DIP_GAIN | 9.0 | 9.8 |
| dip throttle | PUSH 4.5 | DIP_PUSH 1.0 |
| DIP_MUSH, DIP_FALL, DIP_SINK, DIP_FADE | none | -0.08, 5.0, 12.0, 0.5 |
| DIP_MAX | 3.0 | 4.5 |

## Measured (heist level, --hunt-seed=3, real input, scratch/takeoff/roll.gd)

On the wheels with Boost: 5 m/s at 2.0 s, 8 at 3.4 s, 10 at 4.5 s, 11.5 at
5.6 s, 12.5 at 6.5 s (46 m), 13 at 7.0 s (53 m).

- **a. Home strip, pull at 11.5 m/s:** lifts off at 6.47 s and 46.5 m.
  It is 26 m up 3 s later.
- **b. Home, no pull:** goes off the end at 15.3 s, 166 m, 14.2 m/s. Late
  pull (0.3 s after it had the speed): caught 1.15 s after the edge at
  20.5 m/s, climbing at 2.0 s. Lost 27.5 m, lowest nose -0.63 rad (-36°).
- **c. Same, pulled from the edge:** the nose mushes at -0.08. Caught
  2.27 s after the edge, climbing at 2.8 s. Lost 32.2 m. Slower and
  deeper than b, but it recovers.
- **n. Same, never pulled:** the cap catches it at 4.5 s, at 30 m/s and
  95 m down. It is level at 4.8 s.
- **d. Heist landing (`--no-home`), no pull:** off the edge at 4.9 s, 29 m,
  10.8 m/s. Late pull: caught 1.18 s, climbing 2.07 s, lost 26.1 m, nose
  -36°. With a brake run-up it leaves at 11.5 m/s (the lunge reaches
  5.4 m/s in 1 s, against 2.5 without), so it still plummets. The never-
  pulled fall from there loses 93 m.
- **Aqueduct isle:** pulled, it lifts at 6.45 s and 46.3 m, just inside its
  48 m run. Unpulled, it leaves at 12.7 m/s and the late pull recovers
  after losing 26.5 m.
- **e. trip.gd round trip:** passes unchanged, 12/12 (out 108.8 s, back
  110.0 s). From the heist landing its autopilot's early pull goes
  through the mush and recovers.

Smoke (400 frames, 0 errors): `heist_level`, `aqueduct_isle`,
`landing_study`. A rendered contact sheet from the chase camera shows the
plane dropping past the cliff nose down, then pulling out.

## Tests broken

- `test_manual_landing.gd`: "At most ROLL_TOP on the wheels" (the test
  window ends at 9.2 m/s; the roll is slower now). "Off slow it dips
  deeper" (unpulled, both run to the cap, so the faster drop falls further).
- `test_kit_isle_landing.gd`: "Turned away, it rolls on free" (half
  Boost for 1.5 s now covers 1.0 m, and the test needs more than 1.0).
- `test_aqueduct_isle_plane.gd` "R3 puts the camera back" fails before
  this change too.
- `test_motif_sky.gd` passes.

## What the harness lacked

No helper for flying the plane. The input (`_in`), the lift-off and the
plummet logging are hand-rolled in the driver, cribbed from
scratch/loop/trip.gd. A `fly` section in drive.gd (hold the stick and
throttle, log the speed, the edge and the catch) would save the next round.
