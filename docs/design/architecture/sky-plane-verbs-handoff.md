# SkyPlane verbs: handoff

A refactor round that changes no behaviour. The plane and the glide now keep
`velocity` consistent with heading, pitch and speed when outside code sets
them, so callers no longer write `velocity = forward()*speed` by hand.
No flight numbers changed.

## The verbs

On SkyGlide (`scripts/sky_glide.gd`), so SkyPlane, SkyDive and the wanderer's
glide all have them:

- `set_pace(pace)` sets speed to `pace` (not clamped) and velocity to
  `forward()*speed`. `set_pace(0.0)` is the stop.
- `place(at, towards, nose, pace)` sets position, heading and pitch, then
  calls `set_pace(pace)`. Unlike `launch`, it resets nothing else.
- `glance(normal, keep, least)` is the bump turn. It turns the nose along
  the face, clamps pitch to ±0.6 rad and sets the pace to
  `max(least, speed*keep)`. The caller still pushes the plane out of the
  solid, because only the caller knows the solid. `least` is passed in on
  purpose: RuinBump floors the wanderer's plain glide at `SkyPlane.SLOW`.

On SkyPlane (`scripts/sky_plane.gd`):

- `park(at, towards, nose, lean)` is `launch` followed by `rest_on`, with the
  engine off. It is the parked plane being boarded.
- `rest_on(at, nose, lean)` sits the plane on its wheels. It keeps the
  heading, sets the pose and calls `set_pace(0)`.
- `carry(at, moving, pace)` is for scripted runs (a landing, a takeoff, a
  ground roll). It sets position, velocity and speed directly. This is the
  one setter where velocity is the path's direction, not the nose's: on the
  wheels or flown in from outside, the nose need not point the way the plane
  moves. The caller sets the attitude.

## Sites converted

- **The 9 restated invariants:**
  - kit_isle `board` and `fly_from`, hall_rise and hall_chain: deleted. The
    line was redundant, because `launch` already sets velocity.
  - kit_isle `_bump`, ruin_bump, ruin_kit_gallery and sky_pierced: now
    `glance`. The bump block that had been copied into four files is gone.
  - rune_serpent `meet`: now `place`.
- **board_parked:** the `launch` call plus six overwrites is now
  `plane.park(...)`.
- **plane_landing:** `_fly`, `_roll` and the takeoff's ROLL and LIFT phases
  now use `carry`. `_stop_here` uses `rest_on` and `_hold` uses
  `set_pace(0)`.
- **manual_landing:** the ground roll uses `carry`. The stop and `_hold` use
  `set_pace(0)`.
- **flight_run:** checkpoint restart uses `place`.
- **landing_run:** start uses `set_pace`.

Outside writes to `plane.position/velocity/speed/pitch/bank/heading/engine`
dropped from 99 to 45 (counted by grep).

## Writes left on purpose

- **Attitude only (heading, pitch, bank):**
  - plane_landing's eased bank and pitch, the flare pitch, and the taxi turn.
  - manual_landing's `_place_on`, the spot turn and the wingtip kick.

  These are scripted attitude. In those phases velocity follows the path
  through `carry`, not the nose, so there is no invariant to keep.
- **Mid-step physics overrides in manual_landing:**
  - `_dip` and `_bounce` set `speed`, `pitch` and `bank` between steps.
  - The next `step` rebuilds velocity from them.
  - `_air_velocity` reads the velocity left by the step. Calling `set_pace`
    here would change what it reads and so the landing grade, so these
    writes stay raw.
- **Collision probes and push-outs:**
  - kit_isle `_bump`'s position push-outs and the `board` loop that raises
    the plane out of stone. Velocity does not depend on position.
  - kit_isle `_ride_top`: it clamps `velocity.y`, eases the pitch and drags
    the speed. This is the glide's skim done from outside.
  - plane_landing taxi's `position.y`.
  - ruin_bump's, the gallery's and sky_pierced's push-outs.
- **Display sync:** kit_isle and landing_study copy `plane.engine` from the
  sequence every frame.
- **Not converted:**
  - landing_study 723 sets position and heading, then calls `resume`, which
    already rebuilds velocity.
  - tools/landing_slide_probe.
  - sky_traffic's `Flight`: its own class, not a SkyGlide.
  - manual_landing's off-edge xz move before `resume`.

## Proof

- Headless import is clean.
- Smoke passed for 7 of 7 scenes: aqueduct_isle, zenscape, hall_rise,
  hall_chain, ruin_kit_gallery, flight_study and landing_study.
- **A/B trace** (`scratch/plane_trace.gd`, uncommitted, run with
  `python3 tools/drive.py scratch/plane_trace.gd --log ...`):
  - The run on the aqueduct isle, through real input:
    1. Space by the parked plane: board and hop in.
    2. Boost: roll off the edge.
    3. A turn, then a homing loop.
    4. Brake down onto the strip: touch, roll, stop.
  - It logs position, velocity, speed, heading/pitch/bank and engine every
    6 frames, 402 rows.
  - Base and branch traces are identical (after normalising `-0.00000`).
    Two base runs were also identical.
- **Tests, run headless:** 21 of 25 passed. These passed:
  - test_sky_plane, test_plane_flight, test_plane_landing
  - test_aqueduct_isle_plane, test_kit_isle_landing, test_hand_landing_exit
  - test_manual_landing, test_manual_landing_game
  - test_flight_* (8 tests)
  - test_hall_rise, test_hall_chain, test_isle_hall_chain
  - test_pierced_isle, test_serpent_ride
- **Failures that were already there:** test_plane_arc, test_rune_serpent,
  test_serpent_hops and test_serpent_route.
  - They also fail on base c4472906, with the same FAIL lines.
  - plane_arc gets a Nil `advance`. The serpent tests fail with "serpent is
    in the sky by default".
  - So no test exercises rune_serpent `meet`, which now uses `place`.

## Existing tests this breaks

None found.

## Harness gaps

- drive.gd has no helper for a key press sent through `_unhandled_input`.
  The driver builds an `InputEventKey` for Space.
- There is no ready flight autopilot for "fly back and land on the strip".
  The driver uses its own small homing controller.
