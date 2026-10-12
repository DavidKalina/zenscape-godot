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
blow spins the slab at most 1.2 rad/s (`SPIN_KICK`), so its rising tip stays
slower than a slam's throw (round 2c below).

Windowed: `godot --path . res://studies/trap_yard.tscn -- --no-title --trap=seesaw_slam`
(or `seesaw_drop`, `seesaw_dropper`).

Run test: `godot --headless --path . --script tests/test_trap_seesaw.gd` (about 60 s,
`## suite: slow`: it covers the original blows, a heavy block holding its end,
slam against plain landing, the plate drop onto the ledge, the timed throw off
the span, and round 2c's blocks on the yard's own loop).

## Round 2c: blocks fell through the slab (branch `fix/seesaw-blocks`, 2026-10-12)

Played windowed, the blocks fell through the seesaw instead of sliding or
launching. Reproduced headless on the yard's own loop (study `_process`,
physics on its own clock, not the test's scripted tick): one plain landing on
the slam lane's raised near end and the 240 kg block sank through the slab
and came to rest on the floor a layer down (y -5.6), every time.

Root cause: the round 2b throw added a collision exception between the load
and the slab (`add_collision_exception_with`) at every blow, to be removed
only once the load came back down within 0.3 m above the deck or after 2 s.
A plain landing throws the heavy block only ~2 m/s, while the blow swings
its end of the slab up into it: the block sat below the deck top, the
exception never lifted, and it fell through. Under it, the slab was a
StaticBody3D teleported each frame from `before` (the frame's `_process`),
so Jolt saw no deck velocity; the exception and the one-step-late impulse
(`_pending`) were patches over that.

What changed (scripts/traps/trap_seesaw.gd, trap_seesaw_slam.gd):

- The slab is an AnimatableBody3D. Its tilt (balance of moments, spring,
  stops) is stepped and posed in `_physics_process`, once per physics step,
  so Jolt moves it kinematically and loads resting on it get the deck's
  contact velocity, at any frame rate (checked at 60 and 20 fps).
- The pilot is carried in `before` by how far the slab moved since his last
  frame (`_carried`), slide as before; `on_slab` is exact in the slab's own
  frame (as posed when he last stepped).
- A throw is one impulse on the load at the blow. No collision exception, no
  pending impulse, no `_free` tracking. `SPIN_KICK` stays (1.2 rad/s), now
  for a stated reason: the deck's rising tip (3.6 m/s at most) is slower than
  a slam's throw, so the throw sends the load and the deck never shoves it;
  a plain landing just lifts it with the deck. At a stop the slab stops
  (spin pushing past the stop is spent).
- Blocks have continuous collision on; slab and blocks share a friction,
  the new knob `grip`.
- The slam lane's block is set square on the tilted deck (it was set level,
  on one edge).

| knob (new) | default | meaning |
|---|---|---|
| grip | 0.5 | friction of slab and blocks; a block slides down a tilt steeper than atan(grip). The yard's full tilt is 14 deg (tan 0.25), so 0.5 holds; under 0.25 they slide |

`block_arm` stays 0.5: a layout fact, not a physics patch (the slab's low end
dips 0.7 m below the end deck's top, and a block at the very tip would be
thrown into the deck's face).

Headless numbers (yard's loop): at rest the block holds its end 4 s without
moving; a plain landing lifts it 0.37 m with the deck and it stays on; a slam
from 5 m throws it up 2.1 m and 5.4 m along, landing on the far deck; with
`grip` 0.1 it slides down and off the low end; a dropped block launches the
pilot (vy 18) onto the ledge and stays on the slab.

## Unverified

- Round 2b by feel: whether the slam really reads (the pilot's own slam keys
  from a jump onto the 0.7 m raised near end, the block's flight length, the
  catapult arc landing on the ledge with real air steering, the dropper's
  timing). Headless test uses `motor.slam` and scripted placement.
- Round 2c windowed: the fall-through was reproduced and fixed headless on
  the yard's own loop at 60 and 20 fps; not replayed windowed. Whether blocks
  should slide at the yard's 14 deg (`grip` under 0.25) is a feel call: at
  the default they hold, as the slam lane needs (a sliding block ends against
  the end deck's face, which would eat its throw).
- The block interacts with the yard's end deck only by its edge (the low end
  dips below the deck top). Flung loads knocking other things: no pins built.
- Glow/click/thunk are placeholders; not rendered.

- Feel: tip_time, bounce, slide, launch strength, how the tilted ends meet the
  yard decks (the low end dips below, the high end stands up to ~1 jump).
- Walking the whole span, a slow crossing's slide/pitch, and landing on the
  moving slab in play (headless test uses place + scripted input only).
- The pilot-launch is tested through `impact`; a hard landing is tested against a
  RigidBody3D load. Rock-on-the-high-end tell, two seesaws in a row: not built.
- Creak is a placeholder (tell_sound only); looks not rendered.
