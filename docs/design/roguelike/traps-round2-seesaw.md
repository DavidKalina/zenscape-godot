# Traps round 2: Seesaw Slab (2026-10-12)

> Greybox. Branch `feature/trap-seesaw` (off `roguelike`). scripts/traps/trap_seesaw.gd,
> tests/test_trap_seesaw.gd, one line in studies/trap_yard.gd. Contract unchanged.

A stone slab on a central pivot across the yard's gap (route along -z). Weight
tips it toward the pilot's side by his distance from the pivot; he is carried
(`motor.carry`) and slid toward the low end. Hard landing on the high end flings
the low end: the pilot or any RigidBody3D in `trap.loads`. `impact(arm, speed)`
is the same blow from a thrown stone or drum. Tell: pivot drum warms grey to
orange as it moves, `creak` sound while tipping. Cost 3.

| knob | default (wanderer 1.0) | meaning |
|---|---|---|
| length | 6.0 m (walk x 2.5) | the span |
| width | 2.4 m (run x 0.5) | across |
| pivot_offset | 0 | share of length toward the far end; off-centre it rests tipped |
| max_tilt | ~0.24 rad (end rises 0.9 of a first jump) | full tilt |
| tip_time | 0.8 s | the tilt's settling time (its inertia) |
| bounce | 0.55 | damping ratio, under 1 overshoots |
| slide | run x 0.5 m/s | pace down the tilt at full tilt (friction feel) |
| launch | 1.1 | x fall pace (x arm share, capped at 1.5 second jumps) |
| hard | fall of half a first jump | landing speed that launches |
| creak_gap | 0.45 s | between creaks |

Windowed: `godot --path . res://studies/trap_yard.tscn -- --no-title --trap=seesaw`

Run test: `godot --headless --path . --script tests/test_trap_seesaw.gd`

## Unverified

- Feel: tip_time, bounce, slide, launch strength, how the tilted ends meet the
  yard decks (the low end dips below, the high end stands up to ~1 jump).
- Walking the whole span, a slow crossing's slide/pitch, and landing on the
  moving slab in play (headless test uses place + scripted input only).
- The pilot-launch is tested through `impact`; a hard landing is tested against a
  RigidBody3D load. Rock-on-the-high-end tell, two seesaws in a row: not built.
- Creak is a placeholder (tell_sound only); looks not rendered.
