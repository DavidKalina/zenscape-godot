# Plane ground scale (demo)

On its wheels the plane is drawn bigger, so the pilot in the cockpit is the
wanderer's size. In flight it is exactly the old toy size. Code:
scripts/plane_ground_scale.gd, wired in studies/kit_isle.gd (the aqueduct isle
game), with `size`/`lift` on scripts/glide_camera.gd (1 and zero in flight).

- Factor 2.4 by default. Measured: the wanderer is 0.44 m from shoulders to cap
  top and the cockpit pilot is 0.185 m (2.38). Shoulder width gives 2.2.
- `--plane-ground-scale=<x>` sets it. `=1` turns it off: every change falls
  back to the old numbers.
- Driven by ground speed: full size at or under 3 m/s, flight size from 10 m/s
  (ROLL_TOP is 11). Eased over 0.22 s and capped at 1.4x the full change a
  second. Off an edge and dipping it shrinks fast (0.12 s). Flying, it is 1.0.
- Scaled about the wheel contact (PlaneStrip WHEEL_DROP/WHEEL).
- Follows the scale: chase distance, height and look point; the hop-in start
  and the hop arc; the hop-out spot (left, between the lower wing and the
  tailplane); the board reach and the walker's keep-off column; the parked
  footprint check when picking the plane's home.

Open issues:
- On the ground the wings clip trees and walls, and the roll's blocked/bump
  checks still use the flight-size plane.
- The landing mark is hidden on the kit isle, so it wasn't touched. The scarf
  doesn't scale (its width/length).
- The stone plane (`--stone-plane`) is scaled about the wooden plane's wheel
  point. Not checked.
- Rolling off an edge slowly can show a short (~0.3 s) shrink during the dip.
- Not tuned. Only the parked view was captured; the mid-roll blend hasn't
  been seen yet.

Where the cheat can show (keep these in mind for later features):
- Planes seen from on foot in the air: CPU traffic flying low past the
  wanderer, or a landing watched from the ground, reads as a model plane.
  Traffic seen from on foot may need the same cheat.
- Mid-air hand-offs: ejecting into the pocket sail or being knocked off by the
  dragon swaps the ~0.5 m cockpit pilot for the 1.19 m walker in the air.
  Each one needs something to hide the change (a puff, a tumble).
- Built spaces: anything the plane parks in (hangar, strip, dock) is sized for
  the ground scale; anything flown through is sized for flight
  (scripts/world_scale.gd `span`, `gap(room)`).
- Ask scripts/world_scale.gd (sizes) and scripts/plane_ground_scale.gd (the
  size right now) how big the plane is; don't hard-code either in new code.

## The game's sizes (feature/plane-wanderer-scale)

The "meet in the middle" sizes are the default: the plane 2.0x its toy size
everywhere (2.8 m wings), the wanderer 0.83, and no ground cheat (it
derives to 1.0). The user flew these and said "seems alright".

**One file.** `scripts/world_scale.gd` holds the knobs `PLANE` (2.0) and
`WANDERER` (0.83), parses `--plane-scale=` / `--wanderer-scale=` once, and
derives `span`, `wider`, `taller`, `ground_factor()` and `gap(room)`. Nothing
else holds 2.0, 0.83 or 2.4 or parses those flags. Change one number there
and the plane, walker, moves and the flown gaps below follow. The values are
static vars that are read once when the script loads, so a scene opened from
the scene picker keeps the command line's sizes.

`--plane-scale=1 --wanderer-scale=1` gives back the old sizes, and every gap
and move below returns to its old number, with one exception: THREAD comes
back as 3.22, not 3.5 (see below). Checked with a headless probe script. In
that mode the cheat comes back at 2.4. Its code is kept.

**Gaps.** Each flown gap is `WorldScale.gap(room)`: the plane's span plus
`room` toy spans (1.4 m each) of steering room. The room doesn't grow with
the plane because the flight's speeds and turns are unchanged. Old → new,
at plane 2:

| Gap | Old | New |
| --- | --- | --- |
| ruin_kit THREAD (room 1.3) | 3.5 | 4.62 (0.91 past each wingtip) |
| ruin_kit ARCH_SPAN (room 2.0) | 4.2 | 5.6 (crown 6.8 → 8.0) |
| ruin_kit WINDOW width | 3.6 | 5.0 |
| ruin_kit WINDOW_WALL | 6.8 x 7.8 | 8.2 x 9.0 |
| ruin_kit rose glass | 3.96 | 4.95 (rose and gable grown x1.18 by ROSE_GROW; the door stays) |
| hall LANE (room 1.86) | 4.0 wide (z 4–8) | 5.4 (z 4–9.4) |
| hall ROW_Z / WALL_Z | 9.4 / 12.4 | 10.8 / 13.8 (out by the lane's growth) |
| hall TIE_LOW | 4.0 | 4.5 (`4+taller`, capped so 3.6 m stays over it under the capitals) |
| hall LANE_Y top | 3.6 | 4.1 |
| hall KNIFE slit | 1.15 x 3.3 | 1.89 x 4.7 |
| hall ARCH breach | 5.2 | 5.62 (THREAD+1) |
| hall BREACH_HALF | 1.8 | 2.33 |

THREAD's room was 1.5 at first, which gives 4.9 at plane 2. That didn't fit
between a curved hall's outer columns, nor under the aqueduct's 4.7 m
arches, so the room is 1.3: 4.62 at plane 2 and 3.22 at plane 1.

Hall details:
- A knife slit whose head doesn't fit under the screen's top (under a tie)
  now runs up open to the top, with the tie as its lintel (`_wall` slot).
- An outer nave roof strip is too narrow to fly out of alone, so it is
  gapped together with its neighbour, as one opening.
- A breach corridor wider than the room between column bases floors over
  them (`breach_floor`).
- The lane stops short of a high tie up a slope.

Other gaps:
- The aqueduct (CLEAR 4.7) was checked and left. It passes the plane with
  0.95 m past each tip at the piers and about 0.6 m a metre up into the arc.
  Its corridor keeps its old 3.5 width.
- pierced_isle ROUTE_CLEAR and hole room read `span`.
- collectible_lines: PLANE_REACH 1.1 → 1.8, WING 0.8 → 1.5, CLEAR
  +taller. Under-rock tokens hang only where rock is overhead.
- sundered_growth LANE / LANE_TOP, hall_rise_plan, sundered_build,
  hollow_keel_isle_art, lodestone_study and aqueduct_isle_chain read the
  hall/kit values (now static vars).
- The chain plane box in aqueduct_isle uses the drawn size.
- The flight study (flight_course REACH/SPAN) stays at toy size because its
  plane is the toy.

**Walker** (PilotMotor.set_size, from the study's `resize`):
- Hang geometry: HANG_DROP, HANG_OUT and CLIMB_IN x size, to match the
  scaled clips (0.825/0.22/0.3 → 0.685/0.183/0.249).
- Jumps rise by what the hands lose: `JUMPS + HANG_DROP*(1-s)`, so
  0.8/1.5 → 0.94/1.64. Every catch top (GRAB_TOP 1.875, CHAIN_TOP 2.575)
  stays.
- Walk and run go by `size^PACE_POWER`, with PACE_POWER 0.25: 2.4/4.8 →
  2.29/4.58. long_pace, skid and wall-run thresholds follow (3.0/3.4/4.0 →
  2.86/3.25/3.82). Froude's 0.5 broke the cloister tarn's 2.7 m stub jump.
  0 broke the aqueduct circle's twirled loop.
- Water depths: WATER_POWER is 0, so they are unscaled. Scaled, the walker
  swam the drowned nave's causeway.
- The gait plays by pace over size (PilotFigure.size).
- The pocket sail is scaled with him.
- The cockpit pilot already matches at plane 2 (0.185 x 2 vs 0.44 x 0.83),
  so it was left alone.
- CPU traffic is drawn at the plane size (PlaneGroundScale.grow).
- No lodestone plane miniature exists.
- Replays run at the size they were recorded at (old runs at 1). Runs
  recorded now save `size`.
- Shimmy bug fixed: it now reads the lip's way out where he hangs, because a
  rough lip stopped the first shimmy step.

**Still open** (fixed metres that won't follow, roughly by impact):
1. Kit isle body collider. The game's walker collider is still full size
   (radius 0.28, head 1.12, DeckGround). Scaling it made several scripted
   isle routes stick, and the demo the user flew had it this way. The
   character study's collider is scaled.
2. Hand-laid set pieces built for the toy plane:
   - The aqueduct isle's knife-edge stump slot (STUMPS gap 1.9 m) no longer
     fits. test_aqueduct_isle_sky fails. Widening it broke the walker's
     running jump between those stumps.
   - The sundered gorge plane line bumps 4x (test_sundered_gorge_isle).
   - Flight study "sundered_mix" tokens now sit inside the wider hall
     (test_flight_metrics).
   - aqueduct_isle_chain's ring arch (RING_SCALE 2.2) is now 12.3 m wide;
     it may want a smaller scale.
3. Hand-laid isles round widened pieces:
   - The cloister tarn's northeast bridge end is blocked, probably by the
     wider arch placed there (test_cloister_tarn_isle).
   - The hollow keel porch walk now meets a 0.46 m paving edge over the keel
     floor in the widened hall (test_hollow_keel_isle).
   - Gallery slots weren't re-spaced. The rose gable nearly touches the
     turret.
4. Kit and isle geometry is not scaled: stairs, ledges, set-offs, stumps,
   wall heights, catch tops (GRAB_TOP/CHAIN_TOP) and isle layouts. The jump
   is held to the old catch tops, not to his body. To make spacing follow
   WANDERER, these want deriving from the walker's reach next round.
5. THREAD at plane 1 is 3.22 (was 3.5).
6. The gallery's chase cam at 2x sits back inside the hall's columns.
7. Not captured: the walker on the game's stairs and doorways.
8. The scarf width, landing mark and stone plane are unchanged from before.
