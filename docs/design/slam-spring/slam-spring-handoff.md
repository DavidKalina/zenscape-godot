# Slam spring: handoff

Ground-slam onto a bobbing slab and it sinks like a spring, holds, then
kicks back up and launches you far higher than a jump. A prototype, with no
committed tests.

## Play it

```
./run-zenscape.command --no-title --foot-at=slabs --ledger=/tmp/slam_spring.json
```

You start on foot beside the three bob slabs off the near island's east rim.
Hop onto the first slab. The slam needs 1.8 m of air under you (slam.gd
`LOW`), and a plain jump off a slab only gets you 0.9 m. So the first slam
needs height from somewhere else:

- the updraft (Q), then crouch at its top;
- a pump jump off the higher slab down onto a lower one;
- on Stair Clouds (`--foot-at=stair_slabs`), a drop off the stair.

After that, slamming on the way down from a launch springs again, so it
chains. Plain landings and walking on a slab work as before.

## What was built

- **The motor** (`scripts/pilot_motor.gd`): `launch(push, free)` throws him
  like `toss` (a fresh airtime with air steering, the twirl and the sail
  ready, and the height not cut short by letting go of Jump). The first
  `free` m of the drop that follows don't count toward the fall stun or its
  heart damage. A launch also hangs at its top: within LAUNCH_HANG_V
  (3.2 m/s) of the apex, in plain air (no twirl, sail or slam), gravity is
  LAUNCH_HANG_G (0.28) of normal. The band edges split the arc step, so the
  apex is the same at any frame rate. `rise_for(h, hang)` gives the upward
  speed that rises `h` m, counting the hang.
- **The slab** (`scripts/interactables/foot_slab.gd`): an opt-in spring
  (`spring_on`) with these stages: coil, hold with a tremble, release on its
  own fast spring (overshoot and wobble), then settle back to its bob. The
  stone's look is moved under a `Look` node, so the squash and stretch only
  change the drawn stone, about its top. The collision box stays as it was.
- **Bob slabs** (`bob_slab.gd`) have the spring on by default, with
  `SPRING_PUMPS = 6`. No slab has it turned off, and sink and drift slabs
  don't have it.
- **Foot pieces** (`foot_pieces.gd`): a slam that lands on a springing slab
  (the step has both "landed" and "slam") coils it and adds the
  "spring_coil" event. When the slab releases with him still standing on
  it, he is launched by `motor.launch` at 6 × his pump height, keeping his
  flat speed, and the step gets "spring_launch". If he walks or jumps off
  during the coil, the slab still springs but doesn't launch him.
- **Feedback** (`studies/character_study.gd`): on "spring_launch", a stone
  thump (the existing `steps.step`), a ring of 7 grit puffs and an air swirl.
  The slam's own touch effects (ring, clods, camera kick, pad) fire as
  before. No new audio: the kit has no spring sound hook.

## Numbers (size 1, after the user's "springier" pass)

| | |
|---|---|
| sink depth | 1.5 m (about two slab thicknesses), reached in 0.17 s (fast at first, easing into the bottom) |
| squash | 32 % shorter and 16 % wider at the bottom, a 2.5 cm tremble in the hold |
| hold | 0.14 s |
| release | slab kicked up at 11 m/s on a 2.4 Hz spring with damping 0.2 (overshoots above its rest, then wobbles), back to its own bob spring over 1.6 s; squash kicked to a stretch at 7/s on a 3.2 Hz spring with damping 0.22 |
| touch to launch | 20 frames (0.33 s) |
| launch | 21 m/s up, 6 × pump = 9.0 m planned; measured apex +8.65 m over his feet one frame after the launch (about 9 m over the slab top) |
| air time | 1.97 s from the launch back down onto the slab, with a hang at the top (gravity × 0.28 within 3.2 m/s of the apex, about 0.6 s of it) |
| plain jump | 0.80 m on the ground, 0.89 m off a slab |
| fall stun | 6.0 m (4 pumps); the launch forgives 9.0 m of drop |

The first pass had a 0.7 m sink, a 0.12 s hold, a 4-pump launch (5.7 m),
1.2 s of air time and no hang.

## What was proved (headless, real input, scratch/ drivers)

- On the first aqueduct-route slab, the real slam input (updraft Q, then
  crouch) coils the slab. The launch reaches +8.65 m against a jump's
  0.80 m, with 1.97 s of air time. He lands back on the slab (a drop of
  about 9 m) with no stun.
- Four launches in a row worked, each +8.65 m. The second, third and fourth
  came from slamming on the way down from the previous launch.
- A plain jump onto the slab and walking on it: 0 springs, 0 launches.
- Launched and steered west, he landed on the isle rim with no stun (air
  steering is as in any jump).
- On Stair Clouds, launched off the top slab and steered toward the lawn,
  he landed 11.62 m under the apex (2.96 m under the launch) with no stun.
  A landing 6 m or more under the launch point still stuns as any fall
  does.
- Without the forgiven drop, every landing from a launch would stun: the
  9 m apex is well over the 6.0 m stun height, even landing back on the
  same slab.
- Rendered capture (play camera, low angle, one window, `--no-title`): the
  slab sinks well below its neighbour, squashed, holds, then pops up
  stretched and overshoots. The camera follows him up, holds through the
  hang and follows him back down. After the springier pass, the 1.5 m sink
  reads clearly against the neighbouring slab.
- Smoke: headless import, then `studies/zenscape.tscn` and
  `studies/aqueduct_isle.tscn` for 400 frames each, 0 errors.

## Tests

Run headless after the final tuning: `test_foot_interactables`, `test_pilot_motor`,
`test_pilot_stun` and `test_aqueduct_isle` pass. `test_slam` fails 2 checks
("The updraft spends the charge", "Updraft then slam in one airtime"). These
fail the same way on main without this change: the caches-slam merge made
the charge keep. This change breaks no test.

## Notes

- Bob slabs in roguelike `layer_hazards.gd` and `crossing_yard.gd` also
  spring now. Nothing there was checked for routes this could break.
- The harness `film()` with its own camera on this isle drew only clouds
  (the slab as a speck), for a Vector3 target or the slab node. The
  `"play"` view with `_polar` set worked. The harness lacks a reliable
  fixed side camera on sky isles.
