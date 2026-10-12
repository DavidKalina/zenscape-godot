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

## Round 2b: weight, slam to launch, dropped on (branch `feature/seesaw-launch`)

The tilt is now a balance of moments: pilot_mass x his arm plus each load's
mass x its arm, over pilot_mass x half length. A heavy block keeps its end
down; the pilot alone on the other end cannot lift it. Three lanes
(trap_seesaw_slam.gd, trap_seesaw_drop.gd, trap_seesaw_dropper.gd):

- `seesaw_slam`: a 240 kg stone block (3x the pilot) on the far end holds it
  down, the near end stands up one jump. Climb on and SLAM: the motor's
  "slammed" pace drives `impact`; the block is flung up (v, capped) and
  along (`load_along` x (v - `shove`)), real RigidBody3D afterwards. A plain
  landing only hops it (about 0.1 m, goes nowhere). Tell: the block glows
  orange while primed (low end loaded, high end up); `thunk` on impact.
- `seesaw_drop` (catapult route): stand on the plate on the far (low) end for
  `fuse` s; a block hung over the near end lets go, lands as a blow of its
  momentum, and flings you up and along (`cap_mul` 1.7) onto a high ledge
  past the exit, placed from the launch arc (`arc_reach`). Plate and block
  warm with the fuse; `click` on release, `thunk` on landing.
- `seesaw_dropper` (trap, cost 4, void): the same block falls every `period`
  s over the near end with a `warn` glow; a pilot on the far half is flung
  on and `veer` sideways off the span. One on the near half gets the block
  beside him. The block is hung again `rest` s after landing.

| knob (new) | default | meaning |
|---|---|---|
| pilot_mass | 80 | kg the balance and blows weigh him by |
| load_cap | 2.2 | x the pilot's launch cap, the most a load is flung |
| cap_mul | 1.0 (drop 1.7) | x the pilot's own launch cap |
| along | 0.3 (dropper 0.15) | pilot's push along, x up |
| veer | 0 (dropper 0.9) | pilot's push sideways, x up |
| load_along | 1.6 | load's push along, x (v - shove) |
| shove | first-jump takeoff (6.4 m/s) | load speed below which it only hops |
| block_mass / block | 240 kg / 1.1 x first jump | the block |
| block_arm (slam) | 0.5 | share of half length the block sits from the pivot |
| hook / fuse / period / warn / rest (drop) | 2.4 x second jump / 1 s / 4 s / 0.8 s / 2.5 s | |
| plate / ledge / hook_far (drop) | true / 2.0 / false | plate trigger, ledge top in second-jump heights (0 none), hook over far end |

A load momentum: v = min(launch x blow pace x arm share, load_cap x cap) x
2 pilot/(pilot + load), so the heavy block goes at half the speed a pilot-weight
one would; a slam (20+ m/s) saturates, a jump landing (6 to 8) does not. A
blow spins the slab at most 1.2 rad/s (`SPIN_KICK`); a flung load passes
through the slab until it comes down on it (the swinging deck otherwise
shoves it, and Jolt friction ate its sideways speed), and its impulse is
applied a step after the blow for the same reason.

Windowed: `godot --path . res://studies/trap_yard.tscn -- --no-title --trap=seesaw_slam`
(or `seesaw_drop`, `seesaw_dropper`).

Run test: `godot --headless --path . --script tests/test_trap_seesaw.gd` (about 70 s: it
covers the original blows, a heavy block holding its end, slam against plain
landing, the plate drop onto the ledge, and the timed throw off the span).

## Unverified

- Round 2b by feel: whether the slam really reads (the pilot's own slam keys
  from a jump onto the 0.7 m raised near end, the block's flight length, the
  catapult arc landing on the ledge with real air steering, the dropper's
  timing). Headless test uses `motor.slam` and scripted placement.
- The block interacts with the yard's end deck only by its edge: it was flung
  into the deck wall until `block_arm` came inboard (the low end dips below
  the deck top). Flung loads landing on things or knocking them: no pins built.
- Glow/click/thunk are placeholders; not rendered.

- Feel: tip_time, bounce, slide, launch strength, how the tilted ends meet the
  yard decks (the low end dips below, the high end stands up to ~1 jump).
- Walking the whole span, a slow crossing's slide/pitch, and landing on the
  moving slab in play (headless test uses place + scripted input only).
- The pilot-launch is tested through `impact`; a hard landing is tested against a
  RigidBody3D load. Rock-on-the-high-end tell, two seesaws in a row: not built.
- Creak is a placeholder (tell_sound only); looks not rendered.
