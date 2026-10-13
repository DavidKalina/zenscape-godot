# Broken Viaduct: gust arrows (greybox hazard)

Branch `feature/viaduct-arrows`, cut from `feature/crossing-viaduct` (not merged).
This is the Dark Souls 3 giant-archer idea without an archer yet. A dark stone
perch stands off the pier field's left side. It fires the dragon's air blast
(`scripts/dragon_air_blast.gd`) at the pilot while he is on the piers or the
safe stair. No beat was moved or resized.

## Run it

    ./run-crossing-yard.command --beat=2         # start at the piers
    ./run-crossing-yard.command --arrows=0       # arrows off

- **K** turns the arrows on or off and shows a toast. The foot hint shows
  "K arrows: on/off".
- `--arrows=0` / `--arrows=1` sets the start state. The default is on.
- The other keys are as in round 1: R, 1-5, N.

## What happens

- **Tell:** the ball gathers on the perch for 0.8 s, with the blast's inhale
  sound (the yard's audio reads the perch as a dragon's blast).
- **Shot:** a bright shimmer ball with a streak trail, at 30 m/s. It is aimed
  at his middle at the moment it fires: no lead, so a pump's rise and fall
  aren't extrapolated into the piers. It is aimed a little high. In flight it
  bends gently toward him and stops bending once it has passed him.
- **Mid-pump hit** (in the air, or on a landing he can still pump off, which
  means under the motor's `chain_window` on the ground): a hard hit. He is
  thrown about 10 m out and stunned 0.8 s, which takes him off the piers to
  the floor.
- **Standing hit** (on the ground longer than that): a shove of 3.2 m/s out
  and 2.4 m/s up through `toss`. He keeps control. Standing still, he stays on
  his pier. So the counter is: when you see the tell, plant your feet.
- **Cover:** the perch is abeam and low (`ARCHER_ALONG` 26, `ARCHER_ASIDE` 18,
  `ARCHER_UP` 0 from the turn platform). Every pier top is open to it. The
  piers stand between the perch and the safe stair, so shots at a pilot on the
  stair pop on the pier stone. The slow line is also the covered line.
- **Zone:** the perch fires only when he is between the turn platform's edge
  and the plinth, from 3 m left of the piers to 2 m past the stair, and not
  down on the floor (`on_pier_field`).

## Knobs

All are in `studies/crossings/gust_arrows.gd`:

| Knob | Value | What it sets |
|---|---|---|
| `SPEED` | 30 | ball speed (m/s) |
| `WINDUP` | 0.8 | tell (s) |
| `COOLDOWN` | 2.0 | time from a shot to the next tell (s) |
| `HOMING` | 0.8 | most the ball turns toward him (rad/s) |
| `LEAD` | 0 | share of his flat travel that is led |
| `AIM_UP` | 0.5 | aim height over his middle (walker heights) |
| `FUSE` | 0.3 | how near a ball must pass to burst on him (walker heights) |
| `RANGE` | 55 | how far away the perch will wind up at him (m) |
| `FLY` | 90 | how far a ball flies (m) |
| `AIR_OUT` / `AIR_UP` | 9 / 1.2 | mid-air throw (walker heights) |
| `STUN_DOWN` | 0.8 | time laid down after a mid-air throw (s) |
| `PUSH` / `PUSH_UP` | 3.2 / 2.4 | standing shove (m/s) |
| `GLOW` | 1.6 | look boost over the dragon's shimmer |
| `TINT` | | the ball's tint |
| `GATHER` | 1.8 | tell ball size, as a share of the ball |
| `TRAIL` | 4 | trail length (m) |

The perch's placement and zone are `ARCHER_*` in `crossing_viaduct.gd`.

## Code

- `studies/crossings/gust_arrows.gd`: launchers, each a perch node holding a
  DragonAirBlast, a zone, and the knock/shove split.
- `studies/crossings/crossing.gd`: optional hazard hooks (`has_hazards`,
  `set_hazards`, `step_hazards`, `hazard_voices`), which do nothing by default.
- `studies/crossings/crossing_viaduct.gd`: the perch column, `archer_at()`,
  `on_pier_field()` and the hooks.
- `studies/crossing_yard.gd`: steps the hazards after the pilot in `tick`,
  plays their sound, and handles K, `--arrows=` and the hint.
- `scripts/dragon_air_blast.gd`: new per-instance vars whose defaults equal the
  old constants or behaviour, so the dragon is unchanged.
  - `speed`, `flight`, `fire_range`, `knock_out`, `knock_up`, `fuse`,
    `lead_share`, `gather` (defaults SPEED, RANGE, FIRE_RANGE, KNOCK_OUT,
    KNOCK_UP, FUSE, LEAD, GATHER).
  - `lead_flat` (false), `homing` (0: no turn), `glow` (0: the shader's extra
    term is zero), `tint` (AIR_TINT).
  - `lead()` gained optional `pace` and `share` parameters, which default to
    SPEED and LEAD.

## Verified

Headless, `tests/test_crossing_viaduct_arrows.gd`: 9/9 OK. It runs the yard's
own `_process` frames (not `scripted`) at about 60 fps, with the stick and
Space as Input actions.

- Pumping from the turn platform, the perch winds up and fires. The shot bursts
  on him mid-pump around pier 1 and throws him; he ends on the floor about
  17 m aside.
- Standing on the safe stair beside pier 2, both shots pop on the pier stone.
  Nothing touches him.
- Standing on pier 5, a shot shoves him. He stays on pier 5 and isn't stunned.
- With the arrows off, there is no tell and no shot.

Also run:

- `tests/test_crossing_viaduct.gd`: all pass. It now sets `hazards_on = false`.
- Load check of `res://studies/crossing_yard.tscn`: clean.
- I did not run the full suite or `test_dragon_air_blast` (out of scope this
  round). The dragon's defaults are unchanged by construction.

Windowed (forward_plus, `-- --no-title`), driven by a throwaway script through
Input actions, not committed. The same three cases played out in the window: a
mid-pump throw to the floor, a standing shove that kept him on pier 5, and a
pop on the stair. Captures are in `captures/viaduct_arrows/` in the worktree
(gitignored):

- `pump_1_tell.png`: the tell gathering on the perch, top left.
- `pump_2_flight_1.png`, `pump_2_flight_2.png`: the ball in flight toward him.
  It is about 150-210 px across at 14-22 m from the camera, with a white ring
  and streak trail, and reads clearly against the floor.
- `pump_3_hit.png`, `pump_4_thrown.png`, `pump_5_falling.png`: the burst on
  him, then him thrown off over the stair.
- `stand_*.png`: the standing shove.
- `stair_*.png`: the stair-cover pop. The pop happens off-screen; the camera
  faces up the stair, away from the perch.

## Not verified / open

- Feel at human timing.
  - Is 0.8 s of tell plus about 0.7 s of flight fair?
  - Is "plant your feet" discoverable?
  - Is the first shot, which comes as soon as he steps onto the field, too
    quick?
- The tell is still modest: a pale ring on a dark post. A bigger cue (a glow on
  the perch, a sound sting) may be needed.
- Leaving the zone cancels a wind-up without using up the cooldown, so the
  shot can't be baited out yet.
- No second launcher for the aqueduct deck.
- The archer model.

## Round 2 (more perches)

Two more perches after the user played round 1 ("pretty damn good... we need to add more"):
the far side's (right of the safe stair, three quarters along the piers, `FAR_ARCHER_*`,
firing on the piers from 45% on, never on the stair) and the deck's (right of the run-up,
`DECK_ARCHER_*`, firing on the deck). Launchers take turns (`GustArrows.TURN_GAP`): one winds
up only when no other is winding up, has a ball in flight or fired within 1 s. Without it the
two pier perches fired together and a standing shove became a throw from the second ball.
The deck perch is unverified: whether its shots clear the parapets and reach a pilot on the deck.
