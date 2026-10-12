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

## World spacing (feature/world-spacing): the current sizes

The chase camera at these sizes (the plane always in view, game speed
1.15x): docs/design/flight-camera.md.

The user flew `--wanderer-scale=1 --plane-scale=2.0 --plane-ground-scale=1`
and found the walker at 0.83 "too damn small" and the openings too tight.
This round puts the walker back to his full size, keeps the bigger plane,
and spaces the world out. The sections below this one describe the round
before; where they disagree, this section is current.

**Defaults** (scripts/world_scale.gd):
- `PLANE` 2.0 (2.8 m wings) and `WANDERER` 1.0 (his clips' size, 1.19 m).
- The cockpit pilot is drawn bigger instead of the plane: `pilot_size` =
  PILOT_RATIO*wanderer/plane = 1.2 (plane_figure.gd, stone_plane_figure.gd).
  It is capped at `PILOT_MOST` 1.25; past that he stays 1 and the ground
  cheat does all of it.
- With that, the ground cheat `ground_factor()` = PILOT_RATIO*wanderer/
  (plane*pilot_size) comes out at exactly 1.0, so the cheat is off.
  `--plane-ground-scale=<x>` still overrides it. At
  `--plane-scale=1 --wanderer-scale=1` the pilot is 1 and the cheat 2.4,
  as before.
- The walker's collider: kit_isle now calls `decks.scale_body(wanderer)`.
  At 1.0 that is the full-size collider (radius 0.28, head 1.12), the same
  as the character study's. The open item from last round is closed.

**Room** (steering room past the wings, counted in toy spans, both sides
together; it does not grow with the plane):
- `WorldScale.ROOM` 2.0 is the default for a flown opening: 1.4 m past each
  wingtip.
- `WorldScale.SNUG` 2.4/1.4 = 1.714 is the least any flown opening gets:
  1.2 m past each wingtip.
- `WorldScale.knife(room)` sizes a deliberate knife-edge slot: the plane's
  height on its side (TOY_TALL*plane) plus room. `KNIFE_ROOM` is 0.3, so
  1.9 m at plane 2.
- `WorldScale.past_tip(width)` gives what an opening leaves past each tip.

**Openings, old → new at plane 2** (past each wingtip in brackets):

| Opening | Old | New |
| --- | --- | --- |
| RuinKit THREAD (SNUG) | 4.62 (0.91) | 5.2 (1.2) |
| RuinKit ARCH_SPAN (room 2.6) | 5.6 (1.4) | 6.44 (1.82), crown 8.78 |
| RuinKit WINDOW (ROOM) | 5.0 (1.1) | 5.6 (1.4); wall grows with it |
| Rose glass (ROSE_GROW off THREAD) | 4.95 | 5.25 (1.23) |
| Aqueduct CLEAR = THREAD, SPAN = CLEAR+PIER | 4.7 (0.95), SPAN 6.4 | 5.2 (1.2), SPAN 6.9 |
| Aqueduct two-tier LOWER_SPRING | 3.0 | derived, 2.76 (the lower arch crowns under the course) |
| Stone circle sarsen gap (HENGE_ROOM = SNUG) | 14 stones, ~2.1 m gaps | 8 stones, 5.2 m at their inner faces (1.2) |
| Great trilithon slot (knife) | 0.9 | 1.9 (0.21 round the plane on its wingtip) |
| Hall LANE (LANE_ROOM 2.4) | 5.4 (1.3) | 6.16 (1.68) |
| Hall breach corridor (BREACH_HALF off THREAD) | 4.66 | 5.24 (1.22) |
| Hall broken ARCH | 5.62 | 6.2 (1.7) |
| Hall knife slit | 1.89 | 1.89 (knife edge, kept) |
| Ring arch on the lodestone's line (RING_ROOM 8) | 2.2 x arch, 12.3 | gap(8) = 14.0 (5.6) |
| Aqueduct isle stumps' knife slot (knife(0.45)) | 1.9, off the line | 2.11, centred on the arch (0.32 round the plane on edge) |
| CollectibleLines GAP_ROOM (SNUG) | 3.2 | 5.2 |
| CollectibleLines WING (half gap(SNUG)) | 1.5 | 2.6 |
| Pierced isle ROUTE_CLEAR (half gap(SNUG)) | 2.3 | 2.6 |
| Bell spires: hero to the low spire | 6.2 (1.7) | 12.4 (4.8) |
| Bell spires: gable to fin_low | 7.9 | 10.4 (3.8) |
| Bell spires: other spire pairs | 8.8 to 11.7 | 11.6 to 14.2 |

**Stone circle** (ruin_kit.gd `stone_circle`; the user's #1):
- `CIRCLE_STONES` is 8 and `SARSEN` is 1.5 m wide (it was 1.7).
- `CIRCLE_RADIUS` is derived so that the gap between two sarsens at their
  inner faces is `gap(HENGE_ROOM)`. That gives 9.3 m at plane 2 (it was
  8.5) and 7.5 m at plane 1. It fits the aqueduct isle's summit (11 m at its
  narrowest) and the broken ring's 13.5 m isle.
- Fallen lintels no longer leave a whole chord missing:
  - A fallen lintel breaks in its middle. A `LINTEL_BREAK` piece (3.0 m x
    wanderer) falls into the grass, and the two ends stay on their sarsens,
    so the ring is still run round with one twirled jump.
  - A lintel whose sarsen is `missing` keeps the end on the sarsen that still
    stands.
  - The ring's lintels are walked on true hulls (`_walk_hull`). A worn chunk
    out of a 7 m lintel had taken its top for metres.
- The fallen trilithon's stub is turned end-on, so the hop from the stub
  onto the lintel starts on stone.
- `TRILITHON_AT` is derived so the summit jump from the back lintel stays
  the same 2.29 m in. The broken lintel's pieces lie at R-3.6.
- Indices changed: `LEAN_AT` 1, `STUB_AT` 4, the aqueduct isle's
  `MISSING` 6 (292.5 degrees, in the bite), and the broken ring's
  `MISSING` [3, 4].
  - The aqueduct isle's floating ring sarsen is sized off the ring, a
    twirled jump from each broken end: 4.12 x 1.1 x 2.17.
  - Its kit stair stays at 257.14 degrees, 1.3 m off sarsen 5's face.
- test_aqueduct_isle `_ring_loop` now jumps along the ring's own lintels
  (from the sarsen's top to the next). At 8 stones the old straight line,
  cut across a sarsen's corner, ran 0.85 m off the lintels' line, so it left
  the lintels.

**Sundered** (from the Sundered fork, merged; commit a4f5c5bf):
- The line was hard to fly because `Sundered.LANE_MID` was a fixed 6.0. It
  ran 0.6 m off the inner columns in the widened lane. `LANE_MID` and
  `LINE_Y` are now static vars at the lane's middle: 7.08 and 2.55.
- Turns are eased:
  - Sundered: `RADIUS` 70 → 95, `TURN` 0.55 → 0.5, `KINK` 0.14 → 0.1.
  - Sundered line (`hall_line_plan.gd`): the sidestep's `jog_gap` 120 → 140
    m, `bend` 26 → 22 degrees.
- Breaches are placed only where their corridor fits between the columns on
  a curve (`Hall.breach_fits`, `HallPath.stretch`, `fit_breaches`). Where a
  bay can't take one, its roof is broken open instead.
- The podium, bed and island half-widths come from `WALL_Z`.
- Sundered gorge: the line's second point moved to (87.6, 18.8, -47), under
  the two lower-crossing fragments; it grazed them before. 0 bumps.
- Hollow keel: `FLOOR_SINK` 0.2 under the paving (it left a 0.47 m step),
  and its lane uses the kit's lane middle.
- Flight study: its stations keep the toy plane's hall (`TOY_ROW_Z`,
  `TOY_WALL_Z`, `TOY_KNIFE`, `TOY_ARCH` in flight_course.gd), since their
  hashes are pinned and their plane is the toy.
- test_sundered_hall now checks the lane's room, the line in the lane's
  middle, the breaches and arch at least THREAD, and curves of at least 90
  m. Its bot flies the line in 61 s with 0 bumps.

**Bell isles** (from the bells fork, merged; commit 11d1d22e;
studies/bell_spires_isle_art.gd):
- Each outer spire stands off the hero by `gap(CARVE_ROOM 6.0)`. Every
  outer pair is held to `gap(PASS_ROOM 4.0)`.
- The air between two spires is measured rock to rock (`air_between`). The
  bridges, drift stones, causeway, outline and start rebuild from the new
  positions.
- The chimney stays 2.6 m on purpose: it is the walker's wall-kick climb and
  the knife-edge token line.
- The bridges are now 13.3 to 14.1 m long.
- motif_sky's `REACH` for the bells went from 34 to 41.

**Other fixes made along the way:**
- The cloister tarn's north-east arch now faces the bridge across the isle's
  middle. Set along the bridge, its wider pier had stood on the bridge's
  head.
- The rose gable's fallen hub lands to one side of the door, never across
  it. It had blocked the colonnade spine's gate walk.
- kit_isle: a plane with no take-off run parks on the nearest level spot
  with room for it, not on the walker's start. The broken ring's start had
  stood him on the parked plane's column. That failure also happened on
  850aa041.
- The stumps' knife line moved from z -29.2 to z -28 (`KNIFE_Z`), the
  middle of the aqueduct's arch, which is 4 m clear. It had run 0.06 m off
  the arch's pier on a knife edge.

**Tests** (headless; each listed below passes):
- The two world-scale tests. test_world_scale_fit now covers every opening
  in the table, the three knife slots and the cockpit pilot, at the default
  sizes and at the old ones.
- The five that failed on 850aa041: aqueduct_isle_sky, sundered_gorge_isle,
  cloister_tarn_isle, hollow_keel_isle, flight_metrics.
- All of these pass: ruin_kit, sundered_hall, hall_chain, hall_rise,
  isle_hall_chain, lodestone_study, isle_lodestone, aqueduct_isle (+_life,
  _plane, _sail), broken_ring, colonnade_spine, drowned_nave, stair_clouds,
  bell_spires, pierced_isle, collectibles_world, island_pack_ruins_archipelago,
  isle_loop_played, isle_lock, cluster_motifs, kit_isle_landing,
  manual_landing (+_game), hand_landing_exit, plane_landing, sky_plane,
  pocket_sail (+_study), pilot_figure, pilot_ledge, pilot_motor,
  character_climb and character_study. plane_flight passes with a known
  engine error.
- Two tests still fail, and both fail the same way on 850aa041:
  - motif_sky: "colonnade_spine: open turf 14 m long to land on".
  - collectibles_pickup: its checks pass, but the engine logs
    `!isfinite(p_size)` from cozy_worlds `_layout_shell`.
- test_aqueduct_isle_look was not run. It already failed before this work.
- The sarsen token in test_aqueduct_isle_life jumps along the ring's own
  lintel now, the same way the loop test does.

**Open:**
- At `--plane-scale=1` the gaps no longer return to their old numbers. The
  room is bigger now, and the hall lane, arch, circle and ring are all wider
  at plane 1 too.
- Cloister arcades (SPRING 1.75, crown 3.5) are the walker's arches and
  weren't widened. The colonnade spine's portals and the drowned nave's
  openings weren't audited one by one; their tests pass.
- Knife edges (the trilithon at 1.9, the hall slits at 1.89, the stumps at
  2.11) leave only 0.2 to 0.3 m round the plane on its wingtip. They are
  deliberate challenges.
- The moments hall (`--chain-style=halls`) uses the widened hall, but its
  tokens were laid for the toy plane and weren't re-laid.
- The hall's BAY stays 8 m, so a breach on a straight wall has 5.6 m between
  the column shafts.
- The flight study's toy plane now seats a 1.2x pilot.
- Captured (rendered, --no-title) and looked at: the stone circle from
  above and at the ring (wide gaps, broken lintel ends), the bell isles from
  afar, and the Sundered gate and nave.
  - The bell spires capture script's "thread" view (tools/
    bell_spires_captures.sh) now sits by the rock at the new spacing.
  - Not flown by a person yet.

## The game's sizes (feature/plane-wanderer-scale; superseded above)

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
